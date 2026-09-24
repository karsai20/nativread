import SwiftUI

/// Who is on the translate stage right now, and which shelf they came from.
/// Owned by the app shell so the stage can cover the tab bar, and shared
/// through the environment so any shelf can put a book on it and mark its
/// cover as the lift-off point.
@Observable
final class TranslationPresenter {
    /// A shelf that hosts hero covers. Each host keys its matched-geometry
    /// ids separately: the same book sits on the Library grid and in the
    /// Translate list at once, and two sources for one id fight.
    enum Host: String {
        case library, translate
    }

    static var animation: Animation {
        UIAccessibility.isReduceMotionEnabled
            ? .easeOut(duration: 0.2)
            : .spring(response: 0.45, dampingFraction: 1)
    }

    /// The book whose cover is off the shelf — on stage, or still flying.
    private(set) var book: Book?
    private(set) var host: Host = .library
    /// Whether the cover sits on the page (true) or over its shelf slot.
    /// Mounting (`book`) and lifting are separate steps so the cover is laid
    /// out once over the shelf before it flies — one cover, never a fade.
    private(set) var isLifted = false
    /// Counts closes, so a flight's completion can tell it is not the latest.
    @ObservationIgnored private var dismissals = 0

    /// Mounts the stage with the cover over its shelf slot; the stage calls
    /// `lift()` once it has appeared. Allowed while a cover is still flying
    /// home — the shelf is live again by then.
    func present(_ book: Book, from host: Host) {
        guard !isLifted else { return }
        // Same cover caught mid-flight home: the stage is still mounted, so
        // there is no fresh appear to lift it — turn it around here.
        if self.book?.id == book.id, self.host == host { return lift() }
        self.host = host
        self.book = book
    }

    func lift() {
        withAnimation(Self.animation) {
            isLifted = true
        }
    }

    /// Flies the cover home, then unmounts the stage — the shelf cover only
    /// reappears once the flying one has landed on it.
    func dismiss() {
        dismissals += 1
        let thisDismissal = dismissals
        withAnimation(Self.animation) {
            isLifted = false
        } completion: {
            // A book may have been lifted — or lifted and closed again —
            // while this one flew home; only the latest flight unmounts.
            guard !self.isLifted, self.dismissals == thisDismissal else { return }
            self.book = nil
        }
    }

    /// Matched-geometry id for a cover on `host`.
    static func heroID(for book: Book, host: Host) -> String {
        "translation-cover-\(host.rawValue)-\(book.id)"
    }

    /// Matched-geometry id for the cover's place on the stage page.
    static let stageSlotID = "translation-cover-stage-slot"
}
