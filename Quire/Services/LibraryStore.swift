import Foundation
import Observation
import ZIPFoundation

/// Owns the book library: importing, unpacking, metadata, progress,
/// bookmarks and persistence. All paths live under an injectable root
/// so tests can run against a temp directory.
@Observable
final class LibraryStore {
    private(set) var books: [Book] = []
    var lastError: String?

    private let root: URL
    private let fileManager = FileManager.default

    var booksDirectory: URL { root.appendingPathComponent("Books") }
    var extractedDirectory: URL { root.appendingPathComponent("Extracted") }
    var coversDirectory: URL { root.appendingPathComponent("Covers") }
    private var indexURL: URL { root.appendingPathComponent("library.json") }

    init(rootDirectory: URL? = nil) {
        if let rootDirectory {
            self.root = rootDirectory
        } else {
            let documents = FileManager.default
                .urls(for: .documentDirectory, in: .userDomainMask)[0]
            let newRoot = documents.appendingPathComponent("NativRead")
            // One-time migration from a pre-rename data directory (the app was
            // formerly Quire, then Epagora). Move the first one that exists.
            for legacyName in ["Epagora", "Quire"] {
                let legacyRoot = documents.appendingPathComponent(legacyName)
                if FileManager.default.fileExists(atPath: legacyRoot.path),
                   !FileManager.default.fileExists(atPath: newRoot.path) {
                    try? FileManager.default.moveItem(at: legacyRoot, to: newRoot)
                }
            }
            self.root = newRoot
        }
        for directory in [booksDirectory, extractedDirectory, coversDirectory] {
            try? fileManager.createDirectory(
                at: directory, withIntermediateDirectories: true
            )
        }
        load()
    }

    // MARK: - Import

    /// Copies the EPUB in, unpacks it, reads metadata and cover.
    @discardableResult
    func importBook(from sourceURL: URL) throws -> Book {
        let id = UUID()
        let needsScope = sourceURL.startAccessingSecurityScopedResource()
        defer { if needsScope { sourceURL.stopAccessingSecurityScopedResource() } }

        let storedURL = booksDirectory
            .appendingPathComponent("\(id.uuidString).epub")
        try materializedCopy(from: sourceURL, to: storedURL)

        do {
            let extractedRoot = extractedDirectory
                .appendingPathComponent(id.uuidString)
            try fileManager.createDirectory(
                at: extractedRoot, withIntermediateDirectories: true
            )
            do {
                try fileManager.unzipItem(at: storedURL, to: extractedRoot)
            } catch {
                throw EPUBError.unreadableArchive(error.localizedDescription)
            }

            let parsed = try EPUBParser.parse(extractedRoot: extractedRoot)
            // Neutralize any author-supplied scripts in the rendered
            // chapters; the reading engine provides all interactivity.
            EPUBParser.sanitizeScripts(in: parsed.spineURLs)

            var coverFileName: String?
            if let coverSource = parsed.coverImageURL {
                let name = "\(id.uuidString).\(coverSource.pathExtension)"
                let coverTarget = coversDirectory.appendingPathComponent(name)
                try? fileManager.copyItem(at: coverSource, to: coverTarget)
                if fileManager.fileExists(atPath: coverTarget.path) {
                    coverFileName = name
                }
            }

            let book = Book(
                id: id,
                title: parsed.title,
                author: parsed.author,
                fileName: storedURL.lastPathComponent,
                coverFileName: coverFileName,
                spineWeights: parsed.spineWeights
            )
            books.insert(book, at: 0)
            save()
            return book
        } catch {
            // Roll back partial import so the library never holds a corpse.
            try? fileManager.removeItem(at: storedURL)
            try? fileManager.removeItem(
                at: extractedDirectory.appendingPathComponent(id.uuidString)
            )
            throw error
        }
    }

    /// Copies a file from `sourceURL` to `destinationURL`, materializing the
    /// source first when it is an undownloaded iCloud placeholder. A plain
    /// local (non-ubiquitous) file is read directly by the coordinator.
    private func materializedCopy(from sourceURL: URL, to destinationURL: URL) throws {
        // Kick off the download if iCloud reports the item isn't local yet.
        // Non-iCloud files simply have no downloading status, which is fine.
        if let status = try? sourceURL.resourceValues(
            forKeys: [.ubiquitousItemDownloadingStatusKey]
        ).ubiquitousItemDownloadingStatus, status == .notDownloaded {
            try? fileManager.startDownloadingUbiquitousItem(at: sourceURL)
        }

        // Coordinated reading awaits materialization of a .notDownloaded item.
        var coordinatorError: NSError?
        var copyError: Error?
        let coordinator = NSFileCoordinator()
        coordinator.coordinate(
            readingItemAt: sourceURL, options: [], error: &coordinatorError
        ) { coordinatedURL in
            do {
                try fileManager.copyItem(at: coordinatedURL, to: destinationURL)
            } catch {
                copyError = error
            }
        }
        if let coordinatorError { throw coordinatorError }
        if let copyError { throw copyError }
    }

