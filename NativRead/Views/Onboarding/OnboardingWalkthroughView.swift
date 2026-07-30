import SwiftUI

/// Three beats that walk the core loop — add a book, ask for a translation,
/// let it finish without you. Each beat shows the app's own UI rather than an
/// illustration of it, and carries exactly one sentence, because the readers
/// this app is built for should never have to squint at a caption.
///
/// Progress is always explicit and user-controlled; nothing advances on a
/// timer. The app language is not asked for here — it follows the phone, and
/// Settings can override it later.
struct OnboardingWalkthroughView: View {
    var onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var page: OnboardingTourPage = .addBook
    @State private var movingForward = true

    private var palette: BrandPalette {
        BrandPalette.resolve(systemDark: colorScheme == .dark)
    }

    /// At accessibility sizes the sentence needs the whole screen, so the
    /// scene steps aside entirely rather than competing for room. This is what
    /// keeps the copy above the bottom bar without a scroll.
    private var showsScene: Bool { !dynamicTypeSize.isAccessibilitySize }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                OnboardingPaperBackground(palette: palette)

                ScrollView(showsIndicators: false) {
                    Group {
                        if proxy.size.width > proxy.size.height {
                            HStack(alignment: .center, spacing: Spacing.xxl) {
                                scene.frame(maxWidth: 390)
                                pageCopy.frame(maxWidth: 460, alignment: .leading)
                            }
                        } else {
                            VStack(alignment: .leading, spacing: Spacing.xl) {
                                scene.frame(maxWidth: .infinity)
                                pageCopy
                            }
                        }
                    }
                    .id(page)
                    .transition(pageTransition)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    // Centre the beat between the two bars — measured, not
                    // guessed. The old code subtracted a hardcoded 176pt for
                    // chrome that is actually taller than that, which is what
                    // pushed the last line underneath the primary button.
                    // A *minimum* height, so copy that outgrows the gap (long
                    // sentence, landscape, accessibility text) still scrolls
                    // instead of being clipped.
                    .frame(minHeight: proxy.size.height, alignment: .center)
                }
                .animation(
                    reduceMotion
                        ? nil
                        : .spring(response: 0.48, dampingFraction: 0.88),
                    value: page
                )
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) { topBar }
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
    }

    /// A progress rail rather than a step counter: three short bars fill up as
    /// the reader moves, and Skip stays available but visually secondary.
    private var topBar: some View {
        HStack(spacing: Spacing.md) {
            HStack(spacing: 6) {
                ForEach(OnboardingTourPage.allCases, id: \.rawValue) { item in
                    Capsule()
                        .fill(
                            item.rawValue <= page.rawValue
                                ? palette.accent
                                : palette.hairline
                        )
                        .frame(width: 26, height: 4)
                }
            }
            .accessibilityElement()
            .accessibilityLabel(stepText)
            .accessibilityIdentifier("onboarding.tour.progress")
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.24),
                value: page
            )

            Spacer()

            Button("Skip", action: onFinished)
                .font(Typography.control(15, weight: .semibold))
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                .foregroundStyle(palette.secondaryText)
                .frame(minWidth: 48, minHeight: Spacing.minTapTarget, alignment: .trailing)
                .accessibilityIdentifier("onboarding.tour.skip")
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.xs)
    }

    @ViewBuilder
    private var scene: some View {
        if showsScene {
            Group {
                switch page {
                case .addBook:
                    OnboardingShelfScene(palette: palette)
                case .translate:
                    OnboardingTranslateScene(palette: palette)
                case .wait:
                    OnboardingWaitingScene(
                        palette: palette,
                        isAnimated: !reduceMotion
                    )
                }
            }
            .frame(maxWidth: 420)
            .accessibilityHidden(true)
        }
    }

    /// One sentence. The last beat closes with the payoff: where the finished
    /// translation actually turns up, and what happens to the original. The
    /// end of an experience is what gets remembered, so the concrete outcome
    /// belongs here rather than a slogan on a welcome screen.
    private var pageCopy: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(page.title)
                .font(Typography.heading(titleSize))
                .dynamicTypeSize(...DynamicTypeSize.accessibility3)
                .tracking(Typography.headingTracking(titleSize))
                .foregroundStyle(palette.text)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("onboarding.tour.title")

            if page == .wait {
                Text("The finished translation lands on your shelf, beside the original.")
                    .font(Typography.control(17, weight: .semibold))
                    .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                    .foregroundStyle(palette.accent)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("onboarding.tour.promise")
            }
        }
        .frame(maxWidth: 560, alignment: .leading)
    }

    /// Back and Next sit side by side rather than stacked. Stacking cost a
    /// whole row of height on the screen with the least of it to spare, and
    /// left Back as a bare text link; abreast, both are real buttons and the
    /// sentence above gets the room back.
    private var bottomBar: some View {
        HStack(spacing: Spacing.sm) {
            if page != .addBook {
                AppPrimaryButton(
                    title: "Back",
                    tone: .secondary,
                    action: goBack,
                    palette: palette
                )
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                .accessibilityIdentifier("onboarding.tour.back")
                .frame(maxWidth: .infinity)
            }

            // Half-width buttons leave no room for a long label plus a glyph:
            // the finish action keeps the short label and drops the icon
            // rather than hyphenating across three lines.
            AppPrimaryButton(
                title: nextButtonTitle,
                systemImage: page == .wait ? nil : "arrow.right",
                action: advance,
                palette: palette
            )
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            .accessibilityIdentifier(
                page == .wait
                    ? "onboarding.tour.finish"
                    : "onboarding.tour.next"
            )
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.sm)
        .background(palette.background)
    }

    private var nextButtonTitle: LocalizedStringKey {
        page == .wait ? "To my shelf" : "Next"
    }

    /// `Typography.heading` is a fixed point size — it does not scale with
    /// Dynamic Type — so the one sentence on screen has to be stepped up by
    /// hand, or a reader who turned text size up would find everything larger
    /// except the words that matter. The scene yields its room in exchange.
    private var titleSize: CGFloat {
        if dynamicTypeSize.isAccessibilitySize { return 44 }
        return dynamicTypeSize >= .xxLarge ? 40 : 38
    }

    private var stepText: String {
        String.localizedStringWithFormat(
            String(localized: "Step %lld of %lld"),
            page.rawValue + 1,
            OnboardingTourPage.allCases.count
        )
    }

    private var pageTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .move(edge: movingForward ? .trailing : .leading)
                .combined(with: .opacity),
            removal: .move(edge: movingForward ? .leading : .trailing)
                .combined(with: .opacity)
        )
    }

    private func advance() {
        guard page != .wait else {
            onFinished()
            return
        }
        movingForward = true
        if let next = OnboardingTourPage(rawValue: page.rawValue + 1) {
            page = next
        }
    }

    private func goBack() {
        guard page != .addBook else { return }
        movingForward = false
        if let previous = OnboardingTourPage(rawValue: page.rawValue - 1) {
            page = previous
        }
    }
}

/// The three beats of the core loop. Each one states a fact about the product,
/// not a benefit: the scene beside it is doing the persuading.
private enum OnboardingTourPage: Int, CaseIterable {
    case addBook
    case translate
    case wait

    var title: LocalizedStringKey {
        switch self {
        case .addBook:
            return "Add a book in a language you don't read."
        case .translate:
            // The two cards beside this already show what a translation looks
            // like, so the sentence only has to price it.
            return "We translate the first chapter free."
        case .wait:
            return "You can close the app. We keep translating."
        }
    }
}
