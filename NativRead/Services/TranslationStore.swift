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

    func queueFreeChapter(for book: Book) {
        var job = self.job(for: book)
        if job.attestedAt == nil {
            job.attestedAt = .now
        }
        job.bookTitle = book.title
        job.phase = .previewQueued
        job.updatedAt = .now
        upsert(job)

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(700))
            guard var latest = jobs.first(where: { $0.bookID == book.id }),
                  latest.phase == .previewQueued else { return }
            latest.phase = .waitingForBackend
            latest.updatedAt = .now
            upsert(latest)
        }
    }

    func markBackendUploadStarted(for book: Book) {
        var job = self.job(for: book)
        if job.attestedAt == nil {
            job.attestedAt = .now
        }
        job.bookTitle = book.title
        job.phase = .uploading
        job.errorMessage = nil
        job.updatedAt = .now
        upsert(job)
    }

    func markBackendTranslationStarted(for book: Book, backendJobID: String) {
        var job = self.job(for: book)
        job.bookTitle = book.title
        job.phase = .translating
        job.backendJobID = backendJobID
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

    func markBackendImportStarted(for book: Book) {
        var job = self.job(for: book)
        job.bookTitle = book.title
        job.phase = .importingResult
        job.errorMessage = nil
        job.updatedAt = .now
        upsert(job)
    }

    func markBackendFinished(for book: Book) {
        var job = self.job(for: book)
        job.bookTitle = book.title
        job.phase = .finished
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
        jobs = decoded
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(jobs) else { return }
        try? data.write(to: indexURL, options: .atomic)
    }
}
