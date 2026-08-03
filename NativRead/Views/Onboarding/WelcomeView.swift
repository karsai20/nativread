import SwiftUI

/// The first-launch welcome: one screen, one promise, one action. The shelf
/// art, headline, value line, and button land in sequence so the screen feels
/// composed rather than dumped — and the three lessons the old walkthrough
/// carried now appear as tips on the screens they describe (`AppTips`).
///
/// The app language is not asked for here — it follows the phone, and
/// Settings can override it later.
struct WelcomeView: View {
    var onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// How many reveal stages are visible. Stages: 0 nothing, 1 scene,
    /// 2 headline, 3 value line, 4 button.
    @State private var revealedStage = 0

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
                    content
                        .padding(Spacing.lg)
                        .frame(maxWidth: 640, alignment: .leading)
                        .frame(maxWidth: .infinity)
                        // Minimum height, not exact: copy that outgrows the
                        // screen (accessibility text, landscape) scrolls
                        // instead of being clipped.
                        .frame(minHeight: proxy.size.height, alignment: .center)
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
        // One soft tap when the button lands — the moment the screen is ready.
        .sensoryFeedback(.impact(weight: .light), trigger: revealedStage) {
            _, new in new == Self.stageCount
        }
        .onAppear(perform: reveal)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            if showsScene {
                OnboardingShelfScene(palette: palette)
                    .frame(maxWidth: 420)
                    .accessibilityHidden(true)
                    .opacity(revealedStage >= 1 ? 1 : 0)
                    .offset(y: revealedStage >= 1 ? 0 : 24)
            }

            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Read in any language.")
                    .font(Typography.heading(titleSize))
                    .dynamicTypeSize(...DynamicTypeSize.accessibility3)
                    .tracking(Typography.headingTracking(titleSize))
                    .foregroundStyle(palette.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("welcome.title")
                    .opacity(revealedStage >= 2 ? 1 : 0)
                    .offset(y: revealedStage >= 2 ? 0 : 16)

                Text("Add a book you can't read — the first chapter is translated free.")
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

    private var bottomBar: some View {
        AppPrimaryButton(
            title: "To my shelf",
            systemImage: "arrow.right",
            action: onFinished,
            palette: palette
        )
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .accessibilityIdentifier("welcome.continue")
        .opacity(revealedStage >= Self.stageCount ? 1 : 0)
        .frame(maxWidth: 592)
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.sm)
        .background(palette.background)
    }

    /// `Typography.heading` is a fixed point size — it does not scale with
    /// Dynamic Type — so the headline is stepped up by hand at large sizes.
    private var titleSize: CGFloat {
        if dynamicTypeSize.isAccessibilitySize { return 44 }
        return dynamicTypeSize >= .xxLarge ? 40 : 38
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
