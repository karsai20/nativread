import SwiftUI

/// The full-screen reading surface: page web view underneath, tap zones
/// and swipe on top, chrome bars that melt away while reading.
struct ReaderView: View {
    @State private var viewModel: ReaderViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    init(
        book: Book,
        library: LibraryStore,
        settingsStore: SettingsStore,
        statsStore: StatsStore
    ) {
        let bounds = UIScreen.main.bounds
        _viewModel = State(initialValue: ReaderViewModel(
            book: book,
            library: library,
            settingsStore: settingsStore,
            statsStore: statsStore,
            pageSize: bounds.size
        ))
    }

    private var palette: ReaderPalette { viewModel.palette }

    var body: some View {
        ZStack {
            palette.background.ignoresSafeArea()

            if let error = viewModel.loadError {
                errorView(error)
            } else {
                // Taps, swipes and scrolling are handled inside the web
                // view by the JS engine so native text selection works.
                ReaderWebView(controller: viewModel.controller)
                    .ignoresSafeArea()
                chapterLoadingVeil
                nextChapterAffordance
            }

            chrome
        }
        .animation(
            .easeOut(duration: 0.2),
            value: viewModel.isChapterLoading
        )
        .statusBarHidden(!viewModel.isChromeVisible)
        .preferredColorScheme(
            // In system mode the reader must not override appearance,
            // otherwise the colour scheme it reads would be its own.
            viewModel.settings.themeMode == .system
                ? nil : (palette.isDark ? .dark : .light)
        )
        .onChange(of: colorScheme) {
            viewModel.setSystemDark(colorScheme == .dark)
        }
        .onAppear {
            viewModel.setSystemDark(colorScheme == .dark)
            viewModel.open()
            if ProcessInfo.processInfo.arguments
                .contains("-showTypographyPanel") {
                viewModel.activeSheet = .typography
            }
        }
        .onDisappear {
            viewModel.persistProgressNow()
        }
        .sheet(item: $viewModel.activeSheet) { sheet in
            switch sheet {
            case .contents:
                ContentsSheet(viewModel: viewModel)
            case .typography:
                TypographyPanel(viewModel: viewModel)
            case .search:
                SearchSheet(viewModel: viewModel)
            }
        }
    }

    // MARK: - Chapter loading veil

    /// A skeleton "page" that fills the reading area while a chapter
    /// loads, hiding the blank/half-painted WKWebView frame. It mirrors
    /// the reading margins, fades out (~200ms) when the engine reports
    /// the page is painted, and never covers the chrome bars below it.
    @ViewBuilder
    private var chapterLoadingVeil: some View {
        if viewModel.isChapterLoading {
            palette.background
                .overlay(alignment: .topLeading) {
                    SkeletonLines(palette: palette, lineCount: 9)
                        .padding(.horizontal, 28)
                        .padding(.top, 88)
                }
                .ignoresSafeArea()
                .accessibilityIdentifier("reader.loading")
                .accessibilityLabel("Loading chapter")
                .transition(.opacity)
                // Let taps fall through to the web view's tap zones the
                // instant content is ready; while shown it simply masks.
                .allowsHitTesting(false)
        }
    }

    // MARK: - Next chapter affordance (scroll flow)

    /// Floating pill at the end of a scrolled chapter: makes the
    /// chapter boundary visible and tappable. Pulling past the edge
    /// (overscroll) advances too; this is the discoverable half.
    @ViewBuilder
    private var nextChapterAffordance: some View {
        if viewModel.settings.pageFlow == .scroll,
           viewModel.isAtChapterEnd,
           viewModel.hasNextChapter,
           !viewModel.isChromeVisible {
            VStack {
                Spacer()
                Button {
                    viewModel.goToNextChapter()
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                        Text(viewModel.nextChapterTitle.isEmpty
                            ? "Next chapter"
                            : viewModel.nextChapterTitle)
                            .font(.system(size: 13, weight: .medium,
                                          design: .serif))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(
                        Capsule()
                            .fill(palette.background)
                            .shadow(
                                color: .black.opacity(0.18),
                                radius: 10, y: 3
                            )
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(palette.text.opacity(0.12))
                    )
                    .foregroundStyle(palette.accent)
                }
                .accessibilityIdentifier("reader.nextChapter")
                .padding(.bottom, 30)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(
                .easeOut(duration: 0.22),
                value: viewModel.isAtChapterEnd
            )
        }
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
        HStack(spacing: 16) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
            }
            .accessibilityIdentifier("reader.back")

            VStack(spacing: 1) {
                Text(viewModel.book?.title ?? "")
                    .font(.system(size: 13, weight: .semibold, design: .serif))
                    .lineLimit(1)
                Text(viewModel.currentChapterTitle)
                    .font(.system(size: 11))
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
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(chromeBackground)
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            ScrubberView(
                fraction: viewModel.bookFraction,
                accent: palette.accent,
                track: palette.secondaryText.opacity(0.25)
            ) { fraction in
                viewModel.scrub(toBookFraction: fraction)
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

                Text(pageLabel)
                    .font(.system(size: 12, weight: .medium))
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
                    viewModel.activeSheet = .typography
                } label: {
                    Text("Aa")
                        .font(.system(size: 17, weight: .semibold,
                                      design: .serif))
                }
                .padding(.leading, 18)
                .accessibilityIdentifier("reader.typography")
            }
        }
        .foregroundStyle(palette.text)
        .tint(palette.accent)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
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

    private var pageLabel: String {
        let percent = Int((viewModel.bookFraction * 100).rounded())
        return "\(viewModel.page + 1) / \(viewModel.pageCount) · \(percent)%"
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "book.closed")
                .font(.system(size: 40))
                .foregroundStyle(palette.secondaryText)
            Text("This book could not be opened")
                .font(.system(.headline, design: .serif))
            Text(message)
                .font(.footnote)
                .foregroundStyle(palette.secondaryText)
                .multilineTextAlignment(.center)
            Button("Back to Library") { dismiss() }
                .buttonStyle(.borderedProminent)
                .tint(palette.accent)
        }
        .foregroundStyle(palette.text)
        .padding(40)
    }
}

/// A slim, finger-friendly progress scrubber.
struct ScrubberView: View {
    let fraction: Double
    let accent: Color
    let track: Color
    let onScrub: (Double) -> Void

    @State private var dragFraction: Double?

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let current = dragFraction ?? fraction
            ZStack(alignment: .leading) {
                Capsule().fill(track).frame(height: 3)
                Capsule().fill(accent)
                    .frame(width: max(current * width, 0), height: 3)
                Circle()
                    .fill(accent)
                    .frame(width: 13, height: 13)
                    .offset(x: current * width - 6.5)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        dragFraction = min(
                            max(value.location.x / width, 0), 1
                        )
                    }
                    .onEnded { value in
                        let final = min(max(value.location.x / width, 0), 1)
                        dragFraction = nil
                        onScrub(final)
                    }
            )
        }
        .frame(height: 26)
    }
}
