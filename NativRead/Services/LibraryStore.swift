import CryptoKit
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

    /// Flips to true when a finished-book transition satisfies
    /// `ReviewPromptPolicy`. The root view observes it, shows the StoreKit
    /// review prompt, and resets it.
    var reviewPromptRequested = false
    private let reviewPromptPolicy: ReviewPromptPolicy

    private let root: URL
    private let fileManager = FileManager.default

    var booksDirectory: URL { root.appendingPathComponent("Books") }
    var extractedDirectory: URL { root.appendingPathComponent("Extracted") }
    var coversDirectory: URL { root.appendingPathComponent("Covers") }
    private var indexURL: URL { root.appendingPathComponent("library.json") }

    init(
        rootDirectory: URL? = nil,
        reviewPromptDefaults: UserDefaults = .standard
    ) {
        self.reviewPromptPolicy = ReviewPromptPolicy(
            defaults: reviewPromptDefaults
        )
        if let rootDirectory {
            self.root = rootDirectory
        } else {
            let documents = FileManager.default
                .urls(for: .documentDirectory, in: .userDomainMask)[0]
            let newRoot = documents.appendingPathComponent("NativRead")
            // One-time migration from pre-release data directories. Move the
            // first one that exists without exposing retired brand names.
            let earliestDirectoryName = ["Qui", "re"].joined()
            for legacyName in ["Epagora", earliestDirectoryName] {
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

    /// Imports any supported file, routing by extension: EPUB unpacks and
    /// parses, PDF reads metadata + cover, TXT synthesizes a chapter.
    @discardableResult
    func importBook(from sourceURL: URL) throws -> Book {
        switch sourceURL.pathExtension.lowercased() {
        case "pdf": return try importPDF(from: sourceURL)
        case "txt": return try importText(from: sourceURL)
        case "mobi", "azw", "azw3", "prc": return try importMOBI(from: sourceURL)
        default: return try importEPUB(from: sourceURL)
        }
    }

    @discardableResult
    func importTranslationPreview(
        from sourceURL: URL,
        originalBook: Book,
        translatedFraction: Double,
        targetLanguage: TranslationTargetLanguage = .hu
    ) throws -> Book {
        try importEPUB(
            from: sourceURL,
            titleOverride: "\(originalBook.title) (\(targetLanguage.displayName) preview)",
            variant: .translationPreview,
            sourceBookID: originalBook.id,
            translatedFraction: translatedFraction,
            translatedLanguage: targetLanguage
        )
    }

    @discardableResult
    func importFullTranslation(
        from sourceURL: URL,
        originalBook: Book,
        targetLanguage: TranslationTargetLanguage = .hu
    ) throws -> Book {
        try importEPUB(
            from: sourceURL,
            titleOverride: "\(originalBook.title) (\(targetLanguage.displayName) translation)",
            variant: .fullTranslation,
            sourceBookID: originalBook.id,
            translatedFraction: 1,
            translatedLanguage: targetLanguage
        )
    }

    /// Front matter — cover, copyright page, table of contents, dedication —
    /// is proper nouns and boilerplate, and `NLLanguageRecognizer` guesses
    /// wildly on it (an English novel came back as Dutch). Directory order puts
    /// exactly those files first, so this samples the *largest* documents, and
    /// from the *middle* of each: the big files are the chapters, and the
    /// middle is prose even when the whole book is one document.
    /// What the EPUB says it is written in, or nil if it says nothing.
    ///
    /// Books shelved before `declaredLanguage` was recorded carry nil, so the
    /// OPF is re-read for them rather than leaving every existing book on the
    /// guessing path. Cheaper than the text sample this backs up: a few KB of
    /// XML against up to 60 KB of markup and four regex passes.
    func declaredLanguage(for book: Book) -> String? {
        if let declared = book.declaredLanguage { return declared }
        guard book.format == .epub else { return nil }
        return try? parsedEPUB(for: book).declaredLanguage
    }

    func languageDetectionSample(for book: Book, maxCharacters: Int = 4_000) -> String {
        let root = extractedRoot(for: book)
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return "" }

        var documents: [(url: URL, size: Int)] = []
        for case let url as URL in enumerator {
            guard ["xhtml", "html", "htm", "txt"].contains(
                url.pathExtension.lowercased()
            ) else { continue }
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey])
                .fileSize) ?? 0
            documents.append((url, size))
        }

        var sample = ""
        for document in documents.sorted(by: { $0.size > $1.size }).prefix(3) {
            guard let raw = try? String(contentsOf: document.url) else { continue }
            sample += " " + Self.plainTextSample(from: Self.middleWindow(of: raw))
            if sample.count >= maxCharacters { break }
        }
        return String(sample.prefix(maxCharacters))
    }

    /// Middle slice of a document: past the title page, and small enough that
    /// tag-stripping a one-file book stays cheap on the main thread.
    private static func middleWindow(
        of raw: String, characters: Int = 20_000
    ) -> String {
        guard raw.count > characters else { return raw }
        let start = raw.index(
            raw.startIndex, offsetBy: (raw.count - characters) / 2
        )
        return String(raw[start...].prefix(characters))
    }

    private static func plainTextSample(from raw: String) -> String {
        raw
            .replacingOccurrences(
                of: "(?is)<script\\b[^>]*>.*?</script\\s*>",
                with: " ", options: .regularExpression
            )
            .replacingOccurrences(
                of: "(?is)<style\\b[^>]*>.*?</style\\s*>",
                with: " ", options: .regularExpression
            )
            .replacingOccurrences(
                of: "(?is)<[^>]+>", with: " ", options: .regularExpression
            )
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(
                of: "\\s+", with: " ", options: .regularExpression
            )
    }

    /// Copies the source file in (materializing iCloud placeholders) under
    /// `<id>.<ext>` and returns the stored URL. Holds the security scope
    /// only for the read; the reader works off our local copy afterward.
    private func copyIn(from sourceURL: URL, id: UUID, ext: String) throws -> URL {
        let needsScope = sourceURL.startAccessingSecurityScopedResource()
        defer { if needsScope { sourceURL.stopAccessingSecurityScopedResource() } }
        let storedURL = booksDirectory
            .appendingPathComponent("\(id.uuidString).\(ext)")
        try materializedCopy(from: sourceURL, to: storedURL)
        return storedURL
    }

    /// Imports a PDF: copy in, read metadata + render a cover.
    private func importPDF(from sourceURL: URL) throws -> Book {
        let id = UUID()
        let storedURL = try copyIn(from: sourceURL, id: id, ext: "pdf")
        do {
            let book = try PDFImporter.makeBook(
                id: id,
                storedURL: storedURL,
                originalName: sourceURL.deletingPathExtension()
                    .lastPathComponent,
                coversDirectory: coversDirectory
            )
            books.insert(book, at: 0)
            save()
            return book
        } catch {
            try? fileManager.removeItem(at: storedURL)
            throw error
        }
    }

    /// Imports a plain-text file: copy in, synthesize a reflowable chapter.
    private func importText(from sourceURL: URL) throws -> Book {
        let id = UUID()
        let storedURL = try copyIn(from: sourceURL, id: id, ext: "txt")
        do {
            let book = try TextImporter.makeBook(
                id: id,
                storedURL: storedURL,
                extractedRoot: extractedDirectory
                    .appendingPathComponent(id.uuidString),
                originalName: sourceURL.deletingPathExtension()
                    .lastPathComponent
            )
            books.insert(book, at: 0)
            save()
            return book
        } catch {
            try? fileManager.removeItem(at: storedURL)
            try? fileManager.removeItem(
                at: extractedDirectory.appendingPathComponent(id.uuidString)
            )
            throw error
        }
    }

    /// Converts a MOBI/AZW3 (KF8) book to an EPUB in a temp file, then hands
    /// it to the existing EPUB pipeline. The stored book is a real EPUB, so
    /// `format` stays `.epub` and the reflowable reader opens it directly.
    private func importMOBI(from sourceURL: URL) throws -> Book {
        let needsScope = sourceURL.startAccessingSecurityScopedResource()
        defer { if needsScope { sourceURL.stopAccessingSecurityScopedResource() } }
        let tempEPUB = fileManager.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).epub")
        defer { try? fileManager.removeItem(at: tempEPUB) }
        try KF8Converter.convertToEPUB(source: sourceURL, destination: tempEPUB)
        return try importEPUB(from: tempEPUB)
    }

    /// Copies the EPUB in, unpacks it, reads metadata and cover.
    private func importEPUB(
        from sourceURL: URL,
        titleOverride: String? = nil,
        variant: BookVariant = .original,
        sourceBookID: UUID? = nil,
        translatedFraction: Double? = nil,
        translatedLanguage: TranslationTargetLanguage? = nil
    ) throws -> Book {
        let id = UUID()
        let needsScope = sourceURL.startAccessingSecurityScopedResource()
        defer { if needsScope { sourceURL.stopAccessingSecurityScopedResource() } }

        let storedURL = booksDirectory
            .appendingPathComponent("\(id.uuidString).epub")
        try materializedCopy(from: sourceURL, to: storedURL)

        do {
            try EPUBArchiveValidator.validate(at: storedURL)
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
            try EPUBParser.sanitizeForReading(in: parsed.spineURLs)

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
                title: titleOverride ?? parsed.title,
                author: parsed.author,
                fileName: storedURL.lastPathComponent,
                coverFileName: coverFileName,
                spineWeights: parsed.spineWeights,
                variant: variant,
                sourceBookID: sourceBookID,
                translatedFraction: translatedFraction,
                translatedLanguage: translatedLanguage,
                declaredLanguage: parsed.declaredLanguage
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
        let wasFinished = book.isFinished
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
        // Review prompt rides the not-finished -> finished transition only —
        // the peak-happiness moment, never an error or onboarding path.
        if !wasFinished, book.isFinished,
           reviewPromptPolicy.registerFinishedBook(
               isTranslated: book.variant != .original
           ) {
            reviewPromptRequested = true
        }
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

    func storedFileURL(for book: Book) -> URL {
        booksDirectory.appendingPathComponent(book.fileName)
    }

    // MARK: - Quote cache

    /// SHA256 of the stored source file, hex-encoded to match the hash the
    /// backend computes over the same bytes. Read in chunks: a 32 MB book must
    /// not land in memory whole just to be fingerprinted.
    ///
    /// Takes a URL rather than a `Book` so callers can hash off the main
    /// thread without carrying the store across the hop.
    static func sourceHash(ofFileAt url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try? handle.read(upToCount: 1 << 20), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize()
            .map { String(format: "%02x", $0) }
            .joined()
    }

    /// Remembers which price the backend quoted for exactly these bytes, so
    /// reopening the sheet can show it without uploading the book again.
    func recordQuote(bookID: UUID, sourceHash: String, productId: String) {
        guard let index = books.firstIndex(where: { $0.id == bookID }) else {
            return
        }
        var book = books[index]
        book.quotedSourceHash = sourceHash
        book.quotedProductId = productId
        books[index] = book
        save()
    }

    func parsedEPUB(for book: Book) throws -> ParsedEPUB {
        if book.format == .txt {
            return TextImporter.parsed(
                extractedRoot: extractedRoot(for: book), title: book.title
            )
        }
        return try EPUBParser.parse(extractedRoot: extractedRoot(for: book))
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: indexURL),
              let decoded = try? JSONDecoder().decode([Book].self, from: data)
        else { return }
        books = decoded.map(Self.migratingAILabel)
    }

    /// One-shot title cleanup for translated variants: EU AI Act Art 50
    /// transparency is shown by `BookVariant.badgeText`, not repeated in the
    /// persisted title. Older imports may still carry the prior title prefix.
    private static func migratingAILabel(_ book: Book) -> Book {
        guard book.variant != .original, book.title.contains("(AI ") else { return book }
        var migrated = book
        migrated.title = book.title
            .replacingOccurrences(of: "(AI Hungarian preview)", with: "(Hungarian preview)")
            .replacingOccurrences(of: "(AI Hungarian translation)", with: "(Hungarian translation)")
        return migrated
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(books) else { return }
        try? data.write(to: indexURL, options: .atomic)
    }
}
