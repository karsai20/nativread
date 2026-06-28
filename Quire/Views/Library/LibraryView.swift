import SwiftUI
import UniformTypeIdentifiers

/// The shelf. Warm paper surface, serif wordmark, two-column cover grid.
struct LibraryView: View {
    @Environment(LibraryStore.self) private var library
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(StatsStore.self) private var statsStore
    @Environment(VocabularyStore.self) private var vocabularyStore
    @Environment(LocalizationStore.self) private var localizationStore
    @Environment(DictionaryProvider.self) private var dictionaryProvider
    @Environment(\.colorScheme) private var colorScheme

    @State private var isImporterPresented = false
    @State private var openBook: Book?
    @State private var importError: String?
    @State private var isStatsPresented = false
    @State private var isVocabularyPresented = false
    @State private var isSettingsPresented = false
    @State private var isImporting = false

    /// The shelf now carries its own editorial identity rather than morphing
    /// with the reading theme — the library is a place, the reader is the book.
    /// It follows the system light/dark appearance.
    private var palette: BrandPalette {
        BrandPalette.resolve(systemDark: colorScheme == .dark)
    }

    private var sortedBooks: [Book] {
        library.books.sorted {
            ($0.lastOpenedAt ?? $0.addedAt)
                > ($1.lastOpenedAt ?? $1.addedAt)
        }
    }

    /// The most recently touched in-progress book, featured as the hero.
    private var nowReadingBook: Book? {
        sortedBooks.first { $0.isStarted && !$0.isFinished }
    }

