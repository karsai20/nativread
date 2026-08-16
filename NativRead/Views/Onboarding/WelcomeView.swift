import SwiftUI

/// The first-launch welcome: one promise, then one choice. Screen one is a
/// staged-reveal introduction; screen two lets the reader pick how pages
/// should move (slide, curl, or scroll) before landing on the shelf. The
/// choice writes straight into `SettingsStore` and stays adjustable from
/// the reader's typography panel.
///
/// The app language is not asked for here — it follows the phone, and
/// Settings can override it later.
struct WelcomeView: View {
    var onFinished: () -> Void

    @Environment(SettingsStore.self) private var settingsStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private enum Step {
        case welcome, readingMode
    }

    /// How many reveal stages are visible on the welcome step. Stages:
    /// 0 nothing, 1 scene, 2 headline, 3 value line, 4 button.
    @State private var revealedStage = 0
    @State private var step: Step = .welcome
    @State private var selectedMode: WelcomeReadingMode = .slide

    private static let stageCount = 4

    private var palette: BrandPalette {
        BrandPalette.resolve(systemDark: colorScheme == .dark)
    }

    /// At accessibility sizes the copy needs the whole screen, so the scene
    /// steps aside rather than competing for room — same rule the old
    /// walkthrough used.
    private var showsScene: Bool { !dynamicTypeSize.isAccessibilitySize }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                OnboardingPaperBackground(palette: palette)

