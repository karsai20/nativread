import SwiftUI

/// App root: shows the library and overlays onboarding screens on first launch.
///
/// **Flow:**
/// 1. `LaunchView` — brand splash; waits for dictionaries.
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
    @Environment(DictionaryProvider.self) private var dictionaryProvider
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// True while the brand splash is visible.
    @State private var showLaunch: Bool
    /// True while the language picker is visible (shown after the splash).
    @State private var showLanguagePicker = false

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

            if showLaunch {
                LaunchView(onFinished: splashDidFinish)
                    .transition(.opacity)
                    .zIndex(1)
            }

            if showLanguagePicker {
                LanguageSelectionView(onConfirmed: languageDidConfirm)
                    .transition(.opacity)
                    .zIndex(2)
            }
        }
    }

    // MARK: - Step transitions

    /// Called by `LaunchView` once the splash's minimum display time and
    /// dictionary readiness conditions are both satisfied.
    private func splashDidFinish() {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.4)) {
            showLaunch = false
        }
        // Brief pause so the crossfade from splash → library completes before
        // the language picker appears on top.
        Task {
            if !reduceMotion {
                try? await Task.sleep(for: .milliseconds(350))
            }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.45)) {
                showLanguagePicker = true
            }
        }
    }

    /// Called by `LanguageSelectionView` when the user taps Continue.
    private func languageDidConfirm(_ language: AppLanguage) {
        localizationStore.setLanguage(language)
        // Default the Define (dictionary) language to match the chosen app
        // language so picking Magyar at onboarding loads the EN→HU dictionary
        // and shows Magyar selected in Settings. The user can still override
        // Define independently later.
        localizationStore.setDefineLanguage(language)
        // Re-prepare the dictionary provider using the effective dictionary
        // language — respects an independent Define language when already set.
        Task { await dictionaryProvider.reprepare(for: localizationStore.dictionaryLanguage) }
        settingsStore.markOnboardingSeen()
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.5)) {
            showLanguagePicker = false
        }
    }
}
