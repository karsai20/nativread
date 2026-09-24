import SwiftUI

/// Which book's translate page is open. Owned by the app shell and shared
/// through the environment, so any shelf can open a book's page.
@Observable
final class TranslationPresenter {
    private(set) var book: Book?

    func present(_ book: Book) { self.book = book }

    func dismiss() { book = nil }
}
