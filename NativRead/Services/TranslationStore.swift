import Foundation
import Observation

@MainActor
@Observable
final class TranslationStore {
    private(set) var jobs: [TranslationJob] = []

    /// Changes only when a persisted backend job needs reconnecting after an
    /// app launch. LibraryView uses it to start one recovery pass without
    /// racing translations that were started in the current process.
    private(set) var recoveryRevision = 0
    private var pendingRecoveryBookIDs: Set<UUID> = []

    private let root: URL
    private let fileManager = FileManager.default

    private var indexURL: URL {
        root.appendingPathComponent("translation-jobs.json")
    }

    init(rootDirectory: URL? = nil) {
        if let rootDirectory {
            self.root = rootDirectory
        } else {
            let documents = FileManager.default
                .urls(for: .documentDirectory, in: .userDomainMask)[0]
            self.root = documents.appendingPathComponent("NativRead")
        }
        try? fileManager.createDirectory(
            at: root, withIntermediateDirectories: true
        )
        load()
    }

    func job(for book: Book) -> TranslationJob {
        if let existing = jobs.first(where: { $0.bookID == book.id }) {
            return existing
        }
        return draftJob(for: book)
    }

    func recordTermsAcceptance(
        for book: Book,
        localeIdentifier: String = Locale.current.identifier
    ) {
        var job = self.job(for: book)
        job.bookTitle = book.title
        job.phase = .attested
        job.attestedAt = .now
        job.acceptedTermsVersion = TranslationTerms.currentVersion
        job.termsAcceptanceID = UUID()
        job.termsAcceptanceLocale = localeIdentifier
            .replacingOccurrences(of: "_", with: "-")
        job.updatedAt = .now
        upsert(job)
    }

    func currentTermsAcceptance(
        for book: Book
    ) -> TranslationTermsAcceptance? {
        let job = self.job(for: book)
        guard job.acceptedTermsVersion == TranslationTerms.currentVersion,
              let id = job.termsAcceptanceID,
              let acceptedAt = job.attestedAt,
              let localeIdentifier = job.termsAcceptanceLocale
        else { return nil }
        return TranslationTermsAcceptance(
            id: id,
            acceptedAt: acceptedAt,
            localeIdentifier: localeIdentifier
        )
    }

    func clearTermsAcceptance(for book: Book) {
        var job = self.job(for: book)
        guard !job.phase.isInFlight else { return }
        job.acceptedTermsVersion = nil
        job.termsAcceptanceID = nil
        job.termsAcceptanceLocale = nil
        job.attestedAt = nil
        job.phase = .draft
        job.updatedAt = .now
        upsert(job)
    }

    func recordAIProcessingConsent(for book: Book) {
        var job = self.job(for: book)
        job.bookTitle = book.title
        job.acceptedAIProcessingVersion =
            TranslationPrivacy.currentAIConsentVersion
        job.updatedAt = .now
        upsert(job)
    }

    /// Forgets every stored AI-processing permission on this device. This
    /// affects future requests only; work already sent at the user's request
    /// cannot be undone by changing local preference metadata.
    func clearAIProcessingConsents() {
        var changed = false
        jobs = jobs.map { job in
            guard job.acceptedAIProcessingVersion != nil else { return job }
            var updated = job
            updated.acceptedAIProcessingVersion = nil
            updated.updatedAt = .now
            changed = true
            return updated
        }
        if changed { save() }
    }

    /// Removes account-bound translation state after the backend confirms
    /// account deletion. Imported source and translated books stay in the
    /// reader's local library because they are user-owned device files, not
    /// server account records.
    func clearAccountData() {
        jobs.removeAll()
        pendingRecoveryBookIDs.removeAll()
        recoveryRevision += 1
        try? fileManager.removeItem(at: indexURL)
    }

    func setTargetLanguage(_ language: TranslationTargetLanguage, for book: Book) {
        var job = self.job(for: book)
        guard !job.phase.isInFlight else { return }
        job.bookTitle = book.title
        job.targetLanguage = language
        job.updatedAt = .now
        upsert(job)
    }

    func markBackendUploadStarted(
        for book: Book,
        kind: TranslationRequestKind = .preview
    ) {
        var job = self.job(for: book)
        job.bookTitle = book.title
        job.phase = .uploading
        job.activeRequestKind = kind
        job.errorMessage = nil
        job.updatedAt = .now
        upsert(job)
    }

    func markBackendTranslationStarted(
        for book: Book,
        backendJobID: String,
        kind: TranslationRequestKind = .preview
    ) {
        var job = self.job(for: book)
        job.bookTitle = book.title
        job.phase = .translating
        job.backendJobID = backendJobID
        job.activeRequestKind = kind
        job.translatedChunks = nil
        job.totalChunks = nil
        job.errorMessage = nil
        job.updatedAt = .now
        upsert(job)
    }

