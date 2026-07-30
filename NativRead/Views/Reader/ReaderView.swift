import SwiftUI

/// The full-screen reading surface: page web view underneath, tap zones
/// and swipe on top, chrome bars that melt away while reading.
struct ReaderView: View {
    @State private var viewModel: ReaderViewModel
    /// Whether the bottom-right reading menu is fanned out.
    @State private var isMenuOpen = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency)
    private var reduceTransparency

    init(
        book: Book,
        library: LibraryStore,
        settingsStore: SettingsStore,
        initialSystemDark: Bool
    ) {
        let bounds = UIScreen.main.bounds
        _viewModel = State(initialValue: ReaderViewModel(
            book: book,
            library: library,
            settingsStore: settingsStore,
            pageSize: bounds.size,
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
                // Taps, swipes and scrolling are handled inside the web
                // view by the JS engine so native text selection works.
                ReaderWebView(
                    controller: viewModel.controller,
                    onViewportChange: viewModel.viewportDidChange(to:)
                )
                    .ignoresSafeArea()
                chapterLoadingVeil
                nextChapterAffordance
            }

            chrome
        }
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.2),
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
        .onChange(of: reduceMotion) {
            viewModel.setReduceMotion(reduceMotion)
        }
        .onChange(of: viewModel.isChromeVisible) {
            // A collapsed chrome must never come back with the fan open.
            if !viewModel.isChromeVisible { isMenuOpen = false }
        }
        .onAppear {
            viewModel.setSystemDark(colorScheme == .dark)
            viewModel.setReduceMotion(reduceMotion)
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
            case .position:
                ReadingPositionSheet(viewModel: viewModel)
            case .typography:
                TypographyPanel(viewModel: viewModel)
            case .search:
                SearchSheet(viewModel: viewModel)
            }
        }
        .accessibilityAction(.escape) { dismiss() }
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
                    HStack(spacing: Spacing.xxs + 3) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                        Text(viewModel.nextChapterTitle.isEmpty
                            ? "Next chapter"
                            : viewModel.nextChapterTitle)
                            // Crimson Pro at 13pt feels like a deliberate label,
                            // not a system-default tappable hint.
                            .font(Typography.body(13))
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
                reduceMotion ? nil : .easeOut(duration: 0.22),
                value: viewModel.isAtChapterEnd
            )
        }
    }

    // MARK: - Chrome

    /// Two states, Apple-Books-like. Resting (reading): ambient book
    /// title above and page number below, no controls. Expanded (tap):
    /// floating bookmark / close circles, a "pages left in chapter"
    /// eyebrow up top, and a floating settings card down below.
    private var chrome: some View {
        ZStack {
            restingLabels
                .opacity(viewModel.isChromeVisible ? 0 : 1)
            VStack(spacing: 0) {
                if viewModel.isChromeVisible {
                    topChrome.transition(
                        .move(edge: .top).combined(with: .opacity)
                    )
                }
                Spacer()
                if viewModel.isChromeVisible {
                    bottomPanel.transition(
                        .move(edge: .bottom).combined(with: .opacity)
                    )
                }
            }
        }
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.22),
            value: viewModel.isChromeVisible
        )
    }

    /// Ambient labels that stay up while reading. They never intercept
    /// touches — the page behind them owns every gesture.
    private var restingLabels: some View {
        VStack {
            Text(viewModel.currentChapterTitle)
                .font(Typography.eyebrow)
                .tracking(Typography.eyebrowTracking)
                .textCase(.uppercase)
                .lineLimit(1)
                .padding(.horizontal, Spacing.xl)
            Spacer()
            Text("\(viewModel.estimatedBookPagesRead)")
                .font(Typography.meta(12))
                .monospacedDigit()
        }
        .foregroundStyle(palette.secondaryText.opacity(0.85))
        .padding(.vertical, Spacing.xs)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var topChrome: some View {
        ZStack {
            Text(String.localizedStringWithFormat(
                String(localized: "%lld pages left in chapter"),
                viewModel.pagesLeftInChapter
            ))
                .font(Typography.eyebrow)
                .tracking(Typography.eyebrowTracking)
                .textCase(.uppercase)
                .foregroundStyle(palette.secondaryText)
                .lineLimit(1)
                .padding(.horizontal, 64)
                .accessibilityIdentifier("reader.chapterPagesLeft")

            HStack {
                Spacer()
                floatingCircle(
                    icon: "xmark", identifier: "reader.back"
                ) {
                    dismiss()
                }
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.xs)
    }

    /// A small floating circular control, the Books-style chrome unit.
    private func floatingCircle(
        icon: String,
        identifier: String,
        isActive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(isActive ? palette.accent : palette.text)
                .frame(width: 48, height: 48)
                .background(floatingCircleBackground(isActive: isActive))
                .contentShape(Circle())
        }
        .accessibilityIdentifier(identifier)
    }

    private func floatingCircleBackground(isActive: Bool = false) -> some View {
        Circle()
            .fill(palette.background.opacity(reduceTransparency ? 1 : 0.96))
            .overlay {
                if isActive {
                    Circle().fill(
                        palette.accent.opacity(
                            ReaderControlStyle.selectedAccentOpacity
                        )
                    )
                }
            }
            .shadow(color: .black.opacity(0.14), radius: 8, y: 2)
            .overlay(
                Circle().strokeBorder(
                    isActive ? palette.accent : palette.hairline
                )
            )
    }

    /// Bottom chrome: pages-read pill on the left, and the Books-style
    /// menu on the right — one floating icon that fans out into the
    /// reader's tools, with a share / rotation-lock / bookmark row at
    /// the very bottom.
    private var bottomPanel: some View {
        ZStack(alignment: .bottom) {
            positionNumber
                .frame(maxWidth: .infinity)
            HStack {
                Spacer()
                menuFan
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.bottom, Spacing.xs)
    }

    /// Bare "read / total" number, bottom center — no pill chrome.
    /// Still a button: it opens the position navigator.
    private var positionNumber: some View {
        Button {
            viewModel.activeSheet = .position
        } label: {
            Text(pageLabel)
                .font(Typography.meta(13))
                .monospacedDigit()
                .foregroundStyle(palette.secondaryText)
                .frame(minHeight: Spacing.minTapTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("reader.position")
        .accessibilityLabel(Text("Position in book: \(pageLabel)"))
    }

    private var menuFan: some View {
        VStack(alignment: .trailing, spacing: Spacing.sm) {
            if isMenuOpen {
                Group {
                    floatingCircle(
                        icon: "list.bullet", identifier: "reader.contents"
                    ) {
                        viewModel.activeSheet = .contents
                    }
                    .accessibilityLabel(Text("Contents"))
                    .transition(fanTransition(delay: 0.15))

                    floatingCircle(
                        icon: "magnifyingglass", identifier: "reader.search"
                    ) {
                        viewModel.activeSheet = .search
                    }
                    .accessibilityLabel(Text("Search"))
                    .transition(fanTransition(delay: 0.10))

                    Button {
                        viewModel.activeSheet = .typography
                    } label: {
                        // Crimson Pro "Aa" echoes the reader's typeface.
                        Text("Aa")
                            .font(Typography.title(19))
                            .foregroundStyle(palette.text)
                            .frame(width: 48, height: 48)
                            .background(floatingCircleBackground())
                            .contentShape(Circle())
                    }
                    .accessibilityIdentifier("reader.typography")
                    .accessibilityLabel(Text("Themes & settings"))
                    .transition(fanTransition(delay: 0.05))

                    HStack(spacing: Spacing.sm) {
                        if let url = viewModel.bookFileURL {
                            ShareLink(item: url) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(
                                        size: 18, weight: .semibold
                                    ))
                                    .foregroundStyle(palette.text)
                                    .frame(width: 48, height: 48)
                                    .background(floatingCircleBackground())
                                    .contentShape(Circle())
                            }
                            .accessibilityIdentifier("reader.share")
                            .accessibilityLabel(Text("Share book"))
                        }

                        floatingCircle(
                            icon: viewModel.isOrientationLocked
                                ? "lock.rotation" : "rotate.right",
                            identifier: "reader.rotationLock",
                            isActive: viewModel.isOrientationLocked
                        ) {
                            viewModel.toggleOrientationLock()
                            AppDelegate.lockPortrait =
                                viewModel.isOrientationLocked
                            AppDelegate.refreshOrientationLock()
                        }
                        .accessibilityLabel(Text(
                            viewModel.isOrientationLocked
                                ? "Unlock rotation" : "Lock rotation"
                        ))

                        floatingCircle(
                            icon: viewModel.currentBookmark != nil
                                ? "bookmark.fill" : "bookmark",
                            identifier: "reader.bookmark"
                        ) {
                            viewModel.toggleBookmark()
                        }
                        .accessibilityLabel(Text(
                            viewModel.currentBookmark != nil
                                ? "Remove bookmark" : "Add bookmark"
                        ))
                    }
                    .transition(fanTransition(delay: 0))
                }
            }

            floatingCircle(
                icon: isMenuOpen ? "chevron.down" : "ellipsis",
                identifier: "reader.menu"
            ) {
                isMenuOpen.toggle()
            }
            .accessibilityLabel(Text("Reading menu"))
        }
        .animation(
            reduceMotion
                ? nil : .spring(response: 0.34, dampingFraction: 0.72),
            value: isMenuOpen
        )
    }

    /// Staggered pop for the fanned-out menu: each item springs up from
    /// the menu button, the nearest first — the delay makes the fan
    /// visibly cascade instead of appearing as one block.
    private func fanTransition(delay: Double) -> AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .scale(scale: 0.3, anchor: .bottomTrailing)
            .combined(with: .opacity)
            .combined(with: .offset(y: 16))
            .animation(
                .spring(response: 0.34, dampingFraction: 0.72)
                    .delay(delay)
            )
    }

    /// "read / total" whole-book pages at the current typography.
    private var pageLabel: String {
        "\(viewModel.estimatedBookPagesRead) / "
            + "\(viewModel.estimatedBookPageCount)"
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "book.closed")
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

/// Expanded whole-book navigator. The native Slider supplies the adjustable
/// accessibility semantics that the old hand-built 13pt scrubber could not.
private struct ReadingPositionSheet: View {
    @Bindable var viewModel: ReaderViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var draftFraction: Double
    @State private var isEditing = false

    private var palette: ReaderPalette { viewModel.palette }

    init(viewModel: ReaderViewModel) {
        self.viewModel = viewModel
        _draftFraction = State(initialValue: viewModel.bookFraction)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            header

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(viewModel.currentChapterTitle)
                    .font(Typography.title(20))
                    .foregroundStyle(palette.text)
                    .lineLimit(2)
                    .textSelection(.disabled)

                HStack {
                    Text("Chapter \(viewModel.chapterPositionText)")
                    Spacer()
                    Text("\(displayPercent)%")
                        .monospacedDigit()
                }
                .font(Typography.meta(13))
                .foregroundStyle(palette.secondaryText)
            }

            Slider(
                value: $draftFraction,
                in: 0...1,
                onEditingChanged: handleEditingChanged
            )
            .tint(palette.accent)
            .accessibilityLabel("Position in book")
            .accessibilityValue("\(displayPercent)%")
            .accessibilityIdentifier("reader.position.slider")

            HStack(spacing: Spacing.sm) {
                chapterButton(
                    title: "Previous chapter",
                    icon: "chevron.left",
                    identifier: "reader.position.previousChapter",
                    enabled: viewModel.spineIndex > 0
                ) {
                    if viewModel.goToPreviousChapter() {
                        draftFraction = viewModel.bookFraction
                    }
                }
                chapterButton(
                    title: "Next chapter",
                    icon: "chevron.right",
                    identifier: "reader.position.nextChapter",
                    enabled: viewModel.hasNextChapter
                ) {
                    if viewModel.goToNextChapter() {
                        draftFraction = viewModel.bookFraction
                    }
                }
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.xl)
        .foregroundStyle(palette.text)
        .background(palette.background.ignoresSafeArea())
        .presentationDetents([.height(320), .medium])
        .presentationDragIndicator(.hidden)
        .onChange(of: viewModel.bookFraction) { _, newValue in
            if !isEditing { draftFraction = newValue }
        }
    }

    private var displayPercent: Int {
        Int((draftFraction * 100).rounded())
    }

    private var header: some View {
        HStack {
            Text("Position in book")
                .font(Typography.display(28))
            Spacer()
            Button("Done") { dismiss() }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(palette.accent)
                .accessibilityIdentifier("reader.position.done")
        }
    }

    private func handleEditingChanged(_ editing: Bool) {
        isEditing = editing
        if !editing {
            viewModel.scrub(toBookFraction: draftFraction)
        }
    }

    private func chapterButton(
        title: LocalizedStringKey,
        icon: String,
        identifier: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(Typography.body(14))
                .frame(maxWidth: .infinity, minHeight: Spacing.minTapTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.bordered)
        .tint(palette.accent)
        .disabled(!enabled)
        .accessibilityIdentifier(identifier)
    }
}
