import SwiftUI
import UniformTypeIdentifiers

/// The shelf. Warm paper surface, serif wordmark, two-column cover grid.
struct LibraryView: View {
    @Environment(LibraryStore.self) private var library
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(TranslationStore.self) private var translationStore
    @Environment(TranslationAuthStore.self) private var translationAuthStore
    @Environment(LocalizationStore.self) private var localizationStore
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceTransparency)
    private var reduceTransparency

    @State private var isImporterPresented = false
    @State private var openBook: Book?
    @State private var importError: String?
    @State private var isImporting = false
    @State private var translationBook: Book?
    @State private var searchText = ""

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

    /// The grid's contents. Search matches title or author, case- and
    /// diacritic-insensitively so "arvizturo" finds "Árvíztűrő".
    private var visibleBooks: [Book] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return sortedBooks }
        return sortedBooks.filter { book in
            [book.title, book.author].contains {
                $0.range(
                    of: query,
                    options: [.caseInsensitive, .diacriticInsensitive]
                ) != nil
            }
        }
    }

    /// The most recently touched in-progress book, featured as the hero.
    private var nowReadingBook: Book? {
        sortedBooks.first { $0.isStarted && !$0.isFinished }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
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
                UTType(filenameExtension: "epub") ?? .data,
                UTType(filenameExtension: "azw3") ?? .data,
                UTType(filenameExtension: "mobi") ?? .data,
                .pdf,
                .plainText
            ],
            allowsMultipleSelection: true
        ) { result in
            handleImport(result)
        }
        .fullScreenCover(item: $openBook) { book in
            // PDF is fixed-layout and needs the PDFKit reader; EPUB and the
            // synthesized-XHTML TXT share the reflowable web reader.
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
        .sheet(item: $translationBook) { book in
            TranslationSheet(book: book)
                .environment(translationStore)
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
        .task(id: translationRecoveryID) {
            guard scenePhase == .active else { return }
            await TranslationRecovery.reconcilePendingJobs(
                translations: translationStore,
                library: library,
                settings: settingsStore,
                auth: translationAuthStore
            )
        }
    }

    // MARK: - Shelf

    private var shelf: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                header
                searchField

                if let book = nowReadingBook, searchText.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        AppSectionLabel(title: "Continue reading", palette: palette)
                        nowReadingHero(book)
                    }
                }

                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text(searchText.isEmpty ? "All books" : "Results")
                        .font(Typography.heading(22, relativeTo: .title2))
                        .tracking(Typography.headingTracking(22))
                        .foregroundStyle(palette.text)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("library.grid.heading")

                    if visibleBooks.isEmpty {
                        Text("No books match your search.")
                            .font(Typography.control(15))
                            .foregroundStyle(palette.secondaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, Spacing.lg)
                    } else {
                        bookGrid
                    }
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.xl)
        }
    }

    private var bookGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 22),
                GridItem(.flexible(), spacing: 22)
            ],
            alignment: .leading,
            spacing: 30
        ) {
            ForEach(visibleBooks) { book in
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
                            if book.canExportTranslatedEPUB {
                                ShareLink(item: library.storedFileURL(for: book)) {
                                    Label(
                                        "Export translated EPUB",
                                        systemImage: "square.and.arrow.up"
                                    )
                                }
                            }
                            if book.isTranslatableSource {
                                Button {
                                    translationBook = book
                                } label: {
                                    Label(
                                        "Translate book",
                                        systemImage: "sparkles"
                                    )
                                }
                            }
                            Button(role: .destructive) {
                                library.delete(book)
                            } label: {
                                Label("Delete book", systemImage: "trash")
                            }
                }
            }
        }
    }

    // MARK: - Now Reading hero

    /// The featured in-progress book on a raised surface card: the full cover
    /// at its true aspect (never cropped), beside the title, author, a russet
    /// progress rule, and a Continue affordance. The shelf's editorial anchor.
    private func nowReadingHero(_ book: Book) -> some View {
        Button {
            openBook = book
        } label: {
            HStack(alignment: .center, spacing: Spacing.md) {
                heroCover(book)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    AppPill(
                        title: book.format.rawValue.uppercased(),
                        tone: .accent,
                        palette: palette
                    )

                    Text(book.title)
                        .font(Typography.control(19, weight: .bold))
                        .foregroundStyle(palette.text)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(book.author)
                        .font(Typography.control(15))
                        .foregroundStyle(palette.secondaryText)
                        .lineLimit(1)

                    heroProgress(book)
                        .padding(.top, Spacing.xxs)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(palette.tertiaryText)
            }
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Spacing.radiusGroup, style: .continuous)
                    .fill(palette.surface)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("library.nowReading")
        .accessibilityLabel("Now reading \(book.title)")
    }

    /// The hero cover rendered at its real aspect ratio so nothing is cropped —
    /// the fix for the "compressed cover" the grid's uniform 2:3 box caused.
    @ViewBuilder
    private func heroCover(_ book: Book) -> some View {
        let width: CGFloat = 128
        let shape = RoundedRectangle(cornerRadius: Spacing.radiusSmall)
        Group {
            if let url = library.coverURL(for: book),
               let image = UIImage(contentsOfFile: url.path) {
                // Width-bound only: height follows the cover's true aspect, so
                // nothing is cropped or squeezed regardless of source ratio.
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: width)
            } else {
                GeneratedCover(title: book.title, author: book.author)
                    .frame(width: width, height: width * 1.5)
            }
        }
        .clipShape(shape)
        .overlay(shape.strokeBorder(palette.hairline))
        .shadow(
            color: .black.opacity(palette.shadowOpacity),
            radius: 14, x: 0, y: 8
        )
    }


    /// "40% read" → "40% elolvasva", localised via the app-language bundle.
    private func percentReadText(_ fraction: Double) -> String {
        let percent = Int((fraction * 100).rounded())
        let format = localizationStore.localizedString(
            "%@%% read", value: "%@%% read"
        )
        return String(format: format, "\(percent)")
    }

    private func heroProgress(_ book: Book) -> some View {
        let fraction = book.progress.bookFraction
        return HStack(spacing: Spacing.sm) {
            AppProgressTrack(value: fraction, palette: palette)

            Text(percentReadText(fraction))
                .font(Typography.control(13, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(palette.secondaryText)
                .fixedSize()
        }
    }

    private var header: some View {
        AppLargeTitleHeader(
            title: "Library",
            subtitle: shelfSubtitle,
            palette: palette
        ) {
            AppIconButton(
                systemImage: "plus",
                label: "Add a book",
                isSelected: false,
                palette: palette
            ) {
                isImporterPresented = true
            }
            .accessibilityIdentifier("library.import")
            .disabled(isImporting)
        }
    }

    /// Count interpolated as a String so the generated key stays
    /// "%@ book%@ · stored on this device"; Hungarian renders the count and
    /// ignores the plural suffix.
    private var shelfSubtitle: String {
        let count = library.books.count
        let format = localizationStore.localizedString(
            "%@ book%@ · stored on this device",
            value: "%@ book%@ · stored on this device"
        )
        return String(format: format, String(count), count == 1 ? "" : "s")
    }

    private var searchField: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(palette.secondaryText)

            TextField("Search your library", text: $searchText)
                .font(Typography.control(16))
                .foregroundStyle(palette.text)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .accessibilityIdentifier("library.search")

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(palette.tertiaryText)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, Spacing.md)
        .frame(minHeight: 50)
        .background(palette.surface)
        .clipShape(Capsule(style: .continuous))
        .overlay(Capsule(style: .continuous).strokeBorder(palette.hairline))
    }

    private var translationRecoveryID: String {
        let tokenState = translationAuthStore.sessionToken ?? "signed-out"
        return "\(scenePhase)-\(tokenState)-\(translationStore.recoveryRevision)"
    }


    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.md)
            Spacer(minLength: 0)
            emptyContent
            Spacer(minLength: 88)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyContent: some View {
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
                    .font(Typography.heading(26, relativeTo: .title))
                    .tracking(Typography.headingTracking(26))
                    .foregroundStyle(palette.text)
                Text("Add an EPUB, PDF, or text file and start reading.")
                    .font(Typography.control(15))
                    .foregroundStyle(palette.secondaryText)
                    .multilineTextAlignment(.center)
            }
            AppPrimaryButton(
                title: "Add a book",
                systemImage: "plus",
                action: { isImporterPresented = true },
                palette: palette
            )
            .fixedSize(horizontal: true, vertical: false)
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
