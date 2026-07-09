import XCTest
@testable import NativRead

@MainActor
final class LibraryStoreTests: XCTestCase {

    private var root: URL!
    private var epubURL: URL!

    override func setUp() async throws {
        root = try EPUBFixtures.makeTempDirectory()
        let unpacked = try EPUBFixtures.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: unpacked) }
        try EPUBFixtures.writeEPUB3(
            to: unpacked, title: "Imported Title",
            author: "Imported Author", chapterCount: 3
        )
        epubURL = root.appendingPathComponent("source.epub")
        try EPUBFixtures.zipEPUB(directory: unpacked, to: epubURL)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func makeStore() -> LibraryStore {
        LibraryStore(
            rootDirectory: root.appendingPathComponent("store")
        )
    }

    func testImportAddsBookWithMetadataCoverAndWeights() throws {
        let store = makeStore()

        let book = try store.importBook(from: epubURL)

        XCTAssertEqual(store.books.count, 1)
        XCTAssertEqual(book.title, "Imported Title")
        XCTAssertEqual(book.author, "Imported Author")
        XCTAssertEqual(book.variant, .original)
        XCTAssertEqual(book.spineWeights.count, 3)
        XCTAssertNotNil(store.coverURL(for: book))
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: store.extractedRoot(for: book)
                .appendingPathComponent("OEBPS/ch1.xhtml").path
        ))
    }

    func testImportTranslationPreviewMarksSeparateVariant() throws {
        let store = makeStore()
        let original = try store.importBook(from: epubURL)

        let preview = try store.importTranslationPreview(
            from: epubURL,
            originalBook: original,
            translatedFraction: 0.01
        )

        XCTAssertEqual(store.books.count, 2)
        XCTAssertEqual(preview.title, "Imported Title (Hungarian preview)")
        XCTAssertEqual(preview.variant, .translationPreview)
        XCTAssertEqual(preview.sourceBookID, original.id)
        XCTAssertEqual(preview.translatedFraction, 0.01)
        XCTAssertFalse(preview.isTranslatableSource)
        XCTAssertTrue(original.isTranslatableSource)
        // EU AI Act Art 50 transparency markers: AI prefix required on
        // translated variants, no badge on originals.
        XCTAssertEqual(preview.variantBadgeText, "AI · HU PREVIEW")
        XCTAssertNil(original.variantBadgeText)

        let reloaded = makeStore()
        let persisted = reloaded.book(id: preview.id)
        XCTAssertEqual(persisted?.variant, .translationPreview)
        XCTAssertEqual(persisted?.sourceBookID, original.id)
        XCTAssertEqual(persisted?.translatedFraction, 0.01)
    }

    func testImportFullTranslationMarksSeparateVariant() throws {
        let store = makeStore()
        let original = try store.importBook(from: epubURL)

        let translated = try store.importFullTranslation(
            from: epubURL,
            originalBook: original
        )

        XCTAssertEqual(store.books.count, 2)
        XCTAssertEqual(translated.title, "Imported Title (Hungarian translation)")
        XCTAssertEqual(translated.variant, .fullTranslation)
        XCTAssertEqual(translated.sourceBookID, original.id)
        XCTAssertEqual(translated.translatedFraction, 1)
        XCTAssertFalse(translated.isTranslatableSource)
        XCTAssertEqual(translated.variantBadgeText, "AI · HU")
    }

    func testImportTranslationPersistsTargetLanguageMetadata() throws {
        let store = makeStore()
        let original = try store.importBook(from: epubURL)

        let preview = try store.importTranslationPreview(
            from: epubURL,
            originalBook: original,
            translatedFraction: 0.01,
            targetLanguage: .de
        )
        let translated = try store.importFullTranslation(
            from: epubURL,
            originalBook: original,
            targetLanguage: .es
        )

        XCTAssertEqual(preview.title, "Imported Title (German preview)")
        XCTAssertEqual(preview.translatedLanguage, .de)
        XCTAssertEqual(preview.variantBadgeText, "AI · DE PREVIEW")
        XCTAssertEqual(translated.title, "Imported Title (Spanish translation)")
        XCTAssertEqual(translated.translatedLanguage, .es)
        XCTAssertEqual(translated.variantBadgeText, "AI · ES")

        let reloaded = makeStore()
        XCTAssertEqual(reloaded.book(id: preview.id)?.translatedLanguage, .de)
        XCTAssertEqual(reloaded.book(id: translated.id)?.translatedLanguage, .es)
    }

    func testLoadCleansRepeatedAIActTranslatedTitles() throws {
        let store = makeStore()
        let original = try store.importBook(from: epubURL)
        let preview = try store.importTranslationPreview(
            from: epubURL, originalBook: original, translatedFraction: 0.01
        )
        let translated = try store.importFullTranslation(
            from: epubURL, originalBook: original
        )

        // Rewrite the persisted index to the older title format that repeated
        // the AI marker in the title as well as the variant badge.
        let indexURL = root.appendingPathComponent("store/library.json")
        let legacy = try String(contentsOf: indexURL, encoding: .utf8)
            .replacingOccurrences(of: "(Hungarian preview)", with: "(AI Hungarian preview)")
            .replacingOccurrences(of: "(Hungarian translation)", with: "(AI Hungarian translation)")
        try legacy.write(to: indexURL, atomically: true, encoding: .utf8)

        let reloaded = makeStore()
        XCTAssertEqual(
            reloaded.book(id: preview.id)?.title,
            "Imported Title (Hungarian preview)"
        )
        XCTAssertEqual(
            reloaded.book(id: translated.id)?.title,
            "Imported Title (Hungarian translation)"
        )
        XCTAssertEqual(reloaded.book(id: original.id)?.title, "Imported Title")
    }

    func testLibraryPersistsAcrossInstances() throws {
        let book = try makeStore().importBook(from: epubURL)

        let reloaded = makeStore()

        XCTAssertEqual(reloaded.books.map(\.id), [book.id])
        XCTAssertEqual(reloaded.books.first?.title, "Imported Title")
    }

    func testProgressUpdateComputesBookFraction() throws {
        let store = makeStore()
        let book = try store.importBook(from: epubURL)

        store.updateProgress(
            bookID: book.id, spineIndex: 1, pageFraction: 0.5
        )

        let updated = store.book(id: book.id)!
        XCTAssertEqual(updated.progress.spineIndex, 1)
        XCTAssertEqual(updated.progress.pageFraction, 0.5)
        XCTAssertGreaterThan(updated.progress.bookFraction, 0.3)
        XCTAssertLessThan(updated.progress.bookFraction, 0.7)
        XCTAssertNotNil(updated.lastOpenedAt)
    }

    func testBookmarksAddAndRemove() throws {
        let store = makeStore()
        let book = try store.importBook(from: epubURL)
        let bookmark = Bookmark(
            spineIndex: 0, pageFraction: 0.25,
            chapterTitle: "Part 1", snippet: "The lantern burned"
        )

        store.addBookmark(bookID: book.id, bookmark: bookmark)
        XCTAssertEqual(store.book(id: book.id)?.bookmarks.count, 1)

        store.removeBookmark(bookID: book.id, bookmarkID: bookmark.id)
        XCTAssertEqual(store.book(id: book.id)?.bookmarks.count, 0)
    }

    func testHighlightsAddRemoveAndPersist() throws {
        let store = makeStore()
        let book = try store.importBook(from: epubURL)
        let highlight = Highlight(
            spineIndex: 0, text: "a skin of green glass",
            occurrence: 0, chapterTitle: "Part 1"
        )

        store.addHighlight(bookID: book.id, highlight: highlight)
        XCTAssertEqual(store.book(id: book.id)?.highlights.count, 1)

        // Highlights must survive a store reload (Apple Books users'
        // top complaint is silently lost annotations).
        let reloaded = makeStore()
        XCTAssertEqual(
            reloaded.book(id: book.id)?.highlights.first, highlight
        )

        store.removeHighlight(bookID: book.id, highlightID: highlight.id)
        XCTAssertEqual(store.book(id: book.id)?.highlights.count, 0)
    }

    func testDeleteRemovesAllArtifacts() throws {
        let store = makeStore()
        let book = try store.importBook(from: epubURL)
        let extracted = store.extractedRoot(for: book)

        store.delete(book)

        XCTAssertTrue(store.books.isEmpty)
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: extracted.path)
        )
        XCTAssertNil(store.coverURL(for: book))
        XCTAssertTrue(makeStore().books.isEmpty, "deletion must persist")
    }

    func testImportCopiesPlainLocalFileIndependently() throws {
        // The coordinated-read import path must still work for an ordinary,
        // non-ubiquitous local file: the stored EPUB is a self-contained copy
        // that survives deletion of the source.
        let store = makeStore()
        let book = try store.importBook(from: epubURL)

        try FileManager.default.removeItem(at: epubURL)

        let stored = store.booksDirectory
            .appendingPathComponent(book.fileName)
        XCTAssertTrue(FileManager.default.fileExists(atPath: stored.path))
        XCTAssertEqual(book.title, "Imported Title")
    }

    func testImportFailureRollsBack() throws {
        let store = makeStore()
        let bogus = root.appendingPathComponent("bogus.epub")
        try Data("not a zip at all".utf8).write(to: bogus)

        XCTAssertThrowsError(try store.importBook(from: bogus))
        XCTAssertTrue(store.books.isEmpty)
        let leftovers = try FileManager.default.contentsOfDirectory(
            atPath: store.booksDirectory.path
        )
        XCTAssertTrue(leftovers.isEmpty, "no orphan files after failure")
    }

    // MARK: - Review prompt (E8)

    func testFinishingTranslatedBookRequestsReviewPromptOnce() throws {
        let suiteName = "libstore-review-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = LibraryStore(
            rootDirectory: root.appendingPathComponent("store"),
            reviewPromptDefaults: defaults
        )
        let original = try store.importBook(from: epubURL)
        let preview = try store.importTranslationPreview(
            from: epubURL, originalBook: original, translatedFraction: 1.0
        )

        // Mid-book progress: no prompt.
        store.updateProgress(
            bookID: preview.id, spineIndex: 1, pageFraction: 0.5
        )
        XCTAssertFalse(store.reviewPromptRequested)

        // Finishing the translated book crosses the transition: prompt.
        store.updateProgress(
            bookID: preview.id, spineIndex: 2, pageFraction: 1.0
        )
        XCTAssertTrue(store.reviewPromptRequested)

        // Already-finished updates never re-request.
        store.reviewPromptRequested = false
        store.updateProgress(
            bookID: preview.id, spineIndex: 2, pageFraction: 1.0
        )
        XCTAssertFalse(store.reviewPromptRequested)
    }
}
