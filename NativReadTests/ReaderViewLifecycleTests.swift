import SwiftUI
import XCTest
@testable import NativRead

/// A reading session must own exactly one WKWebView. `ReaderView` is built
/// inside a `fullScreenCover` closure that SwiftUI re-runs whenever the
/// library changes — and the library changes on every saved scroll
/// position. Each throwaway view model used to spin up (and tear down) a
/// WebContent process; on iPhone 17 / iOS 26.6 that churn deadlocked
/// RunningBoard and hung the app (0x8BADF00D).
@MainActor
final class ReaderViewLifecycleTests: XCTestCase {

    private struct Host: View {
        let library: LibraryStore
        let settings: SettingsStore
        let book: Book
        var body: some View {
            // Read something observable so a progress save re-renders us,
            // exactly like the shelf behind the reader does.
            let _ = library.books.first?.progress.pageFraction
            ReaderView(
                book: book, library: library,
                settingsStore: settings, initialSystemDark: false
            )
        }
    }

    func testProgressSavesDoNotRecreateTheWebView() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("reader-lifecycle-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let library = LibraryStore(rootDirectory: root)
        let sample = try XCTUnwrap(
            Bundle.main.url(forResource: "sample", withExtension: "epub")
        )
        let book = try library.importBook(from: sample)
        let settings = SettingsStore(
            defaults: UserDefaults(suiteName: UUID().uuidString)!
        )

        let before = ReaderController.createdCount
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        let host = UIHostingController(rootView: Host(
            library: library, settings: settings, book: book
        ))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: .now + 0.3)
        XCTAssertEqual(ReaderController.createdCount - before, 1, "one reader, one web view")

        // Five scroll settles, five progress saves, five parent re-renders.
        for step in 1...5 {
            library.updateProgress(
                bookID: book.id, spineIndex: 0, pageFraction: Double(step) / 10
            )
            host.view.setNeedsLayout()
            host.view.layoutIfNeeded()
            RunLoop.main.run(until: .now + 0.1)
        }
        XCTAssertEqual(
            ReaderController.createdCount - before, 1,
            "a progress save must never build another WKWebView"
        )
    }
}
