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
    /// Only fully-translated, dictionary-backed languages are listed. `.es`/`.de`
    /// stay in the enum (and in `bundled(for:)`) so the plumbing is ready, but
    /// they are withheld from the picker until their String Catalog reaches full
    /// coverage and their bilingual dictionaries are bundled — otherwise picking
    /// them would leave most of the app in the English fallback.
    static let pickable: [AppLanguage] = [.en, .hu]

    /// The two languages for which a bundled bilingual dictionary exists.
    /// English uses WordNet; Magyar adds the EN→HU Wiktionary dictionary.
    /// `.system` is included so the picker can offer "follow app language".
    static let definePickable: [AppLanguage] = [.en, .hu]

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

    /// The set of Define (dictionary) languages the reader has enabled. A
    /// lookup shows a gloss from every enabled language whose dictionary has
    /// the word, so a learner can study two languages at once. Seeded from the
    /// app language on first run; edited in Settings.
    private(set) var defineLanguages: Set<AppLanguage>

    // MARK: - Derived / ephemeral state

    /// The default Define set for an app language: just that language's own
    /// explicit dictionary choice. WordNet is still appended later by
    /// `BundledDictionary` as the global fallback. `.system` resolves to the
    /// closest device language.
    static func defaultDefineLanguages(
        for appLanguage: AppLanguage
    ) -> Set<AppLanguage> {
        let concrete = appLanguage == .system
            ? AppLanguage.matchingDevice() : appLanguage
        return [concrete]
    }

    /// Keeps Define languages aligned with app-language changes only while the
    /// user is still on the default set. Once they manually choose one or more
    /// Define languages, that explicit study set wins.
    static func defineLanguagesAfterAppLanguageChange(
        currentDefineLanguages: Set<AppLanguage>,
        oldAppLanguage: AppLanguage,
        newAppLanguage: AppLanguage,
        explicitDefineLanguages: Set<AppLanguage>?
    ) -> Set<AppLanguage> {
        if let explicitDefineLanguages { return explicitDefineLanguages }
        return currentDefineLanguages == defaultDefineLanguages(for: oldAppLanguage)
            ? defaultDefineLanguages(for: newAppLanguage)
            : currentDefineLanguages
    }

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
    private static let key = "quire.appLanguage.v1"
    /// Legacy single-value Define key (pre multi-language). Read once for
    /// migration, then superseded by `defineLanguagesKey`.
    private static let defineKey = "quire.defineLanguage.v1"
    private static let defineLanguagesKey = "quire.defineLanguages.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let resolvedAppLanguage: AppLanguage
        if let stored = defaults.string(forKey: Self.key),
           let language = AppLanguage(rawValue: stored) {
            resolvedAppLanguage = language
        } else {
            resolvedAppLanguage = .system
        }
        self.appLanguage = resolvedAppLanguage
        self.defineLanguages = Self.loadDefineLanguages(
            from: defaults, appLanguage: resolvedAppLanguage
        )
        // Route Bundle.main string lookups to the chosen language so every
        // `Text`/`String(localized:)` follows the choice from first launch.
        Bundle.setAppLanguage(appLanguage.languageCode)
    }

    /// Loads the enabled Define set: the stored multi-value set if present,
    /// else migrated from the legacy single Define key, else the default for
    /// the app language.
    private static func loadDefineLanguages(
        from defaults: UserDefaults, appLanguage: AppLanguage
    ) -> Set<AppLanguage> {
        if let raw = defaults.string(forKey: defineLanguagesKey) {
            if raw.isEmpty { return [] }
            let parsed = Set(
                raw.split(separator: ",").compactMap {
                    AppLanguage(rawValue: String($0))
                }
            )
            if !parsed.isEmpty { return parsed }
        }
        // Migrate a legacy single choice (`.system` meant "follow app").
        if let stored = defaults.string(forKey: defineKey),
           let legacy = AppLanguage(rawValue: stored) {
            return legacy == .system
                ? defaultDefineLanguages(for: appLanguage)
                : [legacy]
        }
        return defaultDefineLanguages(for: appLanguage)
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

    /// Applies the enabled Define `languages` and persists them. An empty set
    /// is allowed (lookups fall back to WordNet) but never left implicit.
    func setDefineLanguages(_ languages: Set<AppLanguage>) {
        defineLanguages = languages
        defaults.set(
            languages.map(\.rawValue).sorted().joined(separator: ","),
            forKey: Self.defineLanguagesKey
        )
    }

    /// Applies a Define set for the current session without persisting. Kept
    /// for legacy tests around the old bundled dictionary path.
    func overrideDefineLanguagesWithoutPersisting(_ languages: Set<AppLanguage>) {
        defineLanguages = languages
    }

    /// Aligns the current session's Define set with an app-language override,
    /// without persisting either value. Kept for legacy tests around the old
    /// bundled dictionary defaults.
    func overrideDefineLanguagesForAppLanguageWithoutPersisting(
        _ language: AppLanguage
    ) {
        defineLanguages = Self.defaultDefineLanguages(for: language)
    }

    /// Toggles one Define language on or off and persists the result.
    func toggleDefineLanguage(_ language: AppLanguage) {
        var next = defineLanguages
        if next.contains(language) { next.remove(language) }
        else { next.insert(language) }
        setDefineLanguages(next)
    }

    /// Removes the persisted language choices; the next launch will default
    /// to `.system`. Used by the `-resetLanguage` UI-test hook.
    static func resetPersisted(in defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key)
        defaults.removeObject(forKey: defineKey)
        defaults.removeObject(forKey: defineLanguagesKey)
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
    /// of the current `appLanguage`. Used by the onboarding picker so the
    /// heading and Continue button preview the highlighted language live —
    /// tapping "Magyar" flips "Continue" to "Folytatás" before confirming.
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
