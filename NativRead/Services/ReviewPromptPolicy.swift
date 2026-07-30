import Foundation

/// When to ask for an App Store review (CEO D3.3 / blueprint §4): only at
/// peak-happiness — the moment the user finishes their first AI-translated
/// book, or their third finished book for just-readers. Fires at most once
/// ever. Callers only invoke this on the not-finished → finished transition,
/// so error paths and onboarding can never trigger a prompt.
struct ReviewPromptPolicy {
    private let defaults: UserDefaults
    private static let firedKey = "nativread.reviewPrompt.fired.v1"
    private static let finishedCountKey = "nativread.reviewPrompt.finishedBooks.v1"
    /// Just-readers get the prompt on their third finished book — by then the
    /// reader has proven itself, and one book might have been a test import.
    private static let justReaderThreshold = 3

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Records a book transitioning to finished; returns true when the review
    /// prompt should be shown now (and marks it as fired so it never repeats).
    func registerFinishedBook(isTranslated: Bool) -> Bool {
        let count = defaults.integer(forKey: Self.finishedCountKey) + 1
        defaults.set(count, forKey: Self.finishedCountKey)

        guard !defaults.bool(forKey: Self.firedKey) else { return false }
        guard isTranslated || count >= Self.justReaderThreshold else {
            return false
        }
        defaults.set(true, forKey: Self.firedKey)
        return true
    }
}
