import XCTest
@testable import Quire

final class DefinitionFormatterTests: XCTestCase {

    private func entry(_ definition: String, type: Character = "h")
        -> DictionaryEntry {
        DictionaryEntry(headword: "test", definition: definition, type: type)
    }

    // MARK: - HTML rendering

    func testRendersWordNetHTMLToNonEmptyText() {
        let html = "<i>n.</i> a domesticated carnivore<br>"
            + "<small>Hypernyms:</small> <a href=\"feline\">feline</a>"
        let result = DefinitionFormatter.render(entry(html))
        let plain = String(result.characters)

        XCTAssertFalse(plain.isEmpty)
        XCTAssertTrue(plain.contains("n."))
        XCTAssertTrue(plain.contains("domesticated carnivore"))
        XCTAssertTrue(plain.contains("Hypernyms:"))
        // Cross-link text is kept, the tag is dropped.
        XCTAssertTrue(plain.contains("feline"))
        XCTAssertFalse(plain.contains("<"))
        XCTAssertFalse(plain.contains(">"))
    }

    func testBreakTagBecomesNewline() {
        let result = DefinitionFormatter.render(entry("one<br>two"))
        XCTAssertTrue(String(result.characters).contains("\n"))
    }

    func testPlainTextEntryPassesThrough() {
        let result = DefinitionFormatter.render(
            entry("just plain text", type: "m")
        )
        XCTAssertEqual(String(result.characters), "just plain text")
    }

    func testDecodesEntities() {
        let result = DefinitionFormatter.render(entry("salt &amp; pepper"))
        XCTAssertTrue(String(result.characters).contains("salt & pepper"))
    }

    func testStripTagsRemovesMarkup() {
        let stripped = DefinitionFormatter.stripTags(
            "<i>n.</i> a <a href=\"x\">word</a>"
        )
        XCTAssertEqual(stripped, "n. a word")
    }

    func testRenderHTMLNeverEmptyForRealContent() {
        let result = DefinitionFormatter.renderHTML("<i>adj.</i> bright")
        XCTAssertFalse(result.characters.isEmpty)
    }

    // MARK: - Define target validation

    @MainActor
    func testDefineTargetTrimsAndCollapses() {
        XCTAssertEqual(
            ReaderViewModel.defineTarget(from: "  hello   world \n"),
            "hello world"
        )
    }

    @MainActor
    func testDefineTargetRejectsEmptySelection() {
        XCTAssertNil(ReaderViewModel.defineTarget(from: "   \n\t "))
        XCTAssertNil(ReaderViewModel.defineTarget(from: ""))
    }

    @MainActor
    func testDefineTargetKeepsSingleWord() {
        XCTAssertEqual(
            ReaderViewModel.defineTarget(from: "serendipity"),
            "serendipity"
        )
    }
}
