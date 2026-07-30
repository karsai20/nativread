import AuthenticationServices
import SwiftUI

/// App-wide settings sheet: appearance, language, translation backend, about.
/// Styled in the same editorial idiom as the library —
/// BrandPalette surfaces, an in-content serif display header, eyebrow section
/// labels with hairline rules, page-like appearance tiles, and grouped cards
/// with hairline row separators. Launched from the library header gear button.
struct SettingsView: View {
    @Environment(LocalizationStore.self) private var localizationStore
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(TranslationAuthStore.self) private var translationAuthStore
    @Environment(TranslationStore.self) private var translationStore
    @Environment(\.colorScheme) private var colorScheme

    private var palette: BrandPalette {
        BrandPalette.resolve(systemDark: colorScheme == .dark)
    }

    @State private var showsDeleteAccountConfirmation = false
    @State private var showsAccountDeletedConfirmation = false
    @State private var showsAccountDeletionAuthorization = false
    @State private var showsAIConsentResetConfirmation = false
    @State private var showsAIConsentResetResult = false
    @State private var accountActionError: String?

    private var selectedAppLanguage: AppLanguage {
        localizationStore.appLanguage
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    header
                    identityCard
                    appearanceSection
                    appLanguageSection
                    privacyControlsSection
                    if translationAuthStore.isSignedIn {
                        accountSection
                    }
                    aboutSection
                }
                .padding(Spacing.lg)
            }
            .background(palette.background.ignoresSafeArea())
            // No nav bar — the in-content serif header carries the heading and
            // the close button, so the sheet has no empty chrome strip on top.
            // Pushed views (Licenses) still get their own bar with a back button.
            .toolbar(.hidden, for: .navigationBar)
        }
        .accessibilityIdentifier("settings.sheet")
        .alert(
            "Forget AI permissions?",
            isPresented: $showsAIConsentResetConfirmation
        ) {
            Button("Forget Permissions", role: .destructive) {
                translationStore.clearAIProcessingConsents()
                showsAIConsentResetResult = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("NativRead will ask again before any future book text is sent to the AI translation provider. Work already requested cannot be undone.")
        }
        .alert(
            "AI permissions forgotten",
            isPresented: $showsAIConsentResetResult
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("No saved AI-processing permission remains on this device.")
        }
        .alert(
            "Delete account?",
            isPresented: $showsDeleteAccountConfirmation
        ) {
            Button("Delete Account", role: .destructive) {
                showsAccountDeletionAuthorization = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes your translation account, access records, and server data. Books already saved on this device stay in your library.")
        }
        .alert(
            "Account deleted",
            isPresented: $showsAccountDeletedConfirmation
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your translation account and its server data were deleted. Your local books were not changed.")
        }
        .sheet(isPresented: $showsAccountDeletionAuthorization) {
            AccountDeletionAuthorizationView(
                isWorking: translationAuthStore.isDeletingAccount,
                errorMessage: accountActionError
                    ?? translationAuthStore.accountDeletionErrorMessage
            ) { result in
                deleteAccount(result)
            }
        }
    }

    // MARK: - Privacy controls

    private var privacyControlsSection: some View {
        AppSettingsSection("Privacy Controls", palette: palette) {
            AppSettingsRow(
                systemImage: "hand.raised.slash",
                title: "Forget AI Permissions",
                value: String(localized: "Ask again next time"),
                hidesSeparator: true,
                action: { showsAIConsentResetConfirmation = true },
                palette: palette
            )
            .accessibilityIdentifier("settings.privacy.forgetAIConsent")
        }
    }

    // MARK: - Identity

    /// A short "what this app is holding for you" card, so Settings opens with
    /// reassurance rather than a wall of switches.
    private var identityCard: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(palette.accent)
                .clipShape(
                    RoundedRectangle(cornerRadius: Spacing.radiusCard, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text("NativRead")
                    .font(Typography.eyebrow)
                    .tracking(Typography.eyebrowTracking)
                    .textCase(.uppercase)
                    .foregroundStyle(palette.secondaryText)
                Text("Your library stays close.")
                    .font(Typography.control(18, weight: .bold))
                    .foregroundStyle(palette.text)
                Text("Stored on this device")
                    .font(Typography.control(14))
                    .foregroundStyle(palette.secondaryText)
            }
            Spacer(minLength: 0)
        }
        .padding(Spacing.md)
        .background(palette.surface)
        .clipShape(
            RoundedRectangle(cornerRadius: Spacing.radiusGroup, style: .continuous)
        )
    }

    // MARK: - Account

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            AppSettingsSection("Account", palette: palette) {
                AppSettingsRow(
                    systemImage: "person.crop.circle.badge.checkmark",
                    title: "Signed in with Apple",
                    palette: palette
                )

                AppSettingsRow(
                    systemImage: "trash",
                    title: translationAuthStore.isDeletingAccount
                        ? "Deleting account..."
                        : "Delete Account",
                    isDestructive: true,
                    hidesSeparator: true,
                    action: { showsDeleteAccountConfirmation = true },
                    palette: palette
                ) {
                    if translationAuthStore.isDeletingAccount {
                        ProgressView()
                    }
                }
                .disabled(translationAuthStore.isDeletingAccount)
                .accessibilityIdentifier("settings.account.delete")
            }

            if let displayedError = accountActionError
                    ?? translationAuthStore.accountDeletionErrorMessage {
                Label(
                    displayedError,
                    systemImage: "exclamationmark.triangle"
                )
                .font(Typography.meta())
                .foregroundStyle(Color.red)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func deleteAccount(
        _ result: Result<ASAuthorization, Error>
    ) {
        accountActionError = nil
        guard let backendURL = settingsStore.translationBackendURL else {
            accountActionError =
                localizationStore.localizedString(
                    "settings.account.serviceUnavailable",
                    value: "The translation service is unavailable. Check your connection and try again."
                )
            return
        }

        Task {
            let deleted = await translationAuthStore.deleteAccount(
                result,
                backendURL: backendURL
            )
            guard deleted else { return }
            translationStore.clearAccountData()
            showsAccountDeletionAuthorization = false
            showsAccountDeletedConfirmation = true
        }
    }

    // MARK: - Header

    /// In-content serif display title, echoing the library's editorial anchor,
    /// with the close button on the same row. Closing still commits staged
    /// language changes — X means "close", not "discard".
    private var header: some View {
        AppLargeTitleHeader(
            title: "Settings",
            subtitle: String(localized: "A reading space tuned to you"),
            palette: palette
        )
    }

    // MARK: - Appearance

    /// System / Light / Dark as page-like tiles. `System` follows the device —
    /// applied instantly on tap (unlike language) so the change is its own
    /// feedback.
    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Appearance")
                .font(Typography.control(13, weight: .semibold))
                .tracking(0.35)
                .textCase(.uppercase)
                .foregroundStyle(palette.secondaryText)
                .padding(.leading, Spacing.md)

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
        AppSettingsSection("App Language", palette: palette) {
            ForEach(
                Array(AppLanguage.pickable.enumerated()),
                id: \.element.rawValue
            ) { index, language in
                let isSelected = selectedAppLanguage == language
                AppSettingsRow(
                    systemImage: nil,
                    title: LocalizedStringKey(language.endonym),
                    hidesSeparator: index == AppLanguage.pickable.count - 1,
                    // Applied immediately: Settings is a tab now, so there is
                    // no "close" moment to commit at, and the shell
                    // re-localises without losing the selected tab.
                    action: { localizationStore.setLanguage(language) },
                    palette: palette
                ) {
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(palette.accent)
                    }
                }
                .accessibilityIdentifier(
                    "settings.applang.\(language.rawValue)"
                )
                .accessibilityLabel(language.endonym)
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
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
        AppSettingsSection("About", palette: palette) {
            AppSettingsRow(
                systemImage: "info.circle",
                title: "Version",
                value: appVersion,
                palette: palette
            )

            AppSettingsLink(
                systemImage: "hand.raised",
                title: "Privacy Policy",
                palette: palette
            ) {
                PrivacyPolicyView()
            }
            .accessibilityIdentifier("settings.privacy.link")

            AppSettingsLink(
                systemImage: "doc.text",
                title: "Terms of Use",
                palette: palette
            ) {
                TermsOfUseView()
            }
            .accessibilityIdentifier("settings.terms.link")

            AppSettingsLink(
                systemImage: "chevron.left.forwardslash.chevron.right",
                title: "Licenses",
                hidesSeparator: true,
                palette: palette
            ) {
                LicensesView()
            }
            .accessibilityIdentifier("settings.licenses.link")
        }
    }

}
