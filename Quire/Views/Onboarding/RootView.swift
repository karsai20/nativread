import SwiftUI

/// App root: shows the library, overlaying the first-launch brand splash on
/// top of it and crossfading the splash away once the splash finishes. On
/// subsequent launches the splash is skipped entirely (the library shows
/// immediately).
struct RootView: View {
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showLaunch: Bool

    /// `initialShowLaunch` is resolved at launch from the onboarding flag and
    /// the `-forceOnboarding` / `-skipOnboarding` test arguments.
    init(initialShowLaunch: Bool) {
        _showLaunch = State(initialValue: initialShowLaunch)
    }

    var body: some View {
        ZStack {
            LibraryView()

            if showLaunch {
                LaunchView(onFinished: finish)
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
    }

    private func finish() {
        settingsStore.markOnboardingSeen()
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.5)) {
            showLaunch = false
        }
    }
}
