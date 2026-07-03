import SwiftUI

/// First-launch editorial brand splash. Gives a calm first-use feel, then
/// crossfades into the language picker. Uses the editorial `BrandPalette` so
/// the splash, the language picker, and the library all read as one warm paper
/// surface.
struct LaunchView: View {
    /// Called once readiness and the minimum display time are both satisfied.
    var onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Brand copy

    private let tagline = "A quiet place to read"

    /// The chrome palette resolved against the system appearance.
    private var palette: BrandPalette {
        BrandPalette.resolve(systemDark: colorScheme == .dark)
    }

    /// Never flash: keep the splash up for at least this long even if the
    /// dictionaries are already prepared. Long enough for the wordmark and
    /// tagline reveal (~1.05s) to fully settle and breathe before crossfade.
    private let minimumDisplay: Duration = .milliseconds(1_900)
    @State private var wordmarkShown = false
    @State private var taglineShown = false

    var body: some View {
        ZStack {
            // A barely-there vertical lift from the page toward its raised
            // surface — paper depth, not a coloured wash.
            LinearGradient(
                colors: [palette.background, palette.surface],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 14) {
                Text("NativRead")
                    .font(Typography.display(64))
                    .tracking(1)
                    .foregroundStyle(palette.text)
                    .opacity(wordmarkShown ? 1 : 0)
                    .offset(y: wordmarkShown ? 0 : 8)
                    .accessibilityLabel("NativRead")
                    .accessibilityIdentifier("onboarding.wordmark")

                // Editorial accent: a short russet rule under the wordmark.
                Capsule()
                    .fill(palette.accent)
                    .frame(width: 44, height: 2)
                    .opacity(wordmarkShown ? 1 : 0)

                Text(tagline)
                    .font(Typography.display(22))
                    .italic()
                    .tracking(0.5)
                    .foregroundStyle(palette.secondaryText)
                    .opacity(taglineShown ? 1 : 0)
                    .padding(.top, 2)
            }

            VStack {
                Spacer()
                SweepIndicator(
                    track: palette.hairline,
                    sweep: palette.accent,
                    isAnimated: !reduceMotion
                )
                .frame(width: 132, height: 2)
                .padding(.bottom, 64)
            }
        }
        // Note: no identifier/combine on the root container — that would turn
        // the whole splash into a single accessibility element and hide the
        // wordmark leaf, which UI tests query by `onboarding.wordmark`.
        .onAppear { reveal() }
        .task { await driveDismissal() }
    }

    // MARK: - Reveal animation

    private func reveal() {
        guard !reduceMotion else {
            wordmarkShown = true
            taglineShown = true
            return
        }
        withAnimation(.easeOut(duration: 0.7)) {
            wordmarkShown = true
        }
        withAnimation(.easeOut(duration: 0.7).delay(0.35)) {
            taglineShown = true
        }
    }

    // MARK: - Dismissal

    /// Finishes when the minimum display time has elapsed.
    private func driveDismissal() async {
        // UI-test hook: hold the splash on screen (never auto-dismiss) so a
        // test can deterministically assert it appeared, without racing the
        // crossfade.
        if ProcessInfo.processInfo.arguments.contains("-onboardingHold") { return }

        try? await Task.sleep(for: minimumDisplay)
        if Task.isCancelled { return }
        onFinished()
    }
}

/// A thin indeterminate progress indicator: a small brass capsule that sweeps
/// left↔right within a faint hairline track. Collapses to a static centred
/// segment when Reduce Motion is on.
private struct SweepIndicator: View {
    let track: Color
    let sweep: Color
    let isAnimated: Bool

    @State private var phase: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let segment = width * 0.32
            let travel = width - segment

            Capsule()
                .fill(track)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(sweep)
                        .frame(width: segment, height: height)
                        .offset(x: isAnimated ? phase * travel : (travel / 2))
                }
                .onAppear {
                    guard isAnimated else { return }
                    withAnimation(
                        .easeInOut(duration: 1.1)
                            .repeatForever(autoreverses: true)
                    ) {
                        phase = 1
                    }
                }
        }
    }
}
