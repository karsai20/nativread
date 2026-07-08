import XCTest
@testable import NativRead

@MainActor
final class TranslationStoreTests: XCTestCase {

    func testEstimatedPageCountUsesSpineWeights() {
        let book = Book(
            title: "Long",
            author: "A",
            fileName: "long.epub",
            spineWeights: [1_800, 3_600, 900]
        )

        XCTAssertEqual(TranslationStore.estimatedPageCount(for: book), 4)
    }

    func testEstimatedPageCountFallsBackWhenWeightsMissing() {
        // Empty spineWeights is the realistic case for older imports; it must
        // still yield a sane page count since it drives the price tier.
        let empty = Book(title: "T", author: "A", fileName: "f.epub")
        XCTAssertEqual(TranslationStore.estimatedPageCount(for: empty), 1)
        let zeros = Book(
            title: "T", author: "A", fileName: "f.epub",
            spineWeights: [0, 0, 0]
        )
        XCTAssertEqual(TranslationStore.estimatedPageCount(for: zeros), 36)
    }

    func testPriceTierBoundaries() {
        // Both sides of every tier edge: an off-by-one changes what users pay.
        let cases: [(Int, TranslationPriceTier)] = [
            (99, .under100), (100, .pages100To199),
            (199, .pages100To199), (200, .pages200To349),
            (349, .pages200To349), (350, .pages350To549),
            (549, .pages350To549), (550, .pages550To799),
            (799, .pages550To799), (800, .pages800Plus),
        ]
        for (pages, expected) in cases {
            XCTAssertEqual(
                TranslationPriceTier.tier(forEstimatedPages: pages), expected,
                "pages=\(pages)"
            )
        }
    }

    func testInterruptedJobLoadsAsFailed() throws {
        // A job persisted mid-flight (app killed) must reload as failed, not
        // resurrect as active behind a permanent spinner.
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: root, withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: root) }

        var job = TranslationJob(
            bookID: UUID(), bookTitle: "B", phase: .translating,
            estimatedPages: 1, priceTier: .under100
        )
        job.activeRequestKind = .full
        try JSONEncoder().encode([job]).write(
            to: root.appendingPathComponent("translation-jobs.json")
        )

        let reloaded = TranslationStore(rootDirectory: root)
        XCTAssertEqual(reloaded.jobs.first?.phase, .failed)
        XCTAssertNil(reloaded.jobs.first?.activeRequestKind)
    }

    func testUnknownPersistedPhaseDecodesAsFailed() throws {
        // A raw phase from an earlier build (e.g. removed "waitingForBackend")
        // must decode to .failed, not throw and wipe every stored job.
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: root, withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: root) }

        let json = """
        [{"bookID":"\(UUID().uuidString)","bookTitle":"B",\
        "targetLanguage":"hu","phase":"waitingForBackend","estimatedPages":1,\
        "priceTier":"under100","updatedAt":0}]
        """
        try Data(json.utf8).write(
            to: root.appendingPathComponent("translation-jobs.json")
        )

        let reloaded = TranslationStore(rootDirectory: root)
        XCTAssertEqual(reloaded.jobs.count, 1)
        XCTAssertEqual(reloaded.jobs.first?.phase, .failed)
    }

    func testAttestationPersistsForBook() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let book = Book(
            title: "Book",
            author: "A",
            fileName: "book.epub",
            spineWeights: [1_800]
        )

        let store = TranslationStore(rootDirectory: root)
        store.recordAttestation(for: book)

        let reloaded = TranslationStore(rootDirectory: root)
        let job = reloaded.job(for: book)
        XCTAssertEqual(job.phase, .attested)
        XCTAssertNotNil(job.attestedAt)
    }

    func testTargetLanguagePersistsForBook() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let book = Book(
            title: "Book",
            author: "A",
            fileName: "book.epub",
            spineWeights: [1_800]
        )

        let store = TranslationStore(rootDirectory: root)
        store.setTargetLanguage(.de, for: book)

        let reloaded = TranslationStore(rootDirectory: root)
        XCTAssertEqual(reloaded.job(for: book).targetLanguage, .de)
    }

    func testBackendJobStatePersistsForBook() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let book = Book(
            title: "Book",
            author: "A",
            fileName: "book.epub",
            spineWeights: [1_800]
        )

        let store = TranslationStore(rootDirectory: root)
        store.markBackendUploadStarted(for: book)
        store.markBackendTranslationStarted(
            for: book,
            backendJobID: "job-123",
            kind: .full
        )

        // Within the live session the job holds its in-flight state.
        let live = store.job(for: book)
        XCTAssertEqual(live.phase, .translating)
        XCTAssertEqual(live.backendJobID, "job-123")
        XCTAssertEqual(live.activeRequestKind, .full)
        XCTAssertNil(live.errorMessage)

        // Reloading an in-flight job from disk means the app died mid-request;
        // it is failed (not resurrected active), keeping the id for reference.
        var reloaded = TranslationStore(rootDirectory: root).job(for: book)
        XCTAssertEqual(reloaded.phase, .failed)
        XCTAssertEqual(reloaded.backendJobID, "job-123")
        XCTAssertNil(reloaded.activeRequestKind)
        XCTAssertNotNil(reloaded.errorMessage)

        store.markBackendFailed(for: book, message: "Backend failed.")
        reloaded = TranslationStore(rootDirectory: root).job(for: book)
        XCTAssertEqual(reloaded.phase, .failed)
        XCTAssertEqual(reloaded.errorMessage, "Backend failed.")
    }

    func testBackendProgressPersistsAndClears() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let book = Book(
            title: "Book",
            author: "A",
            fileName: "book.epub",
            spineWeights: [1_800]
        )

        let store = TranslationStore(rootDirectory: root)
        store.markBackendTranslationStarted(for: book, backendJobID: "job-123")
        store.updateBackendProgress(
            for: book,
            translatedChunks: 10,
            totalChunks: 19
        )

        // Progress is visible on the live job during translation.
        let live = store.job(for: book)
        XCTAssertEqual(live.phase, .translating)
        XCTAssertEqual(live.translatedChunks, 10)
        XCTAssertEqual(live.totalChunks, 19)
        XCTAssertEqual(live.progressText, "10/19 sections")

        store.markBackendFinished(for: book)
        let reloaded = TranslationStore(rootDirectory: root).job(for: book)
        XCTAssertNotNil(reloaded.previewCompletedAt)
        XCTAssertNil(reloaded.translatedChunks)
        XCTAssertNil(reloaded.totalChunks)
    }

    func testFullCompletionPersistsSeparatelyFromPreview() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let book = Book(
            title: "Book",
            author: "A",
            fileName: "book.epub",
            spineWeights: [1_800]
        )

        let store = TranslationStore(rootDirectory: root)
        store.markBackendUploadStarted(for: book, kind: .full)
        store.markBackendFinished(for: book, kind: .full)

        let reloaded = TranslationStore(rootDirectory: root).job(for: book)
        XCTAssertNil(reloaded.previewCompletedAt)
        XCTAssertNotNil(reloaded.fullCompletedAt)
        XCTAssertNil(reloaded.activeRequestKind)
    }
}
