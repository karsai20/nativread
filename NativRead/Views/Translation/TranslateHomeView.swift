import SwiftUI

/// The Translate destination: a workspace for turning books into the reader's
/// own language. It answers three questions in order — what is running now,
/// what can I translate next, and what is already done.
struct TranslateHomeView: View {
    @Environment(LibraryStore.self) private var library
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(TranslationStore.self) private var translationStore
    @Environment(\.colorScheme) private var colorScheme

    @State private var translationBook: Book?
    @State private var openBook: Book?

    private var palette: BrandPalette {
        BrandPalette.resolve(systemDark: colorScheme == .dark)
    }

    /// Jobs the backend is still working on, newest first.
    private var activeJobs: [TranslationJob] {
        translationStore.jobs
            .filter { $0.phase.isInFlight }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private var translatableBooks: [Book] {
        library.books
            .filter(\.isTranslatableSource)
            .sorted { $0.addedAt > $1.addedAt }
    }

    private var translatedBooks: [Book] {
        library.books
            .filter(\.isTranslatedCopy)
            .sorted { $0.addedAt > $1.addedAt }
    }

    private var isEmpty: Bool {
        activeJobs.isEmpty && translatableBooks.isEmpty && translatedBooks.isEmpty
    }

    var body: some View {
        ZStack {
            palette.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    AppLargeTitleHeader(
                        title: "Translate",
                        subtitle: String(
                            localized: "Keep context beside every translated word"
                        ),
                        palette: palette
                    )

                    if isEmpty {
                        emptyState
                    } else {
                        if !activeJobs.isEmpty { activeSection }
                        if !translatableBooks.isEmpty { readySection }
                        if !translatedBooks.isEmpty { completedSection }
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.md)
                .padding(.bottom, Spacing.xl)
            }
        }
        .sheet(item: $translationBook) { book in
            TranslationSheet(book: book)
                .environment(translationStore)
        }
        .fullScreenCover(item: $openBook) { book in
            if book.format == .pdf {
                PDFReaderView(
                    book: book,
                    library: library,
                    settingsStore: settingsStore,
                    initialSystemDark: colorScheme == .dark
                )
            } else {
                ReaderView(
                    book: book,
                    library: library,
                    settingsStore: settingsStore,
                    initialSystemDark: colorScheme == .dark
                )
            }
        }
    }

    // MARK: - Sections

    private var activeSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            AppSectionLabel(title: "In progress", palette: palette)

            ForEach(activeJobs) { job in
                activeJobCard(job)
            }
        }
    }

    private func activeJobCard(_ job: TranslationJob) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .top, spacing: Spacing.sm) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(job.bookTitle)
                        .font(Typography.control(17, weight: .semibold))
                        .foregroundStyle(palette.text)
                        .lineLimit(2)

                    Text(job.targetLanguage.displayName)
                        .font(Typography.control(14))
                        .foregroundStyle(palette.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                AppPill(title: phaseTitle(job.phase), tone: .info, palette: palette)
            }

            AppProgressTrack(
                value: progressValue(job),
                tone: palette.info,
                palette: palette
            )
        }
        .padding(Spacing.md)
        .background(palette.surface)
        .clipShape(
            RoundedRectangle(cornerRadius: Spacing.radiusGroup, style: .continuous)
        )
    }

    private var readySection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            AppSectionLabel(title: "Ready to translate", palette: palette)

            AppSettingsSection(palette: palette) {
                ForEach(Array(translatableBooks.enumerated()), id: \.element.id) { index, book in
                    AppSettingsRow(
                        systemImage: "sparkles",
                        title: LocalizedStringKey(book.title),
                        value: book.author,
                        hidesSeparator: index == translatableBooks.count - 1,
                        action: { translationBook = book },
                        palette: palette
                    )
                }
            }
        }
    }

    private var completedSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            AppSectionLabel(title: "Completed", palette: palette)

            AppSettingsSection(palette: palette) {
                ForEach(Array(translatedBooks.enumerated()), id: \.element.id) { index, book in
                    AppSettingsRow(
                        systemImage: "checkmark.seal",
                        title: LocalizedStringKey(book.title),
                        value: book.author,
                        hidesSeparator: index == translatedBooks.count - 1,
                        action: { openBook = book },
                        palette: palette
                    )
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "character.book.closed")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(palette.accent)
                .frame(width: 88, height: 88)
                .background(palette.accentSoft)
                .clipShape(Circle())

            Text("Nothing to translate yet")
                .font(Typography.control(20, weight: .bold))
                .foregroundStyle(palette.text)

            Text("Add an EPUB to your library and it will show up here, ready for an AI translation into your language.")
                .font(Typography.control(15))
                .foregroundStyle(palette.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.xxl)
    }

    // MARK: - Helpers

    /// Chunk counts are the only progress the backend reports; before the first
    /// chunk lands the bar shows the phase, not a fake percentage.
    private func progressValue(_ job: TranslationJob) -> Double {
        guard let total = job.totalChunks, total > 0,
              let done = job.translatedChunks else { return 0 }
        return Double(done) / Double(total)
    }

    private func phaseTitle(_ phase: TranslationJobPhase) -> String {
        switch phase {
        case .uploading: return String(localized: "Uploading")
        case .translating: return String(localized: "Translating")
        case .importingResult: return String(localized: "Importing")
        default: return String(localized: "Working")
        }
    }
}
