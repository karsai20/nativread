import Foundation

/// One translation on the backend, end to end: upload (unless a quote already
/// did; the free chapter uploads only the book up to that chapter), start, follow progress, download, and import the result into the
/// library. The sheet decides whether it may run; this only runs it.
@MainActor
struct TranslationRun {
    let client: TranslationBackendClient
    let book: Book
    let kind: TranslationRequestKind
    let sourceURL: URL
    let sourceLanguage: String
    let targetLanguage: TranslationTargetLanguage
    let termsAcceptance: TranslationTermsAcceptance
    let translations: TranslationStore
    let library: LibraryStore

    func perform(preparedUpload: TranslationBackendClient.UploadResponse?) async throws {
        let upload: TranslationBackendClient.UploadResponse
        if let preparedUpload {
            upload = preparedUpload
        } else if kind == .preview {
            // The free chapter sends the book only up to that chapter.
            let sample = try await Self.sample(of: sourceURL)
            defer { try? FileManager.default.removeItem(at: sample) }
            upload = try await client.upload(epubURL: sample)
        } else {
            upload = try await client.upload(epubURL: sourceURL)
        }
        if upload.alreadyTranslated != true {
            translations.markBackendTranslationStarted(
                for: book, backendJobID: upload.id, kind: kind
            )
            try await client.start(
                jobID: upload.id,
                sample: kind == .preview,
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage,
                termsAcceptance: termsAcceptance
            )
            _ = try await client.waitUntilDone(jobID: upload.id) { status in
                await MainActor.run {
                    translations.updateBackendProgress(
                        for: book,
                        translatedChunks: status.chunks?.done,
                        totalChunks: status.chunks?.total
                    )
                }
            }
        }
        translations.markBackendImportStarted(for: book, kind: kind)
        let output = try await client.downloadResult(jobID: upload.id)
        try TranslationResultImporter.importResult(
            output,
            title: upload.title ?? book.title,
            book: book,
            kind: kind,
            targetLanguage: targetLanguage,
            library: library
        )
        translations.markBackendFinished(for: book, kind: kind)
    }

    /// Cuts the book off the main thread: reading a large archive stalls it.
    private static func sample(of sourceURL: URL) async throws -> URL {
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("sample-\(UUID().uuidString).epub")
        try await Task.detached(priority: .userInitiated) {
            try SampleEPUBBuilder.build(from: sourceURL, to: destination)
        }.value
        return destination
    }
}
