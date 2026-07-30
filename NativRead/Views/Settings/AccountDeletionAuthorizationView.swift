import AuthenticationServices
import SwiftUI

/// Final identity check before permanent account deletion. A fresh Apple
/// authorization code lets the backend revoke Sign in with Apple as required;
/// the existing NativRead session alone cannot do that.
struct AccountDeletionAuthorizationView: View {
    let isWorking: Bool
    let errorMessage: String?
    let onCompletion: (Result<ASAuthorization, Error>) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismiss

    private var palette: BrandPalette {
        BrandPalette.resolve(systemDark: colorScheme == .dark)
    }

    private var copy: AccountDeletionCopy {
        locale.language.languageCode?.identifier == "hu"
            ? .hungarian : .english
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Image(systemName: "person.crop.circle.badge.xmark")
                    .font(.system(size: 25, weight: .semibold))
                    .foregroundStyle(Color.red)
                    .frame(width: 56, height: 56)
                    .background(Color.red.opacity(0.10), in: Circle())

                Text(copy.title)
                    .font(Typography.display(31))
                    .foregroundStyle(palette.text)

                Text(copy.explanation)
                    .font(Typography.body(17))
                    .foregroundStyle(palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                SignInWithAppleButton(.continue) { request in
                    request.requestedScopes = []
                } onCompletion: { result in
                    onCompletion(result)
                }
                .signInWithAppleButtonStyle(
                    colorScheme == .dark ? .white : .black
                )
                .frame(height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .disabled(isWorking)
                .accessibilityIdentifier("settings.account.confirmWithApple")

                if isWorking {
                    HStack(spacing: Spacing.sm) {
                        ProgressView()
                        Text(copy.deleting)
                    }
                    .font(Typography.meta())
                    .foregroundStyle(palette.secondaryText)
                } else if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .font(Typography.meta())
                        .foregroundStyle(Color.red)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Button(copy.cancel) { dismiss() }
                    .font(Typography.control(16, weight: .semibold))
                    .foregroundStyle(palette.secondaryText)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: Spacing.minTapTarget)
                    .disabled(isWorking)
            }
            .padding(Spacing.lg)
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
            .background(palette.background.ignoresSafeArea())
            .navigationTitle(copy.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
        .interactiveDismissDisabled(isWorking)
        .accessibilityIdentifier("settings.account.authorization")
    }
}

private struct AccountDeletionCopy {
    let navigationTitle: String
    let title: String
    let explanation: String
    let deleting: String
    let cancel: String

    static let english = AccountDeletionCopy(
        navigationTitle: "Delete account",
        title: "Confirm with Apple",
        explanation: "For your security, confirm the same Apple account once more. NativRead will then revoke Sign in with Apple and permanently delete the translation account and its server data. Books on this device stay in your library.",
        deleting: "Deleting your account securely...",
        cancel: "Cancel"
    )

    static let hungarian = AccountDeletionCopy(
        navigationTitle: "Fiók törlése",
        title: "Megerősítés Apple-lel",
        explanation: "A biztonságod érdekében erősítsd meg még egyszer ugyanazt az Apple-fiókot. A NativRead ezután visszavonja az Apple-lel történő bejelentkezést, és végleg törli a fordítási fiókot és a szerveradatait. Az eszközön lévő könyvek megmaradnak.",
        deleting: "A fiók biztonságos törlése...",
        cancel: "Mégse"
    )
}
