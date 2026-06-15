import SwiftUI

/// First-launch dark-academia brand splash. Covers the one-time dictionary
/// unpacking work and gives a "flawless first-use" feel, then crossfades into
/// the library. The palette is a fixed brand moment — it deliberately ignores
/// the user's current reader theme.
struct LaunchView: View {
    /// Called once readiness and the minimum display time are both satisfied.
    var onFinished: () -> Void

    @Environment(DictionaryProvider.self) private var dictionaryProvider
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Brand constants (easily editable)

    private let tagline = "A quiet place to read"

    private static let pine = Color(hex: "#152319")
    private static let pineDeep = Color(hex: "#0E1812")
    private static let brass = Color(hex: "#CFA94E")
    private static let parchment = Color(hex: "#ECE3CE")

    /// Never flash: keep the splash up for at least this long even if the
    /// dictionaries are already prepared. Long enough for the wordmark and
    /// tagline reveal (~1.05s) to fully settle and breathe before crossfade.
    private let minimumDisplay: Duration = .milliseconds(1_900)
    /// Hard ceiling so a dictionary failure can never trap the user here.
    private let maximumDisplay: Duration = .seconds(8)
    private let pollInterval: Duration = .milliseconds(100)

    @State private var wordmarkShown = false
    @State private var taglineShown = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Self.pine, Self.pineDeep],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                Text("QUIRE")
                    .font(.custom("Cinzel", size: 46))
                    .fontWeight(.semibold)
                    .tracking(8)
                    .foregroundStyle(Self.brass)
                    .opacity(wordmarkShown ? 1 : 0)
                    .offset(y: wordmarkShown ? 0 : 8)
                    .accessibilityLabel("Quire")
                    .accessibilityIdentifier("onboarding.wordmark")

                Text(tagline)
                    .font(.custom("Cormorant Garamond", size: 20))
                    .italic()
                    .tracking(1.5)
                    .foregroundStyle(Self.parchment.opacity(0.85))
                    .opacity(taglineShown ? 0.85 : 0)
            }

            VStack {
                Spacer()
                SweepIndicator(
                    track: Self.parchment.opacity(0.14),
                    sweep: Self.brass,
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

    /// Finishes when the dictionaries are ready AND the minimum display time
    /// has elapsed, with a hard timeout so failures can't strand the user.
    private func driveDismissal() async {
        // UI-test hook: hold the splash on screen (never auto-dismiss) so a
        // test can deterministically assert it appeared, without racing the
        // crossfade. The splash otherwise vanishes once dictionaries are ready.
        if ProcessInfo.processInfo.arguments.contains("-onboardingHold") { return }

        let start = ContinuousClock.now

        while !dictionaryProvider.isReady {
            if ContinuousClock.now - start >= maximumDisplay { break }
            try? await Task.sleep(for: pollInterval)
            if Task.isCancelled { return }
        }

        let elapsed = ContinuousClock.now - start
        if elapsed < minimumDisplay {
            try? await Task.sleep(for: minimumDisplay - elapsed)
        }
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
