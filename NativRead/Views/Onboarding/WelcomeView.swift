import SwiftUI

/// The first-launch welcome: one promise, then the proof. Screen one is a
/// staged-reveal introduction over a shelf of books in the reader's own
/// language; screen two translates a page of a book they cannot read in
/// front of them, then lands on the shelf.
///
/// Nothing here asks the reader to configure anything — the app language
/// follows the phone, and how pages move lives in the reader's typography
/// panel where it can be felt against real text.
struct WelcomeView: View {
    var onFinished: () -> Void

    @Environment(LocalizationStore.self) private var localizationStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private enum Step {
        case welcome, translation
    }

    /// How many reveal stages are visible on the welcome step. Stages:
    /// 0 nothing, 1 scene, 2 headline, 3 value line, 4 button.
    @State private var revealedStage = 0
    @State private var step: Step = .welcome

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
                        case .translation:
                            translationContent
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
                OnboardingShelfScene(
                    books: OnboardingShelf.rows(for: localizationStore.bundleLanguage),
                    palette: palette
                )
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

    // MARK: - Step 2: the translation, happening

    private var translationContent: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("Read it in your language.")
                .font(Typography.heading(titleSize))
                .dynamicTypeSize(...DynamicTypeSize.accessibility3)
                .tracking(Typography.headingTracking(titleSize))
                .foregroundStyle(palette.text)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("welcome.translation.title")

            OnboardingTranslationDemo(
                passage: .alice(readIn: localizationStore.bundleLanguage),
                palette: palette
            )
            .frame(maxWidth: .infinity, alignment: .center)

            Text("The translation arrives as a new book on your shelf. The original stays exactly as it was.")
                .font(Typography.meta())
                .foregroundStyle(palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: 560, alignment: .leading)
    }

    // MARK: - Chrome

    private var bottomBar: some View {
        Group {
            switch step {
            case .welcome:
                AppPrimaryButton(
                    title: "Next",
                    icon: .arrowRight,
                    action: { step = .translation },
                    palette: palette
                )
                .accessibilityIdentifier("welcome.continue")
                .opacity(revealedStage >= Self.stageCount ? 1 : 0)
            case .translation:
                AppPrimaryButton(
                    title: "To my shelf",
                    action: onFinished,
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
