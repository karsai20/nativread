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

    func testPriceTierBoundaries() {
        XCTAssertEqual(
            TranslationPriceTier.tier(forEstimatedPages: 99),
            .under100
        )
        XCTAssertEqual(
            TranslationPriceTier.tier(forEstimatedPages: 100),
            .pages100To199
        )
        XCTAssertEqual(
            TranslationPriceTier.tier(forEstimatedPages: 800),
            .pages800Plus
        )
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

        var reloaded = TranslationStore(rootDirectory: root).job(for: book)
        XCTAssertEqual(reloaded.phase, .translating)
        XCTAssertEqual(reloaded.backendJobID, "job-123")
        XCTAssertEqual(reloaded.activeRequestKind, .full)
        XCTAssertNil(reloaded.errorMessage)

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

        var reloaded = TranslationStore(rootDirectory: root).job(for: book)
        XCTAssertEqual(reloaded.phase, .translating)
        XCTAssertEqual(reloaded.translatedChunks, 10)
        XCTAssertEqual(reloaded.totalChunks, 19)
        XCTAssertEqual(reloaded.progressText, "10/19 sections")

        store.markBackendFinished(for: book)
        reloaded = TranslationStore(rootDirectory: root).job(for: book)
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
