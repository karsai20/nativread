import Foundation
import Observation

/// Persists reader typography settings. Mutations always go through
/// `update(_:)` which writes a fresh value (no in-place mutation leaks).
@Observable
final class SettingsStore {
    private(set) var settings: ReaderSettings

    private let defaults: UserDefaults
    private static let key = "lumenread.readerSettings.v2"

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
    }

    func update(_ transform: (ReaderSettings) -> ReaderSettings) {
        settings = transform(settings)
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: Self.key)
        }
    }
}
