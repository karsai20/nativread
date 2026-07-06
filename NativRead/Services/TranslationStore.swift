import Foundation
import Observation

@MainActor
@Observable
final class TranslationStore {
    private(set) var jobs: [TranslationJob] = []

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

    func recordAttestation(for book: Book) {
        var job = self.job(for: book)
        job.bookTitle = book.title
        job.phase = .attested
        job.attestedAt = .now
        job.updatedAt = .now
        upsert(job)
    }

    func markBackendUploadStarted(
        for book: Book,
        kind: TranslationRequestKind = .preview
    ) {
        var job = self.job(for: book)
        if job.attestedAt == nil {
            job.attestedAt = .now
        }
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
            // An in-flight job reloaded from disk means the app was killed
            // mid-request (crash, jetsam, force quit). Nothing is resuming it,
            // so fail it — otherwise both buttons stay disabled forever behind
            // a perpetual spinner with no way to retry.
            if job.phase.isInFlight {
                var stalled = job
                stalled.phase = .failed
                stalled.activeRequestKind = nil
                stalled.translatedChunks = nil
                stalled.totalChunks = nil
                stalled.errorMessage = "Translation was interrupted. Try again."
                return stalled
            }
            guard job.phase == .finished,
                  job.previewCompletedAt == nil,
                  job.fullCompletedAt == nil
            else { return job }
            var migrated = job
            migrated.previewCompletedAt = job.updatedAt
            return migrated
        }
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(jobs) else { return }
        try? data.write(to: indexURL, options: .atomic)
    }
}
