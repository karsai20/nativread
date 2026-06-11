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
            let newRoot = documents.appendingPathComponent("Quire")
            // One-time migration from the pre-rename data directory.
            let legacyRoot = documents.appendingPathComponent("LumenRead")
            if FileManager.default.fileExists(atPath: legacyRoot.path),
               !FileManager.default.fileExists(atPath: newRoot.path) {
                try? FileManager.default.moveItem(at: legacyRoot, to: newRoot)
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
        try fileManager.copyItem(at: sourceURL, to: storedURL)

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
