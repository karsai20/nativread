import SwiftUI
import StoreKit

/// App root: shows the library and overlays onboarding screens on first launch.
///
/// **Flow:**
/// 1. `LaunchView` — brand splash.
/// 2. `LanguageSelectionView` — language picker (first launch only).
/// 3. `LibraryView` — crossfades in once both onboarding steps are confirmed.
///
/// Subsequent launches (after `hasSeenOnboarding`) skip both overlays and
/// go straight to the library. The individual steps are controlled via the
/// `-forceOnboarding` / `-skipOnboarding` launch flags resolved in
/// `NativReadApp.shouldShowLaunch(_:)`.
struct RootView: View {
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(LocalizationStore.self) private var localizationStore
    @Environment(LibraryStore.self) private var library
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.requestReview) private var requestReview

    /// True while the brand splash is visible.
    @State private var showLaunch: Bool
    /// True while the language picker is visible (shown after the splash).
    @State private var showLanguagePicker = false
    /// False while the picker is covered by the launch screen or being removed,
    /// so stale controls do not remain tappable or visible to UI tests /
    /// VoiceOver outside the actual picker step.
    @State private var languagePickerInteractive = false

    /// `initialShowLaunch` is resolved at launch from the onboarding flag and
    /// the `-forceOnboarding` / `-skipOnboarding` test arguments.
    init(initialShowLaunch: Bool) {
        _showLaunch = State(initialValue: initialShowLaunch)
    }

    var body: some View {
        ZStack {
            // Bump identity on language change so every Text in the library and
            // its sheets re-resolves against the newly-selected .lproj (the
            // BundleLanguage re-class alone won't refresh already-built views;
            // `\.locale` only drives number/date formatting). Scoped to the
            // library — NOT the whole RootView — so an in-app switch refreshes
            // live without tearing down the onboarding flow.
            LibraryView()
                .id(localizationStore.appLanguage)

            if showLanguagePicker {
                LanguageSelectionView(onConfirmed: languageDidConfirm)
                    .transition(.opacity)
                    .allowsHitTesting(languagePickerInteractive)
                    .accessibilityHidden(!languagePickerInteractive)
                    .zIndex(1)
            }

            if showLaunch {
                LaunchView(onFinished: splashDidFinish)
                    .transition(.opacity)
                    .zIndex(2)
            }
        }
        .onChange(of: library.reviewPromptRequested) { _, requested in
            guard requested else { return }
            library.reviewPromptRequested = false
            // Belt-and-braces: the policy only fires on finished books, but
            // the spec says never during onboarding, so guard it anyway.
            if !showLaunch, !showLanguagePicker {
                requestReview()
            }
        }
    }

    // MARK: - Step transitions

    /// Called by `LaunchView` once the splash's minimum display time elapsed.
    private func splashDidFinish() {
        // Mount the language picker *underneath* the splash first (no
        // animation — it's fully covered), then fade the splash out so it
        // reveals the picker directly. The library must never peek through
        // the gap, which read as a home-screen flash before onboarding.
        languagePickerInteractive = false
        showLanguagePicker = true
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.45)) {
            showLaunch = false
        }
        Task { @MainActor in
            if !reduceMotion {
                try? await Task.sleep(for: .milliseconds(460))
            }
            if showLanguagePicker {
                languagePickerInteractive = true
            }
        }
    }

    /// Called by `LanguageSelectionView` when the user taps Continue.
    private func languageDidConfirm(_ language: AppLanguage) {
        localizationStore.setLanguage(language)
        settingsStore.markOnboardingSeen()
        languagePickerInteractive = false
        showLanguagePicker = false
    }
}
