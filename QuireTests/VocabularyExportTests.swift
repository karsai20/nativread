import XCTest
@testable import Quire

final class VocabularyExportTests: XCTestCase {

    private func makeEntry(
        word: String = "lantern",
        definition: String = "a portable light",
        context: String? = "She raised the lantern high.",
        source: String = "WordNet",
        note: String? = nil
    ) -> VocabularyEntry {
        VocabularyEntry(
            word: word,
            definition: definition,
            contextSentence: context,
            dictionarySource: source,
            note: note
        )
    }

    // MARK: - CSV columns / rows

    func testCSVHasHeaderAndOneRowPerEntry() {
        let csv = VocabularyExport.csv(
            for: [makeEntry(word: "alpha"), makeEntry(word: "beta")],
            cloze: false
        )
        let rows = csv
            .split(separator: "\r\n", omittingEmptySubsequences: true)
            .map(String.init)

        XCTAssertEqual(rows.first, "Word,Context,Definition,Source,Note,Date")
        XCTAssertEqual(rows.count, 3) // header + two entries
        XCTAssertTrue(rows[1].hasPrefix("alpha,"))
        XCTAssertTrue(rows[2].hasPrefix("beta,"))
    }

    func testCSVEmptyEntriesIsHeaderOnly() {
        let csv = VocabularyExport.csv(for: [], cloze: false)
        XCTAssertEqual(csv, "Word,Context,Definition,Source,Note,Date\r\n")
    }

    func testCSVEscapesCommaAndQuote() {
        let entry = makeEntry(
            context: "He said, \"hi\" to the room"
        )
        let csv = VocabularyExport.csv(for: [entry], cloze: false)
        XCTAssertTrue(
            csv.contains("\"He said, \"\"hi\"\" to the room\"")
        )
    }

    func testCSVEmptyContextAndNoteAreBlankFields() {
        let entry = makeEntry(context: nil, note: nil)
        let csv = VocabularyExport.csv(for: [entry], cloze: false)
        let rows = csv.split(separator: "\r\n").map(String.init)
        // Word,Context,Definition,Source,Note,Date -> context empty, note empty
        XCTAssertEqual(rows[1], "lantern,,a portable light,WordNet,,"
            + ISO8601DateFormatter().string(from: entry.createdAt))
    }

    // MARK: - Cloze

    func testClozeWrapsWordInContextCaseInsensitive() {
        let entry = makeEntry(
            word: "Lantern",
            context: "She raised the lantern high."
        )
        let csv = VocabularyExport.csv(for: [entry], cloze: true)
        // Original casing inside cloze is preserved from the context match.
        XCTAssertTrue(csv.contains("She raised the {{c1::lantern}} high."))
    }

    func testClozeFallsBackToBareWordWhenNoContext() {
        let entry = makeEntry(word: "ephemeral", context: nil)
        let csv = VocabularyExport.csv(for: [entry], cloze: true)
        XCTAssertTrue(csv.contains("{{c1::ephemeral}}"))
    }

    func testClozeFallsBackWhenWordNotInContext() {
        let entry = makeEntry(
            word: "absent",
            context: "This sentence has no target."
        )
        let result = VocabularyExport.clozeContext(for: entry)
        XCTAssertEqual(result, "{{c1::absent}}")
    }

    func testPlainCSVDoesNotWrapInCloze() {
        let entry = makeEntry(context: "She raised the lantern high.")
        let csv = VocabularyExport.csv(for: [entry], cloze: false)
        XCTAssertFalse(csv.contains("{{c1::"))
        XCTAssertTrue(csv.contains("She raised the lantern high."))
    }

    // MARK: - Markdown

    func testMarkdownShape() {
        let entry = makeEntry(
            word: "lantern",
            definition: "a portable light",
            context: "She raised the lantern high.",
            note: "from the prologue"
        )
        let md = VocabularyExport.markdown(for: [entry])

        XCTAssertTrue(md.hasPrefix("# My Vocabulary"))
        XCTAssertTrue(md.contains("## lantern"))
        XCTAssertTrue(md.contains("> *She raised the lantern high.*"))
        XCTAssertTrue(md.contains("a portable light"))
        XCTAssertTrue(md.contains("*Note: from the prologue*"))
        XCTAssertTrue(md.contains("WordNet ·"))
    }

    func testMarkdownOmitsBlankNoteAndContext() {
        let entry = makeEntry(context: "   ", note: "  ")
        let md = VocabularyExport.markdown(for: [entry])
        XCTAssertFalse(md.contains("Note:"))
        XCTAssertFalse(md.contains("> *"))
    }
}
