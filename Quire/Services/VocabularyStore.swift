import Foundation
import Observation

/// Owns the reader's global saved vocabulary. Persists the list as JSON
/// in the app's Documents directory, mirroring `StatsStore`/`LibraryStore`:
/// load-on-init, coalesced (0.6 s debounced) saves so a burst of edits
/// writes once. Strictly local — nothing leaves the device.
@MainActor
@Observable
final class VocabularyStore {
    /// Newest first, so the list reads as a recent-saves feed.
    private(set) var entries: [VocabularyEntry] = []

    private let root: URL
    private let fileManager = FileManager.default

    /// How long edits coalesce before a single disk write.
    private static let saveDebounce: TimeInterval = 0.6

    private var indexURL: URL { root.appendingPathComponent("vocabulary.json") }

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

    // MARK: - Mutations

    /// Saves a word, deduping case-insensitively on the word itself: if
    /// the word is already saved this is a no-op (the existing entry,
    /// note and context are preserved), so re-saving from anywhere is
    /// idempotent. New entries land at the front of the list.
    func addEntry(_ entry: VocabularyEntry) {
        guard !contains(word: entry.word) else { return }
        entries.insert(entry, at: 0)
        scheduleSave()
    }

    func removeEntry(_ id: UUID) {
        guard entries.contains(where: { $0.id == id }) else { return }
        entries.removeAll { $0.id == id }
        scheduleSave()
    }

    /// Sets or clears the reader's note on an entry. A blank or
    /// whitespace-only note is stored as `nil`, never an empty string.
    func setNote(entryID: UUID, note: String?) {
        guard let index = entries.firstIndex(where: { $0.id == entryID })
        else { return }
        let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        var updated = entries[index]
        updated.note = (trimmed?.isEmpty ?? true) ? nil : trimmed
        entries[index] = updated
        scheduleSave()
    }

    /// True when a word (case/whitespace-insensitive) is already saved,
    /// so the Define sheet can reflect an already-saved state on open.
    func contains(word: String) -> Bool {
        let key = word
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !key.isEmpty else { return false }
        return entries.contains { $0.dedupKey == key }
    }

    // MARK: - Persistence

    private var pendingSave: DispatchWorkItem?

    /// Coalesces a burst of edits into a single write 0.6 s later.
    private func scheduleSave() {
        pendingSave?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.pendingSave = nil
            self?.save()
        }
        pendingSave = work
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Self.saveDebounce, execute: work
        )
    }

    /// Persists any pending coalesced edits immediately.
    func flushPendingSave() {
        guard pendingSave != nil else { return }
        pendingSave?.cancel()
        pendingSave = nil
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: indexURL),
              let decoded = try? JSONDecoder().decode(
                  [VocabularyEntry].self, from: data
              )
        else { return }
        entries = decoded
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(entries) else { return }
        try? data.write(to: indexURL, options: .atomic)
    }
}
