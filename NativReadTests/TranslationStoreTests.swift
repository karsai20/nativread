import XCTest
@testable import NativRead

@MainActor
final class TranslationStoreTests: XCTestCase {

    func testDecodesV32JobJSONWithoutTargetLanguage() throws {
        // v3.2 persisted jobs before multi-language metadata existed. A
        // missing targetLanguage must decode as Hungarian — a decode failure
        // here silently wipes every stored job on upgrade.
        let v32JSON = """
        [{
            "bookID": "00000000-0000-0000-0000-000000000001",
            "bookTitle": "Old Book",
            "phase": "attested",
            "estimatedPages": 120,
            "priceTier": "pages100To199",
            "updatedAt": 773340000
        }]
        """
        // Plain JSONDecoder mirrors TranslationStore.load exactly.
        let jobs = try JSONDecoder().decode(
            [TranslationJob].self, from: Data(v32JSON.utf8)
        )

        XCTAssertEqual(jobs.count, 1)
        XCTAssertEqual(jobs[0].targetLanguage, .hu)
        XCTAssertEqual(jobs[0].phase, .attested)
    }

    func testBackendJobSurvivesRelaunchForRecovery() throws {
        // Translation runs on the backend. Once its ID and request kind were
        // persisted, terminating iOS must keep it recoverable rather than
        // falsely reporting that the translation itself was interrupted.
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: root, withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: root) }

        var job = TranslationJob(
            bookID: UUID(), bookTitle: "B", phase: .translating,
            backendJobID: "backend-123"
        )
        job.activeRequestKind = .full
        try JSONEncoder().encode([job]).write(
            to: root.appendingPathComponent("translation-jobs.json")
        )

        let reloaded = TranslationStore(rootDirectory: root)
        XCTAssertEqual(reloaded.jobs.first?.phase, .translating)
        XCTAssertEqual(reloaded.jobs.first?.activeRequestKind, .full)
        XCTAssertEqual(
            reloaded.takePendingRecoveryJobs().first?.backendJobID,
            "backend-123"
        )
        XCTAssertTrue(reloaded.takePendingRecoveryJobs().isEmpty)
    }

    func testUploadWithoutBackendIdentityStillFailsOnRelaunch() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: root, withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: root) }

        let job = TranslationJob(
            bookID: UUID(), bookTitle: "B", phase: .uploading,
            activeRequestKind: .preview
        )
        try JSONEncoder().encode([job]).write(
            to: root.appendingPathComponent("translation-jobs.json")
        )

        let reloaded = TranslationStore(rootDirectory: root)
        XCTAssertEqual(reloaded.jobs.first?.phase, .failed)
        XCTAssertNil(reloaded.jobs.first?.activeRequestKind)
    }

    func testRelaunchRecoveryDownloadsAndImportsFinishedPreview() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: root, withIntermediateDirectories: true
        )
        defer {
            StubURLProtocol.responder = nil
            try? FileManager.default.removeItem(at: root)
        }

        let sourceTree = root.appendingPathComponent("source-tree")
        try EPUBFixtures.writeEPUB3(
            to: sourceTree, title: "Source", author: "Author"
        )
        let sourceEPUB = root.appendingPathComponent("source.epub")
        try EPUBFixtures.zipEPUB(directory: sourceTree, to: sourceEPUB)

        let translatedTree = root.appendingPathComponent("translated-tree")
        try EPUBFixtures.writeEPUB3(
            to: translatedTree, title: "Fordítás", author: "Author"
        )
        let translatedEPUB = root.appendingPathComponent("translated.epub")
        try EPUBFixtures.zipEPUB(
            directory: translatedTree, to: translatedEPUB
        )
        let translatedData = try Data(contentsOf: translatedEPUB)

        let library = LibraryStore(
            rootDirectory: root.appendingPathComponent("library")
        )
        let book = try library.importBook(from: sourceEPUB)
        let jobRoot = root.appendingPathComponent("jobs")
        let initialStore = TranslationStore(rootDirectory: jobRoot)
        initialStore.recordTermsAcceptance(for: book)
        initialStore.markBackendTranslationStarted(
            for: book, backendJobID: "job-1", kind: .preview
        )
        let relaunchedStore = TranslationStore(rootDirectory: jobRoot)

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        let client = TranslationBackendClient(
            baseURL: URL(string: "http://backend.test")!,
            userID: "user-1",
            session: URLSession(configuration: config)
        )
        StubURLProtocol.responder = { request in
            if request.url?.path == "/api/status" {
                return (
                    200,
                    Data(#"{"id":"job-1","status":"done","title":"Fordítás"}"#.utf8)
                )
            }
            if request.url?.path == "/api/result" {
                return (200, translatedData)
            }
            return (404, Data(#"{"error":"missing"}"#.utf8))
        }

        await TranslationRecovery.reconcilePendingJobs(
            translations: relaunchedStore,
            library: library,
            settings: SettingsStore(
                defaults: UserDefaults(suiteName: UUID().uuidString)!,
                defaultTranslationBackendURLString: "http://backend.test"
            ),
            auth: TranslationAuthStore(),
            clientOverride: client
        )

        XCTAssertEqual(library.books.count, 2)
        XCTAssertEqual(
            library.books.first(where: { $0.id != book.id })?.variant,
            .translationPreview
        )
        XCTAssertEqual(relaunchedStore.job(for: book).phase, .finished)
        XCTAssertNotNil(relaunchedStore.job(for: book).previewCompletedAt)
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

    func testTermsAcceptancePersistsForBookAndVersion() throws {
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
        store.recordTermsAcceptance(for: book, localeIdentifier: "hu-HU")

        let reloaded = TranslationStore(rootDirectory: root)
        let job = reloaded.job(for: book)
        XCTAssertEqual(job.phase, .attested)
        XCTAssertNotNil(job.attestedAt)
        XCTAssertEqual(
            job.acceptedTermsVersion,
            TranslationTerms.currentVersion
        )
        XCTAssertNotNil(job.termsAcceptanceID)
        XCTAssertEqual(job.termsAcceptanceLocale, "hu-HU")
        XCTAssertEqual(
            reloaded.currentTermsAcceptance(for: book)?.id,
            job.termsAcceptanceID
        )
    }

    func testTermsCheckboxCanBeClearedBeforeTranslation() throws {
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
        store.recordTermsAcceptance(for: book, localeIdentifier: "en-US")

        store.clearTermsAcceptance(for: book)

        XCTAssertNil(store.currentTermsAcceptance(for: book))
        XCTAssertNil(store.job(for: book).attestedAt)
        XCTAssertEqual(store.job(for: book).phase, .draft)
    }

    func testAIProcessingConsentPersistsForBookAndVersion() throws {
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
        store.recordAIProcessingConsent(for: book)

        let reloaded = TranslationStore(rootDirectory: root)
        XCTAssertEqual(
            reloaded.job(for: book).acceptedAIProcessingVersion,
            TranslationPrivacy.currentAIConsentVersion
        )
    }

    func testAIProcessingConsentCanBeWithdrawnForFutureRequests() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let firstBook = Book(
            title: "First",
            author: "A",
            fileName: "first.epub",
            spineWeights: [1_800]
        )
        let secondBook = Book(
            title: "Second",
            author: "B",
            fileName: "second.epub",
            spineWeights: [1_800]
        )
        let store = TranslationStore(rootDirectory: root)
        store.recordAIProcessingConsent(for: firstBook)
        store.recordAIProcessingConsent(for: secondBook)

        store.clearAIProcessingConsents()

        let reloaded = TranslationStore(rootDirectory: root)
        XCTAssertNil(reloaded.job(for: firstBook).acceptedAIProcessingVersion)
        XCTAssertNil(reloaded.job(for: secondBook).acceptedAIProcessingVersion)
    }

    func testClearAccountDataRemovesPersistedTranslationJobs() throws {
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
        store.recordTermsAcceptance(for: book)
        store.recordAIProcessingConsent(for: book)

        store.clearAccountData()

        XCTAssertTrue(store.jobs.isEmpty)
        XCTAssertTrue(TranslationStore(rootDirectory: root).jobs.isEmpty)
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

        // Reloading reconnects to the durable backend job instead of treating
        // app termination as a translation failure.
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

        // Progress is visible on the live job during translation.
        let live = store.job(for: book)
        XCTAssertEqual(live.phase, .translating)
        XCTAssertEqual(live.translatedChunks, 10)
        XCTAssertEqual(live.totalChunks, 19)

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
