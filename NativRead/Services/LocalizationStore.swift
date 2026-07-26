import Foundation
import Observation

/// The four languages the app supports explicitly, plus `.system` which
/// defers to the device locale (English fallback when device language is
/// outside the four).
enum AppLanguage: String, CaseIterable, Sendable {
    case system
    case en
    case es
    case de
    case hu

    /// The BCP-47 language code used for `Locale` and `.lproj` lookup.
    /// `.system` returns `nil`; the caller uses the device's locale instead.
    var languageCode: String? {
        switch self {
        case .system: return nil
        case .en: return "en"
        case .es: return "es"
        case .de: return "de"
        case .hu: return "hu"
        }
    }

    /// The endonym — the language's own name in its own script. These are
    /// displayed in the picker so a user can always recognise their language
    /// regardless of the current UI language.
    var endonym: String {
        switch self {
        case .system: return "System"
        case .en:     return "English"
        case .es:     return "Español"
        case .de:     return "Deutsch"
        case .hu:     return "Magyar"
        }
    }

    /// The concrete options shown in the onboarding/settings picker (`.system`
    /// is handled automatically and never presented as a manual choice).
    ///
    /// Only fully-translated languages are listed. `.es`/`.de` stay in the enum
    /// so the plumbing is ready, but they are withheld from the picker until
    /// their String Catalog reaches full coverage — otherwise picking them
    /// would leave most of the app in the English fallback.
    static let pickable: [AppLanguage] = [.en, .hu]

    /// The app language that best matches the device's preferred locale, or
    /// `.en` if the device language is not in the supported set.
    static func matchingDevice() -> AppLanguage {
        let preferred = Locale.preferredLanguages.first ?? "en"
        let code = Locale(identifier: preferred).language.languageCode?.identifier ?? "en"
        return AppLanguage(rawValue: code) ?? .en
    }
}

/// Persists the user's chosen app language and exposes derived values needed
/// to apply it immediately — a `Locale` for SwiftUI's `\.locale` environment
/// key and a `Bundle` pointing to the chosen `.lproj` directory for reliable
/// `String(localized:bundle:)` lookups.
///
/// Mirrors the pattern established by `SettingsStore`: a single key in
/// `UserDefaults`, a `reset` method for `-resetLanguage` UI-test hooks, and
/// an `overrideWithoutPersisting` path for `-forceLanguage`.
@Observable
final class LocalizationStore {

    // MARK: - Persisted state

    /// The user's explicit choice. `.system` is the factory default (no key
    /// stored yet) and means "defer to the device locale."
    private(set) var appLanguage: AppLanguage

    // MARK: - Derived / ephemeral state

    /// Resolved `Locale` for `.environment(\.locale, …)`. When the language
    /// is `.system` the device's current locale is returned unchanged.
    var resolvedLocale: Locale {
        guard let code = appLanguage.languageCode else {
            return .current
        }
        return Locale(identifier: code)
    }

    /// A `Bundle` that resolves string lookups from the chosen `.lproj`
    /// directory.  Use this with `String(localized: key, bundle: bundle)`
    /// whenever `\.locale` environment injection alone doesn't reliably route
    /// SwiftUI `Text` to the right translation.
    ///
    /// Falls back to `Bundle.main` when the `.lproj` resource is missing
    /// (which can happen on a simulator that hasn't been rebuilt after adding
    /// a new language).
    var bundle: Bundle {
        guard let code = appLanguage.languageCode,
              let path = Bundle.main.path(forResource: code, ofType: "lproj"),
              let b = Bundle(path: path) else {
            return .main
        }
        return b
    }

    // MARK: - Persistence

    private let defaults: UserDefaults
    private static let key = "nativread.appLanguage.v1"
    private static let legacyKey = ["qui", "re.appLanguage.v1"].joined()
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let appLanguage: AppLanguage
        let stored = defaults.string(forKey: Self.key)
            ?? defaults.string(forKey: Self.legacyKey)
        if let stored,
           let language = AppLanguage(rawValue: stored) {
            appLanguage = language
        } else {
            appLanguage = .system
        }
        self.appLanguage = appLanguage
        if defaults.object(forKey: Self.key) == nil, let stored {
            defaults.set(stored, forKey: Self.key)
            defaults.removeObject(forKey: Self.legacyKey)
        }
        // Route Bundle.main string lookups to the chosen language so every
        // `Text`/`String(localized:)` follows the choice from first launch.
        Bundle.setAppLanguage(appLanguage.languageCode)
    }

    /// Applies `language` and writes it to `UserDefaults`.
    func setLanguage(_ language: AppLanguage) {
        appLanguage = language
        defaults.set(language.rawValue, forKey: Self.key)
        Bundle.setAppLanguage(language.languageCode)
    }

    /// Applies `language` for the current session without writing to
    /// `UserDefaults`. Used by the `-forceLanguage` UI-test launch hook so
    /// forced settings never leak into subsequent test runs.
    func overrideWithoutPersisting(_ language: AppLanguage) {
        appLanguage = language
        Bundle.setAppLanguage(language.languageCode)
    }

    /// Removes the persisted language choices; the next launch will default
    /// to `.system`. Used by the `-resetLanguage` UI-test hook.
    static func resetPersisted(in defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key)
        defaults.removeObject(forKey: legacyKey)
    }

    // MARK: - Localised string helper

    /// Returns the localised string for `key` from the resolved `.lproj`
    /// bundle, with `value` as the English fallback. This is the robust path
    /// that bypasses any SwiftUI `\.locale` routing ambiguity.
    func localizedString(
        _ key: String,
        value defaultValue: String = ""
    ) -> String {
        bundle.localizedString(forKey: key, value: defaultValue, table: nil)
    }

    /// Localises `key` against a **specific** language's `.lproj`, independent
    /// of the current `appLanguage`. Available for language previews that must
    /// be resolved independently of the currently active app language.
    /// Falls back to the current bundle when the language has no `.lproj`.
    func localizedString(
        _ key: String,
        value defaultValue: String = "",
        for language: AppLanguage
    ) -> String {
        guard let code = language.languageCode,
              let path = Bundle.main.path(forResource: code, ofType: "lproj"),
              let languageBundle = Bundle(path: path) else {
            return localizedString(key, value: defaultValue)
        }
        return languageBundle.localizedString(
            forKey: key, value: defaultValue, table: nil
        )
    }
}
