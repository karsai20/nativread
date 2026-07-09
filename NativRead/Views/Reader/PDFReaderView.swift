import SwiftUI
import PDFKit

/// Full-screen PDF reading surface. Same chrome language as `ReaderView`
/// — melt-away top/bottom bars, shared scrubber, page label, bookmark —
/// over a fixed-layout PDFKit page instead of the reflowable web view.
struct PDFReaderView: View {
    @State private var viewModel: PDFReaderViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(VocabularyStore.self) private var vocabulary
    @Environment(LocalizationStore.self) private var localizationStore

    init(
        book: Book,
        library: LibraryStore,
        settingsStore: SettingsStore,
        statsStore: StatsStore,
        initialSystemDark: Bool
    ) {
        _viewModel = State(initialValue: PDFReaderViewModel(
            book: book,
            library: library,
            settingsStore: settingsStore,
            statsStore: statsStore,
            initialSystemDark: initialSystemDark
        ))
    }

    private var palette: ReaderPalette { viewModel.palette }

    var body: some View {
        ZStack {
            palette.background.ignoresSafeArea()

            if let error = viewModel.loadError {
                errorView(error)
            } else {
                pdfSurface
            }

            chrome
        }
        .statusBarHidden(!viewModel.isChromeVisible)
        .preferredColorScheme(palette.isDark ? .dark : .light)
        .onChange(of: colorScheme) {
            viewModel.setSystemDark(colorScheme == .dark)
        }
        .onAppear {
            viewModel.setSystemDark(colorScheme == .dark)
            viewModel.open()
        }
        .onDisappear {
            viewModel.persistProgressNow()
        }
        .sheet(item: $viewModel.activeSheet) { sheet in
            switch sheet {
            case .contents:
                PDFContentsSheet(viewModel: viewModel)
            case .search:
                PDFSearchSheet(viewModel: viewModel)
            case .appearance:
                PDFAppearanceSheet(viewModel: viewModel)
            }
        }
        .sheet(item: defineItem) { item in
            DefineView(
                word: item.word,
                palette: palette,
                defineLanguage: localizationStore.defineLanguage,
                context: viewModel.defineContext,
                onSave: { definition, source in
                    viewModel.saveToVocabulary(
                        definition: definition,
                        dictionarySource: source,
                        into: vocabulary
                    )
                },
                isAlreadySaved: vocabulary.contains(word: item.word)
            )
        }
    }

    @ViewBuilder
    private var pdfSurface: some View {
        ZStack {
            PDFKitView(
                documentURL: viewModel.documentURL,
                pageIndex: viewModel.page,
                isNight: viewModel.isNight,
                backgroundColor: UIColor(palette.background),
                onPageChange: { viewModel.setPage($0) },
                onTapZone: { viewModel.handleTap(zone: $0) },
                onDefine: { viewModel.define(selection: $0) }
            )
            .ignoresSafeArea()

            // Sepia: a warm multiply tint over the white page keeps images
            // and live selection intact (no re-render), unlike night invert.
            if let tint = viewModel.pageTint {
                tint
                    .blendMode(.multiply)
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
            }
        }
    }

    private var defineItem: Binding<DefineItemPDF?> {
        Binding(
            get: { viewModel.defineWord.map(DefineItemPDF.init) },
            set: { viewModel.defineWord = $0?.word }
        )
    }

    // MARK: - Chrome

    private var chrome: some View {
        VStack(spacing: 0) {
            if viewModel.isChromeVisible {
                topBar.transition(.move(edge: .top).combined(with: .opacity))
            }
            Spacer()
            if viewModel.isChromeVisible {
                bottomBar.transition(
                    .move(edge: .bottom).combined(with: .opacity)
                )
            }
        }
        .animation(.easeOut(duration: 0.22), value: viewModel.isChromeVisible)
    }

    private var topBar: some View {
        HStack(spacing: Spacing.md) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
            }
            .accessibilityIdentifier("reader.back")

            VStack(spacing: 2) {
                Text(viewModel.book?.title ?? "")
                    .font(Typography.title(15))
                    .lineLimit(1)
                Text(viewModel.currentChapterTitle)
                    .font(Typography.eyebrow)
                    .tracking(Typography.eyebrowTracking)
                    .textCase(.uppercase)
                    .foregroundStyle(palette.secondaryText)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)

            Button {
                viewModel.toggleBookmark()
            } label: {
                Image(systemName: viewModel.currentBookmark != nil
                    ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 16, weight: .medium))
            }
            .accessibilityIdentifier("reader.bookmark")
        }
        .foregroundStyle(palette.text)
        .tint(palette.accent)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
        .background(chromeBackground)
    }

    private var bottomBar: some View {
        VStack(spacing: Spacing.xs) {
            ScrubberView(
                fraction: viewModel.bookFraction,
                accent: palette.accent,
                track: palette.hairline.opacity(0.6)
            ) { fraction in
                viewModel.scrub(toFraction: fraction)
            }
            .accessibilityIdentifier("reader.scrubber")

            HStack {
                Button {
                    viewModel.activeSheet = .contents
                } label: {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 17))
                }
                .accessibilityIdentifier("reader.contents")

                Spacer()

                Text(viewModel.pageLabel)
                    .font(Typography.meta(12))
                    .foregroundStyle(palette.secondaryText)
                    .monospacedDigit()
                    .accessibilityIdentifier("reader.pageLabel")

                Spacer()

                Button {
                    viewModel.activeSheet = .search
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16))
                }
                .accessibilityIdentifier("reader.search")

                Button {
                    viewModel.activeSheet = .appearance
                } label: {
                    Image(systemName: "sun.max")
                        .font(.system(size: 16))
                }
                .padding(.leading, Spacing.md)
                .accessibilityIdentifier("reader.appearance")
            }
        }
        .foregroundStyle(palette.text)
        .tint(palette.accent)
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.xs)
        .background(chromeBackground)
    }

    private var chromeBackground: some View {
        palette.background
            .opacity(0.94)
            .overlay(palette.surface.opacity(0.5))
            .overlay(alignment: .bottom) {
                Rectangle().fill(palette.hairline).frame(height: 1)
            }
            .ignoresSafeArea()
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "doc.questionmark")
                .font(.system(size: 40))
                .foregroundStyle(palette.secondaryText)
            Text("This book could not be opened")
                .font(Typography.title(17))
            Text(message)
                .font(Typography.meta())
                .foregroundStyle(palette.secondaryText)
                .multilineTextAlignment(.center)
            Button("Back to Library") { dismiss() }
                .buttonStyle(.borderedProminent)
                .tint(palette.accent)
        }
        .foregroundStyle(palette.text)
        .padding(Spacing.xl)
    }
}

/// Identity wrapper so a PDF Define target can drive `.sheet(item:)`.
private struct DefineItemPDF: Identifiable {
    let word: String
    var id: String { word }
}