    var body: some View {
        ZStack {
            palette.background.ignoresSafeArea()

            if library.books.isEmpty {
                emptyState
            } else {
                shelf
            }

            if isImporting {
                LoadingOverlay(palette: palette, message: "Importing…")
                    .accessibilityIdentifier("library.importing")
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: isImporting)
        .onAppear {
            if ProcessInfo.processInfo.arguments
                .contains("-autoOpenFirstBook") {
                openBook = sortedBooks.first
            }
        }
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [
                UTType(filenameExtension: "epub") ?? .data
            ],
            allowsMultipleSelection: true
        ) { result in
            handleImport(result)
        }
        .fullScreenCover(item: $openBook) { book in
            ReaderView(
                book: book,
                library: library,
                settingsStore: settingsStore,
                statsStore: statsStore
            )
        }
        .sheet(isPresented: $isStatsPresented) {
            StatsView()
                .environment(statsStore)
                .environment(settingsStore)
        }
        .sheet(isPresented: $isVocabularyPresented) {
            VocabularyView()
                .environment(vocabularyStore)
                .environment(settingsStore)
        }
        .sheet(isPresented: $isSettingsPresented) {
            SettingsView()
                .environment(localizationStore)
                .environment(dictionaryProvider)
        }
        .alert(
            "Import failed",
            isPresented: Binding(
                get: { importError != nil },
                set: { if !$0 { importError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importError ?? "")
        }
    }

    // MARK: - Shelf

    private var shelf: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.md)
                    .padding(.bottom, Spacing.lg)

                if let book = nowReadingBook {
                    nowReadingHero(book)
                        .padding(.horizontal, Spacing.lg)
                        .padding(.bottom, Spacing.xl)
                }

                sectionLabel("Library")
                    .padding(.horizontal, Spacing.lg)
                    .padding(.bottom, Spacing.md)

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 22),
                        GridItem(.flexible(), spacing: 22)
                    ],
                    alignment: .leading,
                    spacing: 30
                ) {
                    ForEach(sortedBooks) { book in
                        Button {
                            openBook = book
                        } label: {
                            BookCard(
                                book: book,
                                coverURL: library.coverURL(for: book),
                                titleColor: palette.text,
                                captionColor: palette.secondaryText,
                                accentColor: palette.accent
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier(
                            "library.book.\(book.title)"
                        )
                        .contextMenu {
                            Button(role: .destructive) {
                                library.delete(book)
                            } label: {
                                Label("Delete book", systemImage: "trash")
                            }
                        }
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, 40)
            }
        }
    }

    /// A small uppercase, tracked section label with a trailing hairline rule —
    /// the editorial device that paces the shelf into named regions.
    private func sectionLabel(_ text: String) -> some View {
        HStack(spacing: Spacing.sm) {
            // LocalizedStringKey(text) so a String argument still localizes —
            // Text(String) would be verbatim and skip the catalog.
            Text(LocalizedStringKey(text))
                .font(Typography.eyebrow)
                .tracking(Typography.eyebrowTracking)
                .textCase(.uppercase)
                .foregroundStyle(palette.secondaryText)
            Rectangle()
                .fill(palette.hairline)
                .frame(height: Spacing.hairlineWidth)
        }
    }

    // MARK: - Now Reading hero

    /// The featured in-progress book: an oversized cover beside its title,
    /// author, and a russet progress rule. The shelf's editorial anchor.
    private func nowReadingHero(_ book: Book) -> some View {
        Button {
            openBook = book
        } label: {
            HStack(alignment: .top, spacing: Spacing.md) {
                BookCard.cover(
                    book: book,
                    coverURL: library.coverURL(for: book)
                )
                .frame(width: 104)
                .aspectRatio(2 / 3, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusSmall))
                .overlay(
                    RoundedRectangle(cornerRadius: Spacing.radiusSmall)
                        .strokeBorder(palette.hairline)
                )
                .shadow(
                    color: .black.opacity(palette.shadowOpacity),
                    radius: 12, x: 0, y: 6
                )

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Now Reading")
                        .font(Typography.eyebrow)
                        .tracking(Typography.eyebrowTracking)
                        .textCase(.uppercase)
                        .foregroundStyle(palette.accent)

                    Text(book.title)
                        .font(Typography.display(26))
                        .foregroundStyle(palette.text)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(book.author)
                        .font(Typography.meta())
                        .foregroundStyle(palette.secondaryText)
                        .lineLimit(1)

                    Spacer(minLength: Spacing.xs)

                    heroProgress(book)
                }
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("library.nowReading")
        .accessibilityLabel("Now reading \(book.title)")
    }

    private func heroProgress(_ book: Book) -> some View {
        let fraction = book.progress.bookFraction
        return VStack(alignment: .leading, spacing: Spacing.xxs) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(palette.hairline)
                    Capsule()
                        .fill(palette.accent)
                        .frame(width: max(2, proxy.size.width * fraction))
                }
            }
            .frame(height: 3)

            Text("\(Int((fraction * 100).rounded()))%")
                .font(Typography.meta(11))
                .foregroundStyle(palette.secondaryText)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Quire")
                    .font(Typography.display(40))
                    .foregroundStyle(palette.text)
                // Count interpolated as a String so the generated key is
                // "%@ book%@ on the shelf" (matches the catalog); Hungarian
                // renders the count and ignores the plural suffix.
                Text(
                    "\(String(library.books.count)) book\(library.books.count == 1 ? "" : "s") on the shelf"
                )
                .font(Typography.meta())
                .foregroundStyle(palette.secondaryText)
            }
            Spacer()
            HStack(spacing: Spacing.sm) {
                vocabularyButton
                statsButton
                settingsButton
                importButton
            }
        }
    }

    private var vocabularyButton: some View {
        Button {
            isVocabularyPresented = true
        } label: {
            Image(systemName: "character.book.closed")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(palette.accent)
                .frame(width: 40, height: 40)
                .background(
                    Circle().fill(palette.surface)
                )
        }
        .accessibilityIdentifier("library.vocabulary")
        .accessibilityLabel("My vocabulary")
    }

    private var statsButton: some View {
        Button {
            isStatsPresented = true
        } label: {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(palette.accent)
                .frame(width: 40, height: 40)
                .background(
                    Circle().fill(palette.surface)
                )
        }
        .accessibilityIdentifier("library.stats")
        .accessibilityLabel("Reading statistics")
    }

    private var settingsButton: some View {
        Button {
            isSettingsPresented = true
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(palette.accent)
                .frame(width: 40, height: 40)
                .background(
                    Circle().fill(palette.surface)
                )
        }
        .accessibilityIdentifier("library.settings")
        .accessibilityLabel("Settings")
    }

    private var importButton: some View {
        Button {
            isImporterPresented = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(palette.background)
                .frame(width: 40, height: 40)
                .background(Circle().fill(palette.accent))
        }
        .disabled(isImporting)
        .accessibilityIdentifier("library.import")
        .accessibilityLabel("Import book")
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(palette.surface)
                    .frame(width: 120, height: 120)
                Image(systemName: "books.vertical")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(palette.accent)
            }
            VStack(spacing: 6) {
                Text("Your shelf is empty")
                    .font(Typography.display(28))
                    .foregroundStyle(palette.text)
                Text("Add an EPUB from Files and start reading.")
                    .font(Typography.meta(14))
                    .foregroundStyle(palette.secondaryText)
            }
            Button {
                isImporterPresented = true
            } label: {
                Label("Add a book", systemImage: "plus")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(palette.background)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(palette.accent))
            }
            .disabled(isImporting)
            .accessibilityIdentifier("library.import.empty")
            .padding(.top, 6)
        }
        .padding(32)
    }

    // MARK: - Import

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard !urls.isEmpty else { return }
            importBooks(from: urls)
        case .failure(let error):
            importError = error.localizedDescription
        }
    }

    /// Runs the unzip + EPUB parse off the main thread so large books
    /// no longer freeze the shelf, then hops back to the main actor to
    /// surface progress and errors. `LibraryStore` is reference-shared
    /// and its mutations land via the @Observable book array.
    private func importBooks(from urls: [URL]) {
        isImporting = true
        let library = library
        Task {
            let failureMessage = await Task.detached(
                priority: .userInitiated
            ) { () -> String? in
                var firstFailure: String?
                for url in urls {
                    do {
                        try library.importBook(from: url)
                    } catch {
                        // Surface the first failure; remaining books in
                        // the batch are still attempted.
                        if firstFailure == nil {
                            firstFailure = error.localizedDescription
                        }
                    }
                }
                return firstFailure
            }.value
            isImporting = false
            if let failureMessage {
                importError = failureMessage
            }
        }
    }
}