    func delete(_ book: Book) {
        try? fileManager.removeItem(
            at: booksDirectory.appendingPathComponent(book.fileName)
        )
        try? fileManager.removeItem(
            at: extractedDirectory.appendingPathComponent(book.id.uuidString)
        )
        if let cover = book.coverFileName {
            try? fileManager.removeItem(
                at: coversDirectory.appendingPathComponent(cover)
            )
        }
        books.removeAll { $0.id == book.id }
        save()
    }

    // MARK: - Reading state

    func updateProgress(bookID: UUID, spineIndex: Int, pageFraction: Double) {
        guard let index = books.firstIndex(where: { $0.id == bookID }) else {
            return
        }
        var book = books[index]
        book.progress = ReadingProgress(
            spineIndex: spineIndex,
            pageFraction: pageFraction,
            bookFraction: Book.bookFraction(
                spineIndex: spineIndex,
                pageFraction: pageFraction,
                weights: book.spineWeights
            )
        )
        book.lastOpenedAt = .now
        books[index] = book
        // In scroll mode progress updates fire on every scroll frame;
        // writing the whole library JSON to disk each time makes
        // scrolling stutter. Coalesce the writes — persist once the
        // scroll settles (and on reader teardown via flushPendingSave).
        scheduleProgressSave()
    }

    private var pendingProgressSave: DispatchWorkItem?

    private func scheduleProgressSave() {
        pendingProgressSave?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.pendingProgressSave = nil
            self?.save()
        }
        pendingProgressSave = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
    }

    /// Persists any pending coalesced progress immediately. Call when
    /// the reader closes or the app backgrounds so no position is lost.
    func flushPendingSave() {
        guard pendingProgressSave != nil else { return }
        pendingProgressSave?.cancel()
        pendingProgressSave = nil
        save()
    }

    func addBookmark(bookID: UUID, bookmark: Bookmark) {
        guard let index = books.firstIndex(where: { $0.id == bookID }) else {
            return
        }
        books[index].bookmarks.append(bookmark)
        save()
    }

    func removeBookmark(bookID: UUID, bookmarkID: UUID) {
        guard let index = books.firstIndex(where: { $0.id == bookID }) else {
            return
        }
        books[index].bookmarks.removeAll { $0.id == bookmarkID }
        save()
    }

    func addHighlight(bookID: UUID, highlight: Highlight) {
        guard let index = books.firstIndex(where: { $0.id == bookID }) else {
            return
        }
        books[index].highlights.append(highlight)
        save()
    }

    func removeHighlight(bookID: UUID, highlightID: UUID) {
        guard let index = books.firstIndex(where: { $0.id == bookID }) else {
            return
        }
        books[index].highlights.removeAll { $0.id == highlightID }
        save()
    }

    /// Replaces the matching highlight with a copy carrying `note`,
    /// keeping the array otherwise untouched, then persists.
    func setHighlightNote(
        bookID: UUID, highlightID: UUID, note: String?
    ) {
        guard let index = books.firstIndex(where: { $0.id == bookID }) else {
            return
        }
        books[index].highlights = books[index].highlights.map { highlight in
            guard highlight.id == highlightID else { return highlight }
            var updated = highlight
            updated.note = note
            return updated
        }
        save()
    }

    func book(id: UUID) -> Book? {
        books.first { $0.id == id }
    }

    // MARK: - Paths

    func extractedRoot(for book: Book) -> URL {
        extractedDirectory.appendingPathComponent(book.id.uuidString)
    }

    func coverURL(for book: Book) -> URL? {
        guard let name = book.coverFileName else { return nil }
        let url = coversDirectory.appendingPathComponent(name)
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }

    func parsedEPUB(for book: Book) throws -> ParsedEPUB {
        try EPUBParser.parse(extractedRoot: extractedRoot(for: book))
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: indexURL),
              let decoded = try? JSONDecoder().decode([Book].self, from: data)
        else { return }
        books = decoded
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(books) else { return }
        try? data.write(to: indexURL, options: .atomic)
    }
}
