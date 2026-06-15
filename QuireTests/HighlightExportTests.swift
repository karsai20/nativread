import XCTest
@testable import Quire

final class HighlightExportTests: XCTestCase {

    private func makeBook(
        title: String = "The Sea and the Lantern",
        author: String = "A. Writer",
        highlights: [Highlight] = []
    ) -> Book {
        Book(
            title: title, author: author,
            fileName: "book.epub", highlights: highlights
        )
    }

    // MARK: - Markdown

    func testMarkdownIncludesTitleAndAuthor() {
        let book = makeBook(highlights: [
            Highlight(
                spineIndex: 0, text: "A lantern in the dark",
                occurrence: 0, chapterTitle: "Part 1"
            )
        ])

        let markdown = HighlightExport.markdown(for: book)

        XCTAssertTrue(markdown.hasPrefix("# The Sea and the Lantern"))
        XCTAssertTrue(markdown.contains("by A. Writer"))
        XCTAssertTrue(markdown.contains("## Part 1"))
        XCTAssertTrue(markdown.contains("> A lantern in the dark"))
    }

    func testMarkdownGroupsByChapterInFirstAppearanceOrder() {
        let book = makeBook(highlights: [
            Highlight(
                spineIndex: 0, text: "first", occurrence: 0,
                chapterTitle: "Chapter One"
            ),
            Highlight(
                spineIndex: 1, text: "second", occurrence: 0,
                chapterTitle: "Chapter Two"
            ),
            Highlight(
                spineIndex: 0, text: "third", occurrence: 1,
                chapterTitle: "Chapter One"
            )
        ])

        let markdown = HighlightExport.markdown(for: book)

        // Each chapter heading appears exactly once.
        XCTAssertEqual(
            markdown.components(separatedBy: "## Chapter One").count - 1, 1
        )
        XCTAssertEqual(
            markdown.components(separatedBy: "## Chapter Two").count - 1, 1
        )
        // Chapter One precedes Chapter Two (first-appearance order).
        let oneRange = markdown.range(of: "## Chapter One")!
        let twoRange = markdown.range(of: "## Chapter Two")!
        XCTAssertTrue(oneRange.lowerBound < twoRange.lowerBound)
        // Both highlights from Chapter One are grouped under it.
        XCTAssertTrue(markdown.contains("> first"))
        XCTAssertTrue(markdown.contains("> third"))
    }

    func testMarkdownOmitsAuthorLineWhenEmpty() {
        let book = makeBook(author: "", highlights: [
            Highlight(
                spineIndex: 0, text: "x", occurrence: 0,
                chapterTitle: "Ch"
            )
        ])

        let markdown = HighlightExport.markdown(for: book)

        XCTAssertFalse(markdown.contains("by "))
    }

    func testMarkdownEmptyHighlightsStillHasTitle() {
        let markdown = HighlightExport.markdown(for: makeBook())

        XCTAssertTrue(markdown.hasPrefix("# The Sea and the Lantern"))
        XCTAssertFalse(markdown.contains("## "))
    }

    // MARK: - CSV

    func testCSVHasHeaderAndOneRowPerHighlight() {
        let book = makeBook(highlights: [
            Highlight(
                spineIndex: 0, text: "alpha", occurrence: 0,
                chapterTitle: "One"
            ),
            Highlight(
                spineIndex: 1, text: "beta", occurrence: 0,
                chapterTitle: "Two"
            )
        ])

        let csv = HighlightExport.csv(for: book)
        let rows = csv
            .split(separator: "\r\n", omittingEmptySubsequences: true)
            .map(String.init)

        XCTAssertEqual(rows.first, "Chapter,Highlight,Date,Note")
        XCTAssertEqual(rows.count, 3) // header + two highlights
        XCTAssertTrue(rows[1].hasPrefix("One,alpha,"))
        XCTAssertTrue(rows[2].hasPrefix("Two,beta,"))
        // No note → trailing empty Note column.
        XCTAssertTrue(rows[1].hasSuffix(","))
        XCTAssertTrue(rows[2].hasSuffix(","))
    }

    func testCSVEscapesCommaAndQuote() {
        let book = makeBook(highlights: [
            Highlight(
                spineIndex: 0,
                text: "He said, \"hello\" to the room",
                occurrence: 0, chapterTitle: "One"
            )
        ])

        let csv = HighlightExport.csv(for: book)

        // The field with a comma and quotes is wrapped and its quotes doubled.
        XCTAssertTrue(
            csv.contains("\"He said, \"\"hello\"\" to the room\"")
        )
    }

    func testCSVEmptyHighlightsIsHeaderOnly() {
        let csv = HighlightExport.csv(for: makeBook(highlights: []))

        XCTAssertEqual(csv, "Chapter,Highlight,Date,Note\r\n")
    }

    // MARK: - Notes

    func testMarkdownIncludesNoteWhenPresent() {
        let book = makeBook(highlights: [
            Highlight(
                spineIndex: 0, text: "A lantern in the dark",
                occurrence: 0, chapterTitle: "Part 1",
                note: "reminds me of the harbour"
            )
        ])

        let markdown = HighlightExport.markdown(for: book)

        XCTAssertTrue(markdown.contains("> A lantern in the dark"))
        XCTAssertTrue(markdown.contains("*Note: reminds me of the harbour*"))
    }

    func testMarkdownOmitsBlankNote() {
        let book = makeBook(highlights: [
            Highlight(
                spineIndex: 0, text: "x", occurrence: 0,
                chapterTitle: "Ch", note: "   "
            )
        ])

        XCTAssertFalse(HighlightExport.markdown(for: book).contains("Note:"))
    }

    func testCSVPopulatesAndEscapesNoteColumn() {
        let book = makeBook(highlights: [
            Highlight(
                spineIndex: 0, text: "alpha", occurrence: 0,
                chapterTitle: "One", note: "a, b \"c\""
            )
        ])

        let csv = HighlightExport.csv(for: book)
        let rows = csv
            .split(separator: "\r\n", omittingEmptySubsequences: true)
            .map(String.init)

        XCTAssertEqual(rows.first, "Chapter,Highlight,Date,Note")
        // The note field with a comma and quotes is wrapped and escaped.
        XCTAssertTrue(rows[1].hasSuffix(",\"a, b \"\"c\"\"\""))
    }
}
