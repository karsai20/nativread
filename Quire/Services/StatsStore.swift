import Foundation
import Observation

/// Owns local reading statistics. Persists a single `ReadingStats` value
/// as JSON in the app's Documents directory, mirroring `LibraryStore`'s
/// load-on-init / save-on-change shape. Strictly local — nothing leaves
/// the device.
@Observable
final class StatsStore {
    private(set) var stats: ReadingStats = ReadingStats()

    private let root: URL
    private let fileManager = FileManager.default

    /// A single reading session never legitimately exceeds this; longer
    /// elapsed time means the app was left open (e.g. backgrounded
    /// overnight), so the contribution is clamped to this cap.
    static let maxSessionSeconds: TimeInterval = 4 * 60 * 60

    private var indexURL: URL { root.appendingPathComponent("stats.json") }

    init(rootDirectory: URL? = nil) {
        if let rootDirectory {
            self.root = rootDirectory
        } else {
            let documents = FileManager.default
                .urls(for: .documentDirectory, in: .userDomainMask)[0]
            self.root = documents.appendingPathComponent("Quire")
        }
        try? fileManager.createDirectory(
            at: root, withIntermediateDirectories: true
        )
        load()
    }

    /// Records a reading session. Ignores non-positive durations and
    /// clamps absurdly long ones so an app left open doesn't poison the
    /// stats. Persists once per call (session end), not per sub-second.
    func record(seconds: TimeInterval, on day: Date = .now) {
        guard seconds > 0 else { return }
        let clamped = min(seconds, Self.maxSessionSeconds)
        stats = stats.addingSeconds(clamped, on: day)
        save()
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: indexURL),
              let decoded = try? JSONDecoder().decode(
                  ReadingStats.self, from: data
              )
        else { return }
        stats = decoded
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(stats) else { return }
        try? data.write(to: indexURL, options: .atomic)
    }
}