    /// Keeps the backend identity and request kind intact when only the iOS
    /// client lost its connection. A later foreground/relaunch pass can then
    /// continue polling and import the result instead of asking the reader to
    /// pay for or start the same translation again.
    func markBackendReconnectNeeded(for book: Book, message: String? = nil) {
        var job = self.job(for: book)
        guard job.backendJobID != nil, job.activeRequestKind != nil else {
            markBackendFailed(
                for: book,
                message: message ?? "Could not reconnect to translation."
            )
            return
        }
        job.bookTitle = book.title
        job.phase = .translating
        job.errorMessage = message
        job.updatedAt = .now
        pendingRecoveryBookIDs.insert(book.id)
        upsert(job)
    }

    func markBackendQuoteReady(for book: Book, backendJobID: String) {
        var job = self.job(for: book)
        job.bookTitle = book.title
        job.phase = .attested
        job.backendJobID = backendJobID
        job.activeRequestKind = nil
        job.errorMessage = nil
        job.updatedAt = .now
        upsert(job)
    }

    func updateBackendProgress(
        for book: Book,
        translatedChunks: Int?,
        totalChunks: Int?
    ) {
        var job = self.job(for: book)
        job.bookTitle = book.title
        job.phase = .translating
        job.translatedChunks = translatedChunks
        job.totalChunks = totalChunks
        job.errorMessage = nil
        job.updatedAt = .now
        upsert(job)
    }

    func markBackendImportStarted(
        for book: Book,
        kind: TranslationRequestKind? = nil
    ) {
        var job = self.job(for: book)
        job.bookTitle = book.title
        job.phase = .importingResult
        if let kind {
            job.activeRequestKind = kind
        }
        job.errorMessage = nil
        job.updatedAt = .now
        upsert(job)
    }

    func markBackendFinished(
        for book: Book,
        kind: TranslationRequestKind? = nil
    ) {
        var job = self.job(for: book)
        let completedKind = kind ?? job.activeRequestKind ?? .preview
        job.bookTitle = book.title
        job.phase = .finished
        switch completedKind {
        case .preview:
            job.previewCompletedAt = .now
        case .full:
            job.fullCompletedAt = .now
        }
        job.activeRequestKind = nil
        job.translatedChunks = nil
        job.totalChunks = nil
        job.errorMessage = nil
        job.updatedAt = .now
        upsert(job)
    }

    func markBackendFailed(for book: Book, message: String) {
        var job = self.job(for: book)
        job.bookTitle = book.title
        job.phase = .failed
        job.errorMessage = message
        job.activeRequestKind = nil
        job.translatedChunks = nil
        job.totalChunks = nil
        job.updatedAt = .now
        upsert(job)
    }

    static func estimatedPageCount(for book: Book) -> Int {
        let totalWeight = book.spineWeights.reduce(0, +)
        guard totalWeight > 0 else {
            return max(1, book.spineWeights.count * 12)
        }
        return max(1, Int((totalWeight / 1_800).rounded(.up)))
    }

    private func draftJob(for book: Book) -> TranslationJob {
        let pages = Self.estimatedPageCount(for: book)
        return TranslationJob(
            bookID: book.id,
            bookTitle: book.title,
            estimatedPages: pages,
            priceTier: .tier(forEstimatedPages: pages)
        )
    }

