import XCTest
@testable import LumenRead

final class SearchServiceTests: XCTestCase {

    func testPlainTextStripsMarkupAndEntities() {
        let xhtml = """
        <html><head><style>p{color:red}</style>\
        <script>alert(1)</script></head>
        <body><h1>Title</h1><p>The <em>lantern</em> &amp; the sea&hellip;\
        </p></body></html>
        """
        let text = SearchService.plainText(fromXHTML: xhtml)
        XCTAssertEqual(text, "Title The lantern & the sea…")
    }

    func testMatchesAreCaseAndDiacriticInsensitive() {
        let text = "A Lámpás égett. A lámpás kialudt. LÁMPÁS!"
        let results = SearchService.matches(
            in: text, query: "lampas", spineIndex: 2, chapterTitle: "Ch"
        )
        XCTAssertEqual(results.count, 3)
        XCTAssertEqual(results.map(\.occurrenceInChapter), [0, 1, 2])
        XCTAssertEqual(results[0].spineIndex, 2)
    }

    func testShortQueriesReturnNothing() {
        XCTAssertTrue(SearchService.matches(
            in: "aaaa", query: "a", spineIndex: 0, chapterTitle: ""
        ).isEmpty)
    }

    func testSnippetSurroundsMatch() {
        let text = String(repeating: "x", count: 200)
            + " needle " + String(repeating: "y", count: 200)
        let results = SearchService.matches(
            in: text, query: "needle", spineIndex: 0, chapterTitle: ""
        )
        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results[0].snippet.contains("needle"))
        XCTAssertTrue(results[0].snippet.hasPrefix("…"))
        XCTAssertTrue(results[0].snippet.hasSuffix("…"))
        XCTAssertLessThan(results[0].snippet.count, 160)
    }

    func testSearchSpansChaptersAndCapsResultCount() throws {
        let root = try EPUBFixtures.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        try EPUBFixtures.writeEPUB3(to: root, chapterCount: 3)
        // Chapter 3 gets a word that exists nowhere else in the book.
        try EPUBFixtures.chapterXHTML(
            title: "Part 3", body: "Only here: zephyrglass."
        ).write(
            to: root.appendingPathComponent("OEBPS/ch3.xhtml"),
            atomically: true, encoding: .utf8
        )
        let parsed = try EPUBParser.parse(extractedRoot: root)

        // A rare word is found in the right chapter with the right title.
        let rare = SearchService.search(query: "zephyrglass", in: parsed)
        XCTAssertEqual(rare.map(\.spineIndex), [2])
        XCTAssertEqual(rare.first?.chapterTitle, "Part 3")

        // A frequent word spans chapters but is capped at maxResults
        // (40 matches per fixture chapter → the cap fills mid-book).
        let frequent = SearchService.search(query: "lantern", in: parsed)
        XCTAssertEqual(frequent.count, SearchService.maxResults)
        XCTAssertEqual(Set(frequent.map(\.spineIndex)), [0, 1])
        XCTAssertEqual(frequent.first?.chapterTitle, "Part 1")
    }

    func testChapterTitleFallsBackToLatestTOCEntry() throws {
        let root = try EPUBFixtures.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        try EPUBFixtures.writeEPUB3(to: root, chapterCount: 3)
        let parsed = try EPUBParser.parse(extractedRoot: root)

        XCTAssertEqual(
            SearchService.chapterTitle(forSpineIndex: 2, in: parsed),
            "Part 3"
        )
    }
}
