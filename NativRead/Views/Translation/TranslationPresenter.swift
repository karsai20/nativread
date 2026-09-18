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

    private(set) var book: Book?
    private(set) var host: Host = .library

    func present(_ book: Book, from host: Host) {
        self.host = host
        self.book = book
    }

    func dismiss() { book = nil }

    /// Matched-geometry id for a cover on `host`.
    static func heroID(for book: Book, host: Host) -> String {
        "translation-cover-\(host.rawValue)-\(book.id)"
    }
}