    private func upsert(_ job: TranslationJob) {
        if let index = jobs.firstIndex(where: { $0.bookID == job.bookID }) {
            jobs[index] = job
        } else {
            jobs.insert(job, at: 0)
        }
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: indexURL),
              let decoded = try? JSONDecoder().decode(
                  [TranslationJob].self, from: data
              )
        else { return }
        jobs = decoded.map { job in
            // Uploading has no guaranteed backend identity yet, so it cannot
            // be recovered. Translating/importing can be resumed when both the
            // backend job ID and request kind were persisted before exit.
            if job.phase == .uploading {
                var stalled = job
                stalled.phase = .failed
                stalled.activeRequestKind = nil
                stalled.translatedChunks = nil
                stalled.totalChunks = nil
                stalled.errorMessage = "Upload was interrupted. Try again."
                return stalled
            }
            if job.phase == .translating || job.phase == .importingResult {
                guard job.backendJobID != nil,
                      job.activeRequestKind != nil else {
                    var invalid = job
                    invalid.phase = .failed
                    invalid.activeRequestKind = nil
                    invalid.errorMessage =
                        "Could not reconnect to this translation. Try again."
                    return invalid
                }
                pendingRecoveryBookIDs.insert(job.bookID)
                return job
            }
            guard job.phase == .finished,
                  job.previewCompletedAt == nil,
                  job.fullCompletedAt == nil
            else { return job }
            var migrated = job
            migrated.previewCompletedAt = job.updatedAt
            return migrated
        }
        recoveryRevision = pendingRecoveryBookIDs.count
    }

    /// Atomically claims jobs loaded from disk for one recovery pass. Failed
    /// network reconnects are put back without immediately spinning another
    /// pass; the next foreground activation retries them.
    func takePendingRecoveryJobs() -> [TranslationJob] {
        let claimed = jobs.filter { pendingRecoveryBookIDs.contains($0.bookID) }
        pendingRecoveryBookIDs.subtract(claimed.map(\.bookID))
        return claimed
    }

    func deferRecovery(for book: Book, message: String) {
        pendingRecoveryBookIDs.insert(book.id)
        var job = self.job(for: book)
        job.phase = .translating
        job.errorMessage = message
        job.updatedAt = .now
        upsert(job)
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(jobs) else { return }
        try? data.write(to: indexURL, options: .atomic)
    }
}

/// Reattaches the app to translations that survived an app termination on the
/// backend. Network transport does not need to stay alive in iOS: the client
/// only polls the durable backend job and imports its result when ready.
@MainActor
enum TranslationRecovery {
    static func reconcilePendingJobs(
        translations: TranslationStore,
        library: LibraryStore,
        settings: SettingsStore,
        auth: TranslationAuthStore,
        clientOverride: TranslationBackendClient? = nil
    ) async {
        let client: TranslationBackendClient
        if let clientOverride {
            client = clientOverride
        } else {
            guard let backendURL = settings.translationBackendURL,
                  let token = auth.sessionToken else { return }
            client = TranslationBackendClient(
                baseURL: backendURL,
                bearerToken: token
            )
        }

        let pending = translations.takePendingRecoveryJobs()
        guard !pending.isEmpty else { return }

        for savedJob in pending {
            guard let book = library.book(id: savedJob.bookID),
                  let backendJobID = savedJob.backendJobID,
                  let kind = savedJob.activeRequestKind else { continue }
            do {
                var status = try await client.status(jobID: backendJobID)
                if !Self.isDone(status.status) {
                    status = try await client.waitUntilDone(
                        jobID: backendJobID
                    ) { update in
                        await MainActor.run {
                            translations.updateBackendProgress(
                                for: book,
                                translatedChunks: update.chunks?.done,
                                totalChunks: update.chunks?.total
                            )
                        }
                    }
                }

                translations.markBackendImportStarted(for: book, kind: kind)
                let output = try await client.downloadResult(
                    jobID: backendJobID
                )
                try TranslationResultImporter.importResult(
                    output,
                    title: status.title ?? book.title,
                    book: book,
                    kind: kind,
                    targetLanguage: savedJob.targetLanguage,
                    library: library
                )
                translations.markBackendFinished(for: book, kind: kind)
            } catch let error as TranslationBackendClient.ClientError {
                switch error {
                case .failedStatus, .server:
                    translations.markBackendFailed(
                        for: book, message: error.localizedDescription
                    )
                default:
                    translations.deferRecovery(
                        for: book,
                        message: "Translation continues on the backend. "
                            + "NativRead will reconnect automatically."
                    )
                }
            } catch {
                translations.deferRecovery(
                    for: book,
                    message: "Translation continues on the backend. "
                        + "NativRead will reconnect automatically."
                )
            }
        }
    }

    private static func isDone(_ status: String) -> Bool {
        status.lowercased() == "done"
    }
}

/// Shared result import path for a foreground request and a relaunched app.
@MainActor
enum TranslationResultImporter {
    private static let previewFraction = 0.01

    static func importResult(
        _ data: Data,
        title: String,
        book: Book,
        kind: TranslationRequestKind,
        targetLanguage: TranslationTargetLanguage,
        library: LibraryStore
    ) throws {
        let safeTitle = title
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "\(safeTitle)-translated-\(UUID().uuidString).epub"
            )
        try data.write(to: url, options: .atomic)
        defer { try? FileManager.default.removeItem(at: url) }

        switch kind {
        case .preview:
            try library.importTranslationPreview(
                from: url,
                originalBook: book,
                translatedFraction: previewFraction,
                targetLanguage: targetLanguage
            )
        case .full:
            try library.importFullTranslation(
                from: url,
                originalBook: book,
                targetLanguage: targetLanguage
            )
        }
    }
}
