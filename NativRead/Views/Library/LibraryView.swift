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
    @State private var isSettingsPresented = false
    @State private var isImporting = false
    @State private var isTranslationPickerPresented = false
    @State private var pendingTranslationBook: Book?
    @State private var translationBook: Book?

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

    private var translationCandidate: Book? {
        sortedBooks.first { $0.isTranslatableSource }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            palette.background.ignoresSafeArea()

            if library.books.isEmpty {
                emptyState
            } else {
                shelf
            }

            if !library.books.isEmpty {
                bottomActionBar
                    .padding(.horizontal, Spacing.lg)
                    .padding(.bottom, Spacing.md)
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
        .sheet(
            isPresented: $isTranslationPickerPresented,
            onDismiss: {
                if let book = pendingTranslationBook {
                    pendingTranslationBook = nil
                    translationBook = book
                }
            }
        ) {
            TranslationBookPickerSheet(
                books: sortedBooks.filter(\.isTranslatableSource),
                coverURL: { library.coverURL(for: $0) },
                onSelect: { book in
                    pendingTranslationBook = book
                    isTranslationPickerPresented = false
                }
            )
        }
        .sheet(isPresented: $isSettingsPresented) {
            SettingsView()
                .environment(localizationStore)
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
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, 116)
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

    /// The featured in-progress book on a raised surface card: the full cover
    /// at its true aspect (never cropped), beside the title, author, a russet
    /// progress rule, and a Continue affordance. The shelf's editorial anchor.
    private func nowReadingHero(_ book: Book) -> some View {
        Button {
            openBook = book
        } label: {
            HStack(alignment: .top, spacing: Spacing.md) {
                heroCover(book)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Now Reading")
                        .font(Typography.eyebrow)
                        .tracking(Typography.eyebrowTracking)
                        .textCase(.uppercase)
                        .foregroundStyle(palette.accent)

                    Text(book.title)
                        .font(Typography.display(28))
                        .foregroundStyle(palette.text)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(book.author)
                        .font(Typography.meta())
                        .foregroundStyle(palette.secondaryText)
                        .lineLimit(1)

                    Spacer(minLength: Spacing.sm)

                    heroProgress(book)
                    continueAffordance
                        .padding(.top, Spacing.xxs)
                }
                Spacer(minLength: 0)
            }
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Spacing.radiusCard)
                    .fill(palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Spacing.radiusCard)
                    .strokeBorder(palette.hairline)
            )
            .shadow(
                color: .black.opacity(palette.shadowOpacity * 0.5),
                radius: 16, x: 0, y: 8
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

    private var continueAffordance: some View {
        HStack(spacing: 6) {
            Image(systemName: "book.fill")
                .font(.system(size: 11, weight: .semibold))
            Text("Continue")
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundStyle(palette.background)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Capsule().fill(palette.accent))
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

            Text(percentReadText(fraction))
                .font(Typography.meta(11))
                .monospacedDigit()
                .foregroundStyle(palette.secondaryText)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                // Brand wordmark lives on the launch screen + app icon; the
                // library leads with the shelf itself. Count interpolated as
                // a String so the generated key is "%@ book%@ on the shelf"
                // (matches the catalog); Hungarian renders the count and
                // ignores the plural suffix.
                Text(
                    "\(String(library.books.count)) book\(library.books.count == 1 ? "" : "s") on the shelf"
                )
                .font(Typography.title(22))
                .foregroundStyle(palette.text)
            }
            Spacer()
            settingsButton
        }
    }

    private var settingsButton: some View {
        Button {
            isSettingsPresented = true
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(palette.accent)
                .frame(
                    width: Spacing.minTapTarget,
                    height: Spacing.minTapTarget
                )
                .background(
                    Circle().fill(palette.surface)
                )
        }
        .accessibilityIdentifier("library.settings")
        .accessibilityLabel("Settings")
    }

    // MARK: - Bottom actions

    private var bottomActionBar: some View {
        HStack(spacing: Spacing.sm) {
            bottomAction(
                title: "Translate",
                systemImage: "sparkles",
                accessibilityIdentifier: "library.translate"
            ) {
                isTranslationPickerPresented = true
            }
            .disabled(translationCandidate == nil)

            bottomAction(
                title: "Import",
                systemImage: "plus",
                accessibilityIdentifier: "library.import"
            ) {
                isImporterPresented = true
            }
            .disabled(isImporting)
        }
        .padding(Spacing.xs)
        .background {
            Capsule()
                .fill(palette.surface.opacity(
                    reduceTransparency
                        ? 1 : (colorScheme == .dark ? 0.94 : 0.97)
                ))
                .shadow(
                    color: .black.opacity(palette.shadowOpacity),
                    radius: 18, x: 0, y: 8
                )
        }
        .overlay {
            Capsule()
                .strokeBorder(palette.hairline, lineWidth: 0.8)
        }
    }

    private var translationRecoveryID: String {
        let tokenState = translationAuthStore.sessionToken ?? "signed-out"
        return "\(scenePhase)-\(tokenState)-\(translationStore.recoveryRevision)"
    }

    private func bottomAction(
        title: LocalizedStringKey,
        systemImage: String,
        accessibilityIdentifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .foregroundStyle(palette.text)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
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
                    .font(Typography.display(28))
                    .foregroundStyle(palette.text)
                Text("Add an EPUB, PDF, or text file and start reading.")
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
