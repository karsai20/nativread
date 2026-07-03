import SwiftUI

struct TranslationSheet: View {
    let book: Book

    @Environment(LibraryStore.self) private var library
    @Environment(SettingsStore.self) private var settings
    @Environment(TranslationStore.self) private var translations
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var ownsBook = false
    @State private var isRequestingPreview = false

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
            sectionLabel("First Chapter")

            phaseMessage

            Button {
                requestFreeChapter()
            } label: {
                Label("Translate first chapter", systemImage: "sparkles")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(palette.accent)
            .disabled(!ownsBook || isRequestingPreview || job.isBackendActive)
            .accessibilityIdentifier("translation.freeChapter")
        }
    }

    @ViewBuilder
    private var phaseMessage: some View {
        switch job.phase {
        case .draft:
            Text("Confirm ownership to unlock the free first-chapter request.")
                .font(Typography.meta())
                .foregroundStyle(palette.secondaryText)
        case .attested:
            Text("Ready to request the free first chapter.")
                .font(Typography.meta())
                .foregroundStyle(palette.secondaryText)
        case .previewQueued:
            HStack(spacing: Spacing.sm) {
                ProgressView()
                    .tint(palette.accent)
                Text("Preparing request...")
                    .font(Typography.meta())
                    .foregroundStyle(palette.secondaryText)
            }
        case .waitingForBackend:
            Label(
                "Translator backend is the next connection point.",
                systemImage: "server.rack"
            )
            .font(Typography.meta())
            .foregroundStyle(palette.secondaryText)
        case .uploading:
            progressMessage("Uploading EPUB to translator...")
        case .translating:
            progressMessage(
                job.progressText.map {
                    "Translating preview on the backend... \($0)"
                } ?? "Translating preview on the backend..."
            )
        case .importingResult:
            progressMessage("Importing translated EPUB...")
        case .finished:
            Label("Translated preview was added to your library.", systemImage: "checkmark.circle")
                .font(Typography.meta())
                .foregroundStyle(palette.secondaryText)
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

            Text("StoreKit purchase and server-side entitlement verification are intentionally not stubbed in this build.")
                .font(Typography.meta())
                .foregroundStyle(palette.secondaryText)
                .padding(.top, Spacing.xs)
        }
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

    private func requestFreeChapter() {
        if !ownsBook {
            ownsBook = true
            translations.recordAttestation(for: book)
        }
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

        isRequestingPreview = true
        let sourceURL = library.storedFileURL(for: book)
        let client = TranslationBackendClient(baseURL: backendURL)
        translations.markBackendUploadStarted(for: book)

        Task {
            do {
                let upload = try await client.upload(epubURL: sourceURL)
                if upload.alreadyTranslated != true {
                    translations.markBackendTranslationStarted(
                        for: book,
                        backendJobID: upload.id
                    )
                    try await client.start(jobID: upload.id, sample: true)
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
                translations.markBackendImportStarted(for: book)
                let output = try await client.downloadResult(jobID: upload.id)
                let importedURL = try writeTemporaryTranslatedEPUB(
                    output,
                    title: upload.title ?? book.title
                )
                let library = library
                _ = try await Task.detached(priority: .userInitiated) {
                    try library.importBook(from: importedURL)
                }.value
                translations.markBackendFinished(for: book)
            } catch {
                translations.markBackendFailed(
                    for: book,
                    message: error.localizedDescription
                )
            }
            isRequestingPreview = false
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
    var isBackendActive: Bool {
        switch phase {
        case .uploading, .translating, .importingResult, .previewQueued:
            return true
        default:
            return false
        }
    }
}