                ScrollView(showsIndicators: false) {
                    Group {
                        switch step {
                        case .welcome:
                            welcomeContent
                        case .readingMode:
                            readingModeContent
                        }
                    }
                    .transition(stepTransition)
                    .padding(Spacing.lg)
                    .frame(maxWidth: 640, alignment: .leading)
                    .frame(maxWidth: .infinity)
                    // Minimum height, not exact: copy that outgrows the
                    // screen (accessibility text, landscape) scrolls
                    // instead of being clipped.
                    .frame(minHeight: proxy.size.height, alignment: .center)
                }
                .animation(
                    reduceMotion
                        ? nil
                        : .spring(response: 0.48, dampingFraction: 0.88),
                    value: step
                )
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
        // One soft tap when the button lands and on each step change.
        .sensoryFeedback(.impact(weight: .light), trigger: revealedStage) {
            _, new in new == Self.stageCount
        }
        .sensoryFeedback(.impact(weight: .light), trigger: step)
        .onAppear(perform: reveal)
    }

    // MARK: - Step 1: the promise

    private var welcomeContent: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            if showsScene {
                OnboardingShelfScene(palette: palette)
                    .frame(maxWidth: .infinity)
                    // Cancels the step's own inset so the shelf runs past both
                    // edges; a shelf that stops short of them reads as a strip.
                    .padding(.horizontal, -Spacing.lg)
                    .accessibilityHidden(true)
                    .opacity(revealedStage >= 1 ? 1 : 0)
                    .offset(y: revealedStage >= 1 ? 0 : 24)
            }

            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Any book. Your language.")
                    .font(Typography.heading(titleSize))
                    .dynamicTypeSize(...DynamicTypeSize.accessibility3)
                    .tracking(Typography.headingTracking(titleSize))
                    .foregroundStyle(palette.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("welcome.title")
                    .opacity(revealedStage >= 2 ? 1 : 0)
                    .offset(y: revealedStage >= 2 ? 0 : 16)

                Text("Bring a book you can't read. We translate the first chapter free.")
                    .font(Typography.control(17, weight: .semibold))
                    .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                    .foregroundStyle(palette.accent)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("welcome.subtitle")
                    .opacity(revealedStage >= 3 ? 1 : 0)
                    .offset(y: revealedStage >= 3 ? 0 : 16)
            }
            .frame(maxWidth: 560, alignment: .leading)
        }
    }

    // MARK: - Step 2: how pages move

    private var readingModeContent: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("How do you like to read?")
                .font(Typography.heading(titleSize))
                .dynamicTypeSize(...DynamicTypeSize.accessibility3)
                .tracking(Typography.headingTracking(titleSize))
                .foregroundStyle(palette.text)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("welcome.mode.title")

            OnboardingModePreview(mode: selectedMode, palette: palette)
                .frame(maxWidth: .infinity, alignment: .center)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                modePicker

                Text(selectedMode.subtitle)
                    .font(Typography.meta())
                    .foregroundStyle(palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .animation(.easeInOut(duration: 0.2), value: selectedMode)
            }

            Text("Change this later in the reading menu.")
                .font(Typography.meta())
                .foregroundStyle(palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: 560, alignment: .leading)
    }

    /// Three segments under the sample page. Picking one plays that turn on
    /// the page above, so the choice is made by watching, not by reading.
    private var modePicker: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(WelcomeReadingMode.allCases) { mode in
                modeSegment(mode)
            }
        }
    }

    private func modeSegment(_ mode: WelcomeReadingMode) -> some View {
        let isSelected = mode == selectedMode
        return Button {
            selectedMode = mode
        } label: {
            VStack(spacing: Spacing.xxs) {
                Image(systemName: mode.icon)
                    .font(.system(size: 17, weight: .semibold))
                Text(mode.title)
                    .font(Typography.control(13, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(isSelected ? palette.background : palette.text)
            .padding(.vertical, Spacing.xs)
            .frame(maxWidth: .infinity, minHeight: Spacing.minTapTarget)
            .background(isSelected ? palette.accent : palette.surface)
            .clipShape(
                RoundedRectangle(cornerRadius: Spacing.radiusCard, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: Spacing.radiusCard, style: .continuous)
                    .strokeBorder(
                        isSelected ? palette.accent : palette.hairline,
                        lineWidth: isSelected ? 1.5 : Spacing.hairlineWidth
                    )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityIdentifier("welcome.mode.\(mode.rawValue)")
    }

    // MARK: - Chrome

    private var bottomBar: some View {
        Group {
            switch step {
            case .welcome:
                AppPrimaryButton(
                    title: "Next",
                    systemImage: "arrow.right",
                    action: advanceToReadingMode,
                    palette: palette
                )
                .accessibilityIdentifier("welcome.continue")
                .opacity(revealedStage >= Self.stageCount ? 1 : 0)
            case .readingMode:
                AppPrimaryButton(
                    title: "To my shelf",
                    action: finish,
                    palette: palette
                )
                .accessibilityIdentifier("welcome.finish")
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .frame(maxWidth: 592)
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.sm)
        // Bar spans the full width on iPad; only the button is capped.
        .frame(maxWidth: .infinity)
        .background(palette.background)
    }

    /// `Typography.heading` is a fixed point size — it does not scale with
    /// Dynamic Type — so the headline is stepped up by hand at large sizes.
    private var titleSize: CGFloat {
        if dynamicTypeSize.isAccessibilitySize { return 44 }
        return dynamicTypeSize >= .xxLarge ? 40 : 38
    }

    private var stepTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }

    private func advanceToReadingMode() {
        selectedMode = WelcomeReadingMode.current(from: settingsStore.settings)
        step = .readingMode
    }

    private func finish() {
        settingsStore.update { current in
            var next = current
            next.pageFlow = selectedMode.flow
            if let transition = selectedMode.transition {
                next.pageTransition = transition
            }
            return next
        }
        onFinished()
    }

    private func reveal() {
        guard !reduceMotion else {
            revealedStage = Self.stageCount
            return
        }
        for stage in 1...Self.stageCount {
            withAnimation(
                .spring(response: 0.55, dampingFraction: 0.85)
                    .delay(0.15 + Double(stage - 1) * 0.35)
            ) {
                revealedStage = stage
            }
        }
    }
}

/// The three curated reading styles the welcome offers. A mode maps onto
/// the reader's real `pageFlow` + `pageTransition` settings; the full
/// matrix stays available in the typography panel.
enum WelcomeReadingMode: String, CaseIterable, Identifiable {
    case slide
    case curl
    case scroll

    var id: String { rawValue }

    var flow: PageFlow {
        self == .scroll ? .scroll : .paged
    }

    /// `nil` leaves the persisted transition untouched (scroll ignores it).
    var transition: PageTransition? {
        switch self {
        case .slide: return .slide
        case .curl: return .curl
        case .scroll: return nil
        }
    }

    var icon: String {
        switch self {
        case .slide: return "arrow.left.and.right"
        case .curl: return "book.pages"
        case .scroll: return "arrow.up.and.down"
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .slide: return "Turn pages"
        case .curl: return "Page curl"
        case .scroll: return "Scroll"
        }
    }

    var subtitle: LocalizedStringKey {
        switch self {
        case .slide: return "Pages slide side to side."
        case .curl: return "Pages curl like real paper."
        case .scroll: return "One column, no page turns."
        }
    }

    /// The mode matching what is already persisted, so reopening the
    /// picker reflects reality instead of resetting to the default.
    static func current(from settings: ReaderSettings) -> WelcomeReadingMode {
        if settings.pageFlow == .scroll { return .scroll }
        return settings.pageTransition == .curl ? .curl : .slide
    }
}
