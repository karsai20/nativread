import Foundation

/// Pure, value-type record of reading time per calendar day.
///
/// Days are keyed by an ISO `yyyy-MM-dd` string. All day strings are
/// derived in the **current** calendar/time zone so the chart and streak
/// match what the reader sees on their own clock — a session at 11pm and
/// one at 1am the next night are two different days for them. The fixed
/// formatter below is the single source of truth for that mapping.
struct ReadingStats: Codable, Equatable {
    /// Seconds read, keyed by `yyyy-MM-dd` in the current calendar.
    private(set) var dailySeconds: [String: TimeInterval]

    init(dailySeconds: [String: TimeInterval] = [:]) {
        self.dailySeconds = dailySeconds
    }

    // MARK: - Day keys

    /// Formatter for `yyyy-MM-dd` keys. POSIX locale keeps the format
    /// stable across regions; the current calendar/time zone keeps days
    /// aligned to the reader's local midnight.
    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar.current
        formatter.timeZone = Calendar.current.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func dayKey(for day: Date) -> String {
        dayFormatter.string(from: day)
    }

    // MARK: - Immutable updates

    /// Returns a new value with `seconds` added to `day`. Non-positive
    /// durations are ignored (returns an unchanged copy).
    func addingSeconds(_ seconds: TimeInterval, on day: Date) -> ReadingStats {
        guard seconds > 0 else { return self }
        let key = Self.dayKey(for: day)
        var updated = dailySeconds
        updated[key, default: 0] += seconds
        return ReadingStats(dailySeconds: updated)
    }

    // MARK: - Derived values

    var totalSeconds: TimeInterval {
        dailySeconds.values.reduce(0, +)
    }

    /// Number of consecutive days, counting backward, on which any
    /// reading happened (seconds > 0).
    ///
    /// Anchoring rule: the streak is anchored to **today** if today has
    /// reading, otherwise to **yesterday**. This way a streak stays
    /// "alive" for the whole of the following day before it lapses — you
    /// don't lose your streak the instant midnight passes; you lose it
    /// only after a full calendar day with no reading. If neither today
    /// nor yesterday has reading, the streak is 0.
    var currentStreak: Int {
        currentStreak(asOf: .now)
    }

    /// Testable form of `currentStreak` with an injectable "now".
    func currentStreak(asOf now: Date) -> Int {
        let calendar = Calendar.current
        guard let yesterday = calendar.date(
            byAdding: .day, value: -1, to: now
        ) else { return 0 }

        let anchor: Date
        if hasReading(on: now) {
            anchor = now
        } else if hasReading(on: yesterday) {
            anchor = yesterday
        } else {
            return 0
        }

        var streak = 0
        var cursor = anchor
        while hasReading(on: cursor) {
            streak += 1
            guard let previous = calendar.date(
                byAdding: .day, value: -1, to: cursor
            ) else { break }
            cursor = previous
        }
        return streak
    }

    private func hasReading(on day: Date) -> Bool {
        (dailySeconds[Self.dayKey(for: day)] ?? 0) > 0
    }

    /// Per-day totals for the last `n` days ending on `day`, oldest
    /// first. Zero-days are included so a chart has continuous bars.
    func dailyTotals(
        lastDays n: Int, endingOn day: Date
    ) -> [(day: Date, seconds: TimeInterval)] {
        guard n > 0 else { return [] }
        let calendar = Calendar.current
        let endStart = calendar.startOfDay(for: day)
        return (0..<n).reversed().compactMap { offset in
            guard let date = calendar.date(
                byAdding: .day, value: -offset, to: endStart
            ) else { return nil }
            let seconds = dailySeconds[Self.dayKey(for: date)] ?? 0
            return (day: date, seconds: seconds)
        }
    }
}
