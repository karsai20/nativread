import XCTest
@testable import NativRead

@MainActor
final class TextImporterTests: XCTestCase {

    private var root: URL!

    override func setUp() async throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("txt-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: root, withIntermediateDirectories: true
        )
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func makeStore() -> LibraryStore {
        LibraryStore(rootDirectory: root.appendingPathComponent("store"))
    }

    func testImportTextSynthesizesChapterAndTitle() throws {
        let txtURL = root.appendingPathComponent("note.txt")
        try "First Line Title\n\nSecond paragraph here."
            .write(to: txtURL, atomically: true, encoding: .utf8)

        let store = makeStore()
        let book = try store.importBook(from: txtURL)

        XCTAssertEqual(book.format, .txt)
        XCTAssertEqual(book.title, "First Line Title")
        XCTAssertEqual(book.spineWeights, [1.0])

        let chapter = store.extractedRoot(for: book)
            .appendingPathComponent("content.xhtml")
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: chapter.path)
        )
        let html = try String(contentsOf: chapter, encoding: .utf8)
        XCTAssertTrue(html.contains("<p>First Line Title</p>"))
        XCTAssertTrue(html.contains("Second paragraph here."))
    }

    func testParsedViewReturnsSingleSynthesizedSpine() throws {
        let txtURL = root.appendingPathComponent("note.txt")
        try "Hello world".write(to: txtURL, atomically: true, encoding: .utf8)
        let store = makeStore()
        let book = try store.importBook(from: txtURL)

        let parsed = try store.parsedEPUB(for: book)

        XCTAssertEqual(parsed.spineURLs.count, 1)
        XCTAssertEqual(parsed.toc.count, 1)
        XCTAssertEqual(parsed.title, "Hello world")
    }

    func testRenderEscapesHTMLSignificantCharacters() {
        let html = TextImporter.render("a < b & \"c\" > d", title: "T")
        XCTAssertTrue(html.contains("a &lt; b &amp; &quot;c&quot; &gt; d"))
        XCTAssertFalse(html.contains("<p>a < b"))
    }

    func testTitleFallsBackToFilenameWhenEmpty() throws {
        let txtURL = root.appendingPathComponent("Fallback Name.txt")
        try "   \n\n  ".write(to: txtURL, atomically: true, encoding: .utf8)

        let book = try makeStore().importBook(from: txtURL)

        XCTAssertEqual(book.title, "Fallback Name")
    }

    func testImportDecodesLatin1WhenNotUTF8() throws {
        // 0xE9 is 'é' in ISO Latin-1 but invalid as standalone UTF-8, so the
        // importer's latin-1 safety net must catch it instead of yielding "".
        let txtURL = root.appendingPathComponent("legacy.txt")
        var bytes: [UInt8] = Array("Caf".utf8)
        bytes.append(0xE9) // é in Latin-1
        try Data(bytes).write(to: txtURL)

        let store = makeStore()
        let book = try store.importBook(from: txtURL)

        let chapter = store.extractedRoot(for: book)
            .appendingPathComponent("content.xhtml")
        let html = try String(contentsOf: chapter, encoding: .utf8)
        XCTAssertTrue(html.contains("Café"))
    }

    func testRenderSplitsParagraphsOnCRLFBlankLine() {
        let html = TextImporter.render("Para one.\r\n\r\nPara two.", title: "T")
        XCTAssertTrue(html.contains("<p>Para one.</p>"))
        XCTAssertTrue(html.contains("<p>Para two.</p>"))
    }

    func testRenderCollapsesSoftNewlineToBreak() {
        let html = TextImporter.render("line one\nline two", title: "T")
        XCTAssertTrue(html.contains("line one<br/>line two"))
        // A single soft newline stays inside one paragraph.
        XCTAssertFalse(html.contains("<p>line two</p>"))
    }
}
