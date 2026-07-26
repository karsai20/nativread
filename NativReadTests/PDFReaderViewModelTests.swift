import XCTest
import UIKit
@testable import NativRead

@MainActor
final class PDFReaderViewModelTests: XCTestCase {

    private var root: URL!

    override func setUp() async throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("pdfvm-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: root, withIntermediateDirectories: true
        )
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: root)
    }

    /// Writes a minimal multi-page PDF.
    private func makePDF(at url: URL, pages: Int) throws {
        let bounds = CGRect(x: 0, y: 0, width: 200, height: 300)
        let renderer = UIGraphicsPDFRenderer(bounds: bounds)
        try renderer.writePDF(to: url) { context in
            for index in 0..<pages {
                context.beginPage()
                ("Page \(index + 1) lorem ipsum sample" as NSString).draw(
                    at: CGPoint(x: 20, y: 20), withAttributes: nil
                )
            }
        }
    }

    private func makeStore() -> LibraryStore {
        LibraryStore(rootDirectory: root.appendingPathComponent("store"))
    }

    private func makeViewModel(
        store: LibraryStore, book: Book
    ) -> PDFReaderViewModel {
        PDFReaderViewModel(
            book: book,
            library: store,
            settingsStore: SettingsStore(
                defaults: UserDefaults(suiteName: UUID().uuidString)!
            )
        )
    }

    /// Imports a fresh PDF and returns the (store, book, viewModel) triple.
    private func makeReader(pages: Int) throws
        -> (LibraryStore, Book, PDFReaderViewModel) {
        let pdfURL = root.appendingPathComponent("source-\(UUID().uuidString).pdf")
        try makePDF(at: pdfURL, pages: pages)
        let store = makeStore()
        let book = try store.importBook(from: pdfURL)
        return (store, book, makeViewModel(store: store, book: book))
    }

    // MARK: - Paging clamps

    func testSetPageClampsBelowZeroAndAboveLast() throws {
        let (_, _, vm) = try makeReader(pages: 5)

        vm.setPage(-5)
        XCTAssertEqual(vm.page, 0)

        vm.setPage(9999)
        XCTAssertEqual(vm.page, 4)
    }

    func testSetPageIsNoOpForSamePage() throws {
        let (store, book, vm) = try makeReader(pages: 5)
        vm.setPage(3)
        XCTAssertEqual(vm.page, 3)
        XCTAssertEqual(store.book(id: book.id)?.progress.spineIndex, 3)

        // Re-setting the same page must not change state or re-persist.
        vm.setPage(3)
        XCTAssertEqual(vm.page, 3)
    }

    func testSetPagePersistsProgress() throws {
        let (store, book, vm) = try makeReader(pages: 4)
        vm.setPage(2)

        XCTAssertEqual(store.book(id: book.id)?.progress.spineIndex, 2)
        // pageFraction is stored as 1.0 so (page+1)/count math is exact.
        XCTAssertEqual(store.book(id: book.id)?.progress.pageFraction, 1.0)
    }

    /// Regression: tap-zone / TOC / search / scrubber navigation moves `page`
    /// first, then the PDFView settle fires setPage(samePage). Persistence must
    /// still run — deduping on `page` (the old bug) dropped every such turn.
    func testTapNavigationPersistsProgress() throws {
        let (store, book, vm) = try makeReader(pages: 6)

        // Simulate a tap-zone turn: handleTap -> goToPage moves page, then the
        // PDFView settles and reports the new page back via setPage.
        vm.handleTap(zone: "right") // goToPage(1)
        XCTAssertEqual(vm.page, 1)
        vm.setPage(1)               // settle echo from .PDFViewPageChanged

        XCTAssertEqual(store.book(id: book.id)?.progress.spineIndex, 1)

        // And again for a TOC/search-style jump via goToPage.
        vm.goToPage(4)
        vm.setPage(4)
        XCTAssertEqual(store.book(id: book.id)?.progress.spineIndex, 4)
    }

    func testGoToPageClampsToRange() throws {
        let (_, _, vm) = try makeReader(pages: 3)
        vm.goToPage(-1)
        XCTAssertEqual(vm.page, 0)
        vm.goToPage(100)
        XCTAssertEqual(vm.page, 2)
    }

    // MARK: - Scrub & bookFraction round-trip

    func testScrubLandsOnFirstMiddleLastPage() throws {
        let (_, _, vm) = try makeReader(pages: 10)

        vm.scrub(toFraction: 0)
        XCTAssertEqual(vm.page, 0)

        vm.scrub(toFraction: 0.5)
        XCTAssertEqual(vm.page, 5)

        // fraction 1.0 would compute index == pageCount; must clamp to last.
        vm.scrub(toFraction: 1.0)
        XCTAssertEqual(vm.page, 9)
    }

    func testBookFractionIsOneOnLastPage() throws {
        let (_, _, vm) = try makeReader(pages: 8)
        vm.goToPage(7)
        XCTAssertEqual(vm.bookFraction, 1.0, accuracy: 0.0001)
        vm.goToPage(0)
        XCTAssertEqual(vm.bookFraction, 1.0 / 8.0, accuracy: 0.0001)
    }

    // MARK: - Search

    func testRunSearchBelowMinimumLengthClearsState() throws {
        let (_, _, vm) = try makeReader(pages: 2)
        vm.searchQuery = "a"
        vm.runSearch()

        XCTAssertTrue(vm.searchResults.isEmpty)
        XCTAssertFalse(vm.hasSearched)
        XCTAssertFalse(vm.isSearching)
    }

    func testRunSearchWithNoMatchMarksSearched() throws {
        let (_, _, vm) = try makeReader(pages: 2)
        vm.searchQuery = "zzzznotpresent"
        vm.runSearch()

        XCTAssertTrue(vm.searchResults.isEmpty)
        XCTAssertTrue(vm.hasSearched)
        XCTAssertFalse(vm.isSearching)
    }

    func testRunSearchFindsMatch() throws {
        let (_, _, vm) = try makeReader(pages: 3)
        vm.searchQuery = "lorem"
        vm.runSearch()

        XCTAssertTrue(vm.hasSearched)
        XCTAssertFalse(vm.searchResults.isEmpty)
    }

    // MARK: - Outline fallback

    func testEmptyOutlineFallsBackToPageLabel() throws {
        // Renderer-built PDFs carry no outline, so toc is empty and the
        // chapter title falls back to the page label.
        let (_, _, vm) = try makeReader(pages: 2)
        XCTAssertTrue(vm.toc.isEmpty)
        vm.goToPage(0)
        XCTAssertEqual(vm.currentChapterTitle, "Page 1")
        vm.goToPage(1)
        XCTAssertEqual(vm.currentChapterTitle, "Page 2")
    }

    // MARK: - Bookmarks

    func testToggleBookmarkAddsThenRemoves() throws {
        let (store, book, vm) = try makeReader(pages: 4)
        vm.goToPage(2)

        vm.toggleBookmark()
        XCTAssertNotNil(vm.currentBookmark)
        XCTAssertEqual(store.book(id: book.id)?.bookmarks.count, 1)
        XCTAssertEqual(vm.currentBookmark?.spineIndex, 2)

        vm.toggleBookmark()
        XCTAssertNil(vm.currentBookmark)
        XCTAssertEqual(store.book(id: book.id)?.bookmarks.count, 0)
    }

    func testGoToBookmarkJumpsToPage() throws {
        let (_, _, vm) = try makeReader(pages: 6)
        let bookmark = Bookmark(
            spineIndex: 4, pageFraction: 0,
            chapterTitle: "Page 5", snippet: "x"
        )
        vm.goTo(bookmark: bookmark)
        XCTAssertEqual(vm.page, 4)
        XCTAssertNil(vm.activeSheet)
    }

    // MARK: - Tap zones

    func testTapZonesPage() throws {
        let (_, _, vm) = try makeReader(pages: 5)
        vm.goToPage(2)
        vm.handleTap(zone: "left")
        XCTAssertEqual(vm.page, 1)
        vm.handleTap(zone: "right")
        XCTAssertEqual(vm.page, 2)
    }

    func testCenterTapTogglesChrome() throws {
        let (_, _, vm) = try makeReader(pages: 2)
        XCTAssertTrue(vm.isChromeVisible)
        vm.handleTap(zone: "center")
        XCTAssertFalse(vm.isChromeVisible)
    }

    // MARK: - Load failure

    func testUnreadableDocumentSetsLoadErrorAndClampsPage() throws {
        let (store, book, _) = try makeReader(pages: 3)
        // Corrupt the stored file, then open a fresh reader over it.
        let storedURL = store.booksDirectory
            .appendingPathComponent(book.fileName)
        try Data("not a pdf".utf8).write(to: storedURL)

        let vm = makeViewModel(store: store, book: book)
        XCTAssertNotNil(vm.loadError)
        XCTAssertEqual(vm.page, 0)
        XCTAssertEqual(vm.pageCount, 1)
    }

    func testInitRestoresSavedPageClamped() throws {
        let (store, book, vm) = try makeReader(pages: 5)
        vm.setPage(3)

        // A fresh reader for the same book restores the persisted page.
        let reopened = makeViewModel(
            store: store, book: store.book(id: book.id)!
        )
        XCTAssertEqual(reopened.page, 3)
    }
}
