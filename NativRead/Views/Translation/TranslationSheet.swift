import SwiftUI

private let freePreviewFraction = 0.01

struct TranslationSheet: View {
    let book: Book

    @Environment(LibraryStore.self) private var library
    @Environment(SettingsStore.self) private var settings
    @Environment(TranslationStore.self) private var translations
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var ownsBook = false
    @State private var isRequestingTranslation = false

    private var palette: BrandPalette {
        BrandPalette.resolve(systemDark: colorScheme == .dark)
    }

    private var job: TranslationJob {
        translations.job(for: book)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    header
                    languageSection
                    ownershipSection
                    freeChapterSection
                    purchaseSection
                }
                .padding(Spacing.lg)
            }
            .background(palette.background.ignoresSafeArea())
            .navigationTitle("Translate Book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .tint(palette.accent)
                }
            }
        }
        .presentationDetents([.large])
        .accessibilityIdentifier("translation.sheet")
        .onAppear {
            ownsBook = job.attestedAt != nil
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(book.title)
                .font(Typography.display(30))
                .foregroundStyle(palette.text)
                .fixedSize(horizontal: false, vertical: true)

            Text(book.author)
                .font(Typography.meta())
                .foregroundStyle(palette.secondaryText)

            Text("Translate an EPUB you own for private reading.")
                .font(Typography.body(16))
                .foregroundStyle(palette.secondaryText)
                .padding(.top, Spacing.sm)
        }
    }

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionLabel("Target")
            HStack {
                Label("Hungarian", systemImage: "character.bubble")
                    .font(Typography.body(16))
                    .foregroundStyle(palette.text)
                Spacer()
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(palette.accent)
            }
            .padding(.vertical, Spacing.xs)
        }
    }

    private var ownershipSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionLabel("Ownership")

            Button {
                ownsBook.toggle()
                if ownsBook {
                    translations.recordAttestation(for: book)
                }
            } label: {
                HStack(alignment: .top, spacing: Spacing.sm) {
                    Image(
                        systemName: ownsBook
                            ? "checkmark.square.fill" : "square"
                    )
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(palette.accent)
                    .frame(width: 28, height: 28)

                    Text("I own this book and may translate it for personal use.")
                        .font(Typography.body(16))
                        .foregroundStyle(palette.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("translation.attestation")
            .accessibilityAddTraits(ownsBook ? [.isSelected] : [])
        }
    }

    private var freeChapterSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            sectionLabel("Free Preview")

            phaseMessage

            Button {
                requestTranslation(kind: .preview)
            } label: {
                Label(freePreviewButtonTitle, systemImage: "sparkles")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(palette.accent)
            .disabled(
                !ownsBook
                    || isRequestingTranslation
                    || job.isBackendActive
                    || job.hasFreePreview
                    || !book.isTranslatableSource
            )
            .accessibilityIdentifier("translation.freeChapter")
        }
    }

    private var freePreviewButtonTitle: String {
        job.hasFreePreview ? "Preview already added" : "Translate free preview"
    }

    @ViewBuilder
    private var phaseMessage: some View {
        switch job.phase {
        case .draft:
            Text("Confirm ownership to unlock a one-time free preview. It translates only the opening, up to about 1% of the book, and imports a separate preview copy.")
                .font(Typography.meta())
                .foregroundStyle(palette.secondaryText)
        case .attested:
            Text("Ready to request a one-time preview. The rest of the EPUB stays in the original language.")
                .font(Typography.meta())
                .foregroundStyle(palette.secondaryText)
        case .uploading:
            progressMessage("Uploading EPUB to translator...")
        case .translating:
            progressMessage(
                job.progressText.map {
                    "\(job.activeProgressMessage)... \($0)"
                } ?? "\(job.activeProgressMessage)..."
            )
        case .importingResult:
            progressMessage("Importing \(job.activeResultName)...")
        case .finished:
            if job.hasFullTranslation {
                Label("Full Hungarian translation was added as a separate library book.", systemImage: "checkmark.circle")
                    .font(Typography.meta())
                    .foregroundStyle(palette.secondaryText)
            } else {
                Label("Hungarian preview was added as a separate library book.", systemImage: "checkmark.circle")
                    .font(Typography.meta())
                    .foregroundStyle(palette.secondaryText)
            }
        case .failed:
            Label(job.errorMessage ?? "Translation failed.", systemImage: "exclamationmark.triangle")
                .font(Typography.meta())
                .foregroundStyle(palette.secondaryText)
        }
    }

    private func progressMessage(_ text: String) -> some View {
        HStack(spacing: Spacing.sm) {
            ProgressView()
                .tint(palette.accent)
            Text(text)
                .font(Typography.meta())
                .foregroundStyle(palette.secondaryText)
        }
    }

    private var purchaseSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionLabel("Whole Book")

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(job.priceTier.displayName)
                        .font(Typography.body(16))
                        .foregroundStyle(palette.text)
                    Text("\(job.estimatedPages) estimated pages")
                        .font(Typography.meta())
                        .foregroundStyle(palette.secondaryText)
                }
                Spacer()
                Text(job.priceTier.priceText)
                    .font(Typography.title(22))
                    .foregroundStyle(palette.accent)
            }

            Button {
                requestTranslation(kind: .full)
            } label: {
                Label(fullBookButtonTitle, systemImage: "book.closed")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(palette.accent)
            .disabled(
                !ownsBook
                    || isRequestingTranslation
                    || job.isBackendActive
                    || job.hasFullTranslation
                    || !book.isTranslatableSource
            )
            .accessibilityIdentifier("translation.fullBook")

            Text("Payment and entitlement checks are still planned; this MVP runs the full-book backend path directly.")
                .font(Typography.meta())
                .foregroundStyle(palette.secondaryText)
                .padding(.top, Spacing.xs)
        }
    }

    private var fullBookButtonTitle: String {
        job.hasFullTranslation ? "Full translation already added" : "Translate whole book"
    }

    private func sectionLabel(_ text: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Text(text)
                .font(Typography.eyebrow)
                .tracking(Typography.eyebrowTracking)
                .textCase(.uppercase)
                .foregroundStyle(palette.secondaryText)
            Rectangle()
                .fill(palette.hairline)
                .frame(height: Spacing.hairlineWidth)
        }
    }

    private func requestTranslation(kind: TranslationRequestKind) {
        guard kind == .full || !job.hasFreePreview else { return }
        guard kind == .preview || !job.hasFullTranslation else { return }
        // Ownership attestation is a legal gate; never set it programmatically.
        // The buttons are already disabled until the user checks the box.
        guard ownsBook else { return }
        guard book.format == .epub else {
            translations.markBackendFailed(
                for: book,
                message: TranslationBackendClient.ClientError
                    .unsupportedFormat.localizedDescription
            )
            return
        }
        guard let backendURL = settings.translationBackendURL else {
            translations.markBackendFailed(
                for: book,
                message: TranslationBackendClient.ClientError
                    .invalidBackendURL.localizedDescription
            )
            return
        }

        isRequestingTranslation = true
        let sourceURL = library.storedFileURL(for: book)
        let client = TranslationBackendClient(
            baseURL: backendURL,
            userID: settings.translationUserID
        )
        translations.markBackendUploadStarted(for: book, kind: kind)

        Task {
            do {
                let upload = try await client.upload(epubURL: sourceURL)
                let shouldStartTranslation =
                    kind == .full || upload.alreadyTranslated != true
                if shouldStartTranslation {
                    translations.markBackendTranslationStarted(
                        for: book,
                        backendJobID: upload.id,
                        kind: kind
                    )
                    try await client.start(
                        jobID: upload.id,
                        sample: kind == .preview
                    )
                    _ = try await client.waitUntilDone(jobID: upload.id) {
                        status in
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
                let importedURL = try writeTemporaryTranslatedEPUB(
                    output,
                    title: upload.title ?? book.title
                )
                // Temp file is consumed by the import below; drop it either way
                // so translated EPUBs don't accumulate in tmp/.
                defer { try? FileManager.default.removeItem(at: importedURL) }
                // Import on the main actor, like every other import path.
                // LibraryStore is not Sendable and SwiftUI observes `books` on
                // main; a background `Task.detached` here raced `books`/`save()`
                // against a concurrent import and could corrupt library.json.
                switch kind {
                case .preview:
                    try library.importTranslationPreview(
                        from: importedURL,
                        originalBook: book,
                        translatedFraction: freePreviewFraction
                    )
                case .full:
                    try library.importFullTranslation(
                        from: importedURL,
                        originalBook: book
                    )
                }
                translations.markBackendFinished(for: book, kind: kind)
            } catch {
                translations.markBackendFailed(
                    for: book,
                    message: error.localizedDescription
                )
            }
            isRequestingTranslation = false
        }
    }

    private func writeTemporaryTranslatedEPUB(
        _ data: Data,
        title: String
    ) throws -> URL {
        let safeTitle = title
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(safeTitle)-translated-\(UUID().uuidString).epub")
        try data.write(to: url, options: .atomic)
        return url
    }
}

private extension TranslationJob {
    var hasFreePreview: Bool {
        previewCompletedAt != nil
    }

    var hasFullTranslation: Bool {
        fullCompletedAt != nil
    }

    var activeProgressMessage: String {
        switch activeRequestKind {
        case .full:
            return "Translating whole book on the backend"
        case .preview, nil:
            return "Translating preview on the backend"
        }
    }

    var activeResultName: String {
        switch activeRequestKind {
        case .full:
            return "full translation"
        case .preview, nil:
            return "preview"
        }
    }

    var isBackendActive: Bool {
        switch phase {
        case .uploading, .translating, .importingResult:
            return true
        default:
            return false
        }
    }
}
