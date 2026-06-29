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

    private let defaults: UserDefaults
    private static let key = "lumenread.readerSettings.v2"
    private static let onboardingSeenKey = "quire.onboarding.v1.seen"
    private static let appearanceKey = "nativread.appAppearance.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
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
    }

    /// Sets and persists the app-wide appearance preference.
    func setAppearance(_ appearance: AppAppearance) {
        appAppearance = appearance
        defaults.set(appearance.rawValue, forKey: Self.appearanceKey)
    }

    func update(_ transform: (ReaderSettings) -> ReaderSettings) {
        settings = transform(settings)
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: Self.key)
        }
    }

    /// Whether the first-launch brand splash has already been shown.
    /// Stored under its own key so it never bloats the codable settings.
    var hasSeenOnboarding: Bool {
        defaults.bool(forKey: Self.onboardingSeenKey)
    }

    /// Records that the launch splash has been seen; subsequent launches
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
        defaults.removeObject(forKey: appearanceKey)
    }
}
