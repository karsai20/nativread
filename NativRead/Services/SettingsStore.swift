import Foundation
import Observation

/// App-wide appearance preference for the library and chrome. `.system`
/// follows the device's Light/Dark setting; the others force one mode.
enum AppAppearance: String, CaseIterable, Sendable {
    case system, light, dark
}

/// Persists reader typography settings. Mutations always go through
/// `update(_:)` which writes a fresh value (no in-place mutation leaks).
@Observable
final class SettingsStore {
    private(set) var settings: ReaderSettings

    /// Whole-app Light/Dark/System preference (chrome, library, onboarding).
    private(set) var appAppearance: AppAppearance
    /// True when the reader pinned the interface to portrait so the page
    /// never rotates with the phone.
    private(set) var isOrientationLocked: Bool
    private(set) var translationBackendURLString: String
    private(set) var translationUserID: String

    private let defaults: UserDefaults
    private static let key = "lumenread.readerSettings.v2"
    private static let onboardingSeenKey = "nativread.onboarding.v1.seen"
    private static let legacyOnboardingSeenKey = [
        "qui", "re.onboarding.v1.seen",
    ].joined()
    private static let appearanceKey = "nativread.appAppearance.v1"
    private static let translationBackendURLKey = "nativread.translationBackendURL.v1"
    private static let translationUserIDKey = "nativread.translationUserID.v1"
    private static let defaultTranslationBackendURLKey = "NativReadDefaultTranslationBackendURL"
    private static let orientationLockKey = "nativread.orientationLock.v1"
    private static var bundledTranslationBackendURLString: String {
        let value = Bundle.main.object(
            forInfoDictionaryKey: defaultTranslationBackendURLKey
        ) as? String
        return (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    init(
        defaults: UserDefaults = .standard,
        defaultTranslationBackendURLString: String? = nil
    ) {
        self.defaults = defaults
        if defaults.object(forKey: Self.onboardingSeenKey) == nil,
           defaults.bool(forKey: Self.legacyOnboardingSeenKey) {
            defaults.set(true, forKey: Self.onboardingSeenKey)
            defaults.removeObject(forKey: Self.legacyOnboardingSeenKey)
        }
        if let data = defaults.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode(
               ReaderSettings.self, from: data
           ) {
            settings = decoded
        } else {
            settings = ReaderSettings()
        }
        appAppearance = defaults.string(forKey: Self.appearanceKey)
            .flatMap(AppAppearance.init) ?? .system
        isOrientationLocked = defaults.bool(
            forKey: Self.orientationLockKey
        )
        let bundledBackendURL = (
            defaultTranslationBackendURLString
                ?? Self.bundledTranslationBackendURLString
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        translationBackendURLString = defaults.string(
            forKey: Self.translationBackendURLKey
        ) ?? bundledBackendURL
        if let existingUserID = defaults.string(
            forKey: Self.translationUserIDKey
        ), !existingUserID.isEmpty {
            translationUserID = existingUserID
        } else {
            let newUserID = UUID().uuidString
            translationUserID = newUserID
            defaults.set(newUserID, forKey: Self.translationUserIDKey)
        }
    }

    /// Sets and persists the portrait orientation lock.
    func setOrientationLocked(_ locked: Bool) {
        isOrientationLocked = locked
        defaults.set(locked, forKey: Self.orientationLockKey)
    }

    /// Sets and persists the app-wide appearance preference.
    func setAppearance(_ appearance: AppAppearance) {
        appAppearance = appearance
        defaults.set(appearance.rawValue, forKey: Self.appearanceKey)
    }

    func setTranslationBackendURL(_ value: String) {
        translationBackendURLString = value.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        defaults.set(
            translationBackendURLString,
            forKey: Self.translationBackendURLKey
        )
    }

    /// Test/screenshot override for a local translator. Keeping this out of
    /// UserDefaults prevents an automated run from changing the endpoint a
    /// person configured in Settings.
    func overrideTranslationBackendURLWithoutPersisting(_ value: String) {
        translationBackendURLString = value.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }

    /// Parsed backend URL, or nil when unset/invalid. Only http/https with a
    /// non-empty host is accepted: this is the gate that stops a typo'd or
    /// pasted arbitrary URL (file://, mailto:, host-less garbage) from silently
    /// uploading the user's EPUB somewhere unintended.
    var translationBackendURL: URL? {
        guard !translationBackendURLString.isEmpty,
              let url = URL(string: translationBackendURLString),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = url.host, !host.isEmpty
        else { return nil }
        return url
    }

    func update(_ transform: (ReaderSettings) -> ReaderSettings) {
        settings = transform(settings)
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: Self.key)
        }
    }

    /// Whether the complete first-launch onboarding has been finished.
    /// Stored under its own key so it never bloats the codable settings.
    var hasSeenOnboarding: Bool {
        defaults.bool(forKey: Self.onboardingSeenKey)
    }

    /// Records that onboarding has been completed; subsequent launches
    /// go straight to the library.
    func markOnboardingSeen() {
        defaults.set(true, forKey: Self.onboardingSeenKey)
    }

    /// Applies launch-argument overrides without persisting them, so
    /// forced test/screenshot configurations don't leak between runs.
    func overrideWithoutPersisting(
        _ transform: (ReaderSettings) -> ReaderSettings
    ) {
        settings = transform(settings)
    }

    /// Wipes persisted settings; used by the `-resetSettings` launch
    /// argument so UI tests start from a known configuration.
    static func resetPersisted(in defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key)
        defaults.removeObject(forKey: onboardingSeenKey)
        defaults.removeObject(forKey: legacyOnboardingSeenKey)
        defaults.removeObject(forKey: appearanceKey)
        defaults.removeObject(forKey: translationBackendURLKey)
        defaults.removeObject(forKey: translationUserIDKey)
        defaults.removeObject(forKey: orientationLockKey)
    }
}
