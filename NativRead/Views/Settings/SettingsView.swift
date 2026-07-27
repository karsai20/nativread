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

    @State private var backendURL: String = ""
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
#if DEBUG
                    translationBackendSection
#endif
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
            sectionLabel("Account")

            VStack(spacing: 0) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .foregroundStyle(palette.accent)
                    Text("Signed in with Apple")
                        .font(Typography.control(17))
                        .foregroundStyle(palette.text)
                    Spacer()
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.md)

                SettingsRowDivider(palette: palette)

                Button {
                    showsDeleteAccountConfirmation = true
                } label: {
                    HStack(spacing: Spacing.sm) {
                        if translationAuthStore.isDeletingAccount {
                            ProgressView()
                        } else {
                            Image(systemName: "trash")
                        }
                        if translationAuthStore.isDeletingAccount {
                            Text("Deleting account...")
                        } else {
                            Text("Delete Account")
                        }
                        Spacer()
                    }
                    .font(Typography.control(17, weight: .semibold))
                    .foregroundStyle(palette.danger)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.md)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(translationAuthStore.isDeletingAccount)
                .accessibilityIdentifier("settings.account.delete")
            }
            .settingsGroupedCard(palette: palette)

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
                    // Applied immediately: Settings is a tab now, so there is no
                    // "close" moment to commit at, and the tab shell re-localises
                    // its content without losing the selected tab.
                    .onTapGesture { localizationStore.setLanguage(language) }
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

    // MARK: - Translation Backend

    /// Debug-only endpoint override. Production builds always use the bundled,
    /// trusted HTTPS service and never ask readers to configure infrastructure.
#if DEBUG
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
#endif

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
                    PrivacyPolicyView()
                } label: {
                    HStack {
                        Text("Privacy Policy")
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
                .accessibilityIdentifier("settings.privacy.link")

                SettingsRowDivider(palette: palette)

                NavigationLink {
                    TermsOfUseView()
                } label: {
                    HStack {
                        Text("Terms of Use")
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
                .accessibilityIdentifier("settings.terms.link")

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
    /// editorial device used throughout LibraryView.
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
