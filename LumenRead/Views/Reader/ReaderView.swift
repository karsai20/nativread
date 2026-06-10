import SwiftUI

/// The full-screen reading surface: page web view underneath, tap zones
/// and swipe on top, chrome bars that melt away while reading.
struct ReaderView: View {
    @State private var viewModel: ReaderViewModel
    @Environment(\.dismiss) private var dismiss

    init(book: Book, library: LibraryStore, settingsStore: SettingsStore) {
        let bounds = UIScreen.main.bounds
        _viewModel = State(initialValue: ReaderViewModel(
            book: book,
            library: library,
            settingsStore: settingsStore,
            pageSize: bounds.size
        ))
    }

    private var theme: ReaderTheme { viewModel.settings.theme }

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()

            if let error = viewModel.loadError {
                errorView(error)
            } else {
                ReaderWebView(controller: viewModel.controller)
                    .ignoresSafeArea()
                pageTurnOverlay
            }

            chrome
        }
        .statusBarHidden(!viewModel.isChromeVisible)
        .preferredColorScheme(theme.isDark ? .dark : .light)
        .onAppear {
            viewModel.open()
            if ProcessInfo.processInfo.arguments
                .contains("-showTypographyPanel") {
                viewModel.activeSheet = .typography
            }
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

    // MARK: - Gestures

    private var pageTurnOverlay: some View {
        GeometryReader { proxy in
            HStack(spacing: 0) {
                Color.clear
                    .contentShape(Rectangle())
                    .frame(width: proxy.size.width * 0.24)
                    .onTapGesture { viewModel.prevPage() }
                    .accessibilityLabel("Previous page")
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.22)) {
                            viewModel.isChromeVisible.toggle()
                        }
                    }
                    .accessibilityLabel("Toggle controls")
                Color.clear
                    .contentShape(Rectangle())
                    .frame(width: proxy.size.width * 0.24)
                    .onTapGesture { viewModel.nextPage() }
                    .accessibilityLabel("Next page")
            }
        }
        .gesture(
            DragGesture(minimumDistance: 28)
                .onEnded { value in
                    guard abs(value.translation.width)
                        > abs(value.translation.height) else { return }
                    if value.translation.width < 0 {
                        viewModel.nextPage()
                    } else {
                        viewModel.prevPage()
                    }
                }
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
                    .foregroundStyle(theme.secondaryText)
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
        .foregroundStyle(theme.text)
        .tint(theme.accent)
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(chromeBackground)
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            ScrubberView(
                fraction: viewModel.bookFraction,
                accent: theme.accent,
                track: theme.secondaryText.opacity(0.25)
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
                    .foregroundStyle(theme.secondaryText)
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
        .foregroundStyle(theme.text)
        .tint(theme.accent)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(chromeBackground)
    }

    private var chromeBackground: some View {
        theme.background
            .opacity(0.94)
            .overlay(theme.text.opacity(0.04))
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
                .foregroundStyle(theme.secondaryText)
            Text("This book could not be opened")
                .font(.system(.headline, design: .serif))
            Text(message)
                .font(.footnote)
                .foregroundStyle(theme.secondaryText)
                .multilineTextAlignment(.center)
            Button("Back to Library") { dismiss() }
                .buttonStyle(.borderedProminent)
                .tint(theme.accent)
        }
        .foregroundStyle(theme.text)
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
