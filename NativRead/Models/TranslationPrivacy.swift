import Foundation

/// Versioned privacy configuration for the optional translation service.
///
/// Keep the bundled provider name aligned with the production backend and the
/// published Privacy Policy. Changing the provider or the disclosed processing
/// requires a new consent version so existing readers are asked again.
enum TranslationPrivacy {
    static let policyVersion = "2026-08-05"
    static let currentAIConsentVersion = "2026-07-20-gemini"

    private static let providerNameKey = "NativReadAIProviderName"
    private static let publicPolicyURLKey = "NativReadPrivacyPolicyURL"

    static var aiProviderName: String {
        let configured = Bundle.main.object(
            forInfoDictionaryKey: providerNameKey
        ) as? String
        let trimmed = (configured ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Google Gemini API" : trimmed
    }

    /// The live web policy used by App Store Connect once the legal site has
    /// been deployed. The complete policy remains readable inside the app even
    /// while this build setting is empty during development.
    static var publicPolicyURL: URL? {
        let configured = Bundle.main.object(
            forInfoDictionaryKey: publicPolicyURLKey
        ) as? String
        let trimmed = (configured ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let url = URL(string: trimmed),
              url.scheme?.lowercased() == "https",
              url.host != nil
        else { return nil }
        return url
    }
}
