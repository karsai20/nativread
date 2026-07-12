import SwiftUI

/// App-wide settings sheet: appearance, language, translation backend, about.
/// Styled in the same editorial idiom as StatsView and VocabularyView —
/// BrandPalette surfaces, an in-content serif display header, eyebrow section
/// labels with hairline rules, page-like appearance tiles, and grouped cards
/// with hairline row separators. Launched from the library header gear button.
struct SettingsView: View {
    @Environment(LocalizationStore.self) private var localizationStore
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    private var palette: BrandPalette {
        BrandPalette.resolve(systemDark: colorScheme == .dark)
    }

    // Staged selections — nil means "unchanged from the store". Tapping a row
    // only stages locally (checkmark moves, app does not switch); the change is
    // committed on Done so the UI never re-localises out from under the user.
    @State private var pendingAppLanguage: AppLanguage?
    @State private var pendingDefineLanguage: AppLanguage?
    @State private var backendURL: String = ""

    private var selectedAppLanguage: AppLanguage {
        pendingAppLanguage ?? localizationStore.appLanguage
    }

    private var selectedDefineLanguage: AppLanguage {
        pendingDefineLanguage ?? localizationStore.defineLanguage
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    header
                    appearanceSection
                    appLanguageSection
                    defineLanguageSection
                    translationBackendSection
                    aboutSection
                }
                .padding(Spacing.lg)
            }
            .background(palette.background.ignoresSafeArea())
            // No nav title — the in-content serif header carries the heading,
            // so the sheet reads as designed chrome, not a system form.
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { applyAndDismiss() }
                        .tint(palette.accent)
                        .accessibilityIdentifier("settings.done")
                }
            }
        }
        .accessibilityIdentifier("settings.sheet")
    }

    // MARK: - Header

    /// In-content serif display title, echoing StatsView's editorial anchor.
    private var header: some View {
        Text("Settings")
            .font(Typography.display(34))
            .foregroundStyle(palette.text)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Commit

    /// Applies any staged language changes, then dismisses. Tapping rows only
    /// stages; nothing re-localises until Done so the screen never flips
    /// language mid-edit.
    private func applyAndDismiss() {
        if let pendingAppLanguage,
           pendingAppLanguage != localizationStore.appLanguage {
            localizationStore.setLanguage(pendingAppLanguage)
        }
        if let pendingDefineLanguage,
           pendingDefineLanguage != localizationStore.defineLanguage {
            localizationStore.setDefineLanguage(pendingDefineLanguage)
        }
        settingsStore.setTranslationBackendURL(backendURL)
        dismiss()
    }

    // MARK: - Appearance

    /// System / Light / Dark as page-like tiles. `System` follows the device —
    /// applied instantly on tap (unlike language) so the change is its own
    /// feedback.
    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            sectionLabel("Appearance")

            HStack(spacing: Spacing.sm) {
                ForEach(AppAppearance.allCases, id: \.rawValue) { appearance in
                    AppearanceTile(
                        appearance: appearance,
                        label: appearanceLabel(appearance),
                        isSelected: settingsStore.appAppearance == appearance,
                        palette: palette,
                        action: { settingsStore.setAppearance(appearance) }
                    )
                    .accessibilityIdentifier(
                        "settings.appearance.\(appearance.rawValue)"
                    )
                    .accessibilityLabel(appearanceLabel(appearance))
                    .accessibilityAddTraits(
                        settingsStore.appAppearance == appearance
                            ? [.isSelected] : []
                    )
                }
            }
        }
    }

    private func appearanceLabel(_ appearance: AppAppearance) -> String {
        switch appearance {
        case .system:
            return localizationStore.localizedString(
                "settings.appearance.system", value: "System")
        case .light:
            return localizationStore.localizedString(
                "settings.appearance.light", value: "Light")
        case .dark:
            return localizationStore.localizedString(
                "settings.appearance.dark", value: "Dark")
        }
    }

    // MARK: - App Language

    private var appLanguageSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            sectionLabel("App Language")

            VStack(spacing: 0) {
                ForEach(
                    Array(AppLanguage.pickable.enumerated()),
                    id: \.element.rawValue
                ) { index, language in
                    if index > 0 { SettingsRowDivider(palette: palette) }
                    SettingsGroupedRow(
                        title: language.endonym,
                        isSelected: selectedAppLanguage == language,
                        palette: palette
                    )
                    .onTapGesture { pendingAppLanguage = language }
                    .accessibilityIdentifier(
                        "settings.applang.\(language.rawValue)"
                    )
                    .accessibilityLabel(language.endonym)
                    .accessibilityAddTraits(
                        selectedAppLanguage == language
                            ? [.isSelected] : []
                    )
                }
            }
            .settingsGroupedCard(palette: palette)
        }
    }

    // MARK: - Define Language

    private var defineLanguageSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            sectionLabel("Define Language")

            VStack(spacing: 0) {
                ForEach(
                    Array(AppLanguage.definePickable.enumerated()),
                    id: \.element.rawValue
                ) { index, language in
                    if index > 0 { SettingsRowDivider(palette: palette) }
                    SettingsGroupedRow(
                        title: language.defineDisplayName,
                        subtitle: language.defineSourceName,
                        isSelected: selectedDefineLanguage == language,
                        palette: palette
                    )
                    .onTapGesture { pendingDefineLanguage = language }
                    .accessibilityIdentifier(
                        "settings.definelang.\(language.rawValue)"
                    )
                    .accessibilityLabel(language.defineDisplayName)
                    .accessibilityAddTraits(
                        selectedDefineLanguage == language
                            ? [.isSelected] : []
                    )
                }
            }
            .settingsGroupedCard(palette: palette)

            Text("English uses the built-in glossary. Magyar adds English → Hungarian lookup. Other dictionary packs stay hidden until installed. The Apple system dictionary is always available as a fallback.")
                .font(Typography.meta())
                .foregroundStyle(palette.secondaryText)
        }
    }

    // MARK: - Translation Backend

    /// Power-user setting — kept visually quiet: one grouped field card with a
    /// meta caption beneath, placed low so it does not compete with appearance
    /// and language.
    private var translationBackendSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            sectionLabel("Translation Backend")

            VStack(alignment: .leading, spacing: Spacing.xs) {
                TextField("http://translator.local:48218", text: $backendURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .font(Typography.control(16))
                    .foregroundStyle(palette.text)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.md)
                    .settingsGroupedCard(palette: palette)
                    .accessibilityIdentifier("settings.translationBackendURL")

                Text("The self-hosted translator server this app uploads books to.")
                    .font(Typography.meta())
                    .foregroundStyle(palette.secondaryText)
            }
        }
        .onAppear {
            if backendURL.isEmpty {
                backendURL = settingsStore.translationBackendURLString
            }
        }
    }

    // MARK: - About

    private var appVersion: String {
        let version = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "—"
        let build = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleVersion"
        ) as? String
        return build.map { "\(version) (\($0))" } ?? version
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            sectionLabel("About")

            VStack(spacing: 0) {
                HStack {
                    Text("Version")
                        .font(Typography.control(17))
                        .foregroundStyle(palette.text)
                    Spacer()
                    Text(appVersion)
                        .font(Typography.control(16))
                        .foregroundStyle(palette.secondaryText)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.md)

                SettingsRowDivider(palette: palette)

                NavigationLink {
                    LicensesView()
                } label: {
                    HStack {
                        Text("Licenses")
                            .font(Typography.control(17))
                            .foregroundStyle(palette.text)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(palette.secondaryText)
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.md)
                    .contentShape(Rectangle())
                }
                .accessibilityIdentifier("settings.licenses.link")
            }
            .settingsGroupedCard(palette: palette)
        }
    }

    // MARK: - Section label

    /// Uppercase eyebrow label with a trailing hairline rule — the same
    /// editorial device used throughout LibraryView and StatsView.
    private func sectionLabel(_ text: String) -> some View {
        HStack(spacing: Spacing.sm) {
            // LocalizedStringKey so a String argument still routes through the
            // catalog (Text(String) would render verbatim).
            Text(LocalizedStringKey(text))
                .font(Typography.eyebrow)
                .tracking(Typography.eyebrowTracking)
                .textCase(.uppercase)
                .foregroundStyle(palette.secondaryText)
            Rectangle()
                .fill(palette.hairline)
                .frame(height: Spacing.hairlineWidth)
        }
    }
}
