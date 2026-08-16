import CryptoKit
import XCTest
import ZIPFoundation
@testable import NativRead

/// The on-device translation quote must equal the backend's to the character,
/// or a reader is quoted one price and charged another.
///
/// `quote-golden.json` was produced by the server itself
/// (`scripts/quote-golden.ts` in nativread-translator) running the real
/// `countSourceCharacters` over these books. If a book here stops matching,
/// the port drifted — fix the port, never the fixture.
final class QuoteGoldenTests: XCTestCase {

    private struct Golden: Decodable {
        let quoteVersion: String
        let entries: [Entry]

        struct Entry: Decodable {
            let file: String
            let sha256: String
            let spineItems: Int
            let sourceCharacters: Int
            let requiredCredits: Int
            let quoteVersion: String
        }
    }

    func testQuoteMatchesServerGoldenForEveryBook() throws {
        let golden = try loadGolden()
        XCTAssertFalse(golden.entries.isEmpty, "quote-golden.json has no entries")

        for entry in golden.entries {
            let bookURL = try XCTUnwrap(
                bundledEPUB(named: entry.file),
                "\(entry.file): fixture EPUB missing from the app bundle"
            )
            let bytes = try Data(contentsOf: bookURL)
            XCTAssertEqual(
                sha256(of: bytes), entry.sha256,
                "\(entry.file): the fixture book's bytes changed, so its golden"
                    + " numbers no longer describe it — regenerate the fixture"
            )

            let parsed = try parseUnzipped(bookURL)
            XCTAssertEqual(
                parsed.spineURLs.count, entry.spineItems,
                "\(entry.file): spine item count differs from the server's"
            )

            let quote = try SourceCharacterCounter.quote(for: parsed)
            XCTAssertEqual(
                quote.sourceCharacters, entry.sourceCharacters,
                "\(entry.file): source character count differs from the server's"
            )
            XCTAssertEqual(
                quote.requiredCredits, entry.requiredCredits,
                "\(entry.file): required credits differ from the server's"
            )
            XCTAssertEqual(
                TranslationQuote.version, entry.quoteVersion,
                "\(entry.file): quote version differs from the server's"
            )
        }
    }

    /// The fixture books barely use entities, `<br>`, comments or exotic
    /// whitespace, so the rules those depend on are pinned separately. Every
    /// expected number below was produced by running the server's
    /// `countSourceCharacters` over the same snippet.
    func testCountingSemanticsMatchTheServer() {
        let cases: [(name: String, xhtml: String, expected: Int)] = [
            ("entities decode before counting",
             "<body><p>Tom &amp; Jerry&nbsp;&#8217;s &mdash; &#x27;end&#x27;</p></body>", 22),
            ("U+FEFF is whitespace, U+200B is not",
             "<body><p>a\u{FEFF}b\u{200B}c</p></body>", 5),
            ("<br> reads as a newline", "<body><p>one<br/>two</p></body>", 7),
            ("comments are not counted",
             "<body><p>a<!-- a very long hidden comment -->b</p></body>", 2),
            ("script bodies are counted",
             "<body><p>a<script>var x = 1;</script>b</p></body>", 12),
            ("only leaf blocks count, once",
             "<body><blockquote><p>inner</p></blockquote><div><h2>Head</h2></div></body>", 9),
            ("blank blocks contribute nothing, not even a space",
             "<body><p>   </p><p></p><p>x</p></body>", 1),
            ("text is normalized to NFC", "<body><p>e\u{301}</p></body>", 1),
            ("a '>' inside an attribute value is not a tag end",
             "<body><p title=\"a>b\">x</p></body>", 1),
            ("a document without <body> still counts", "<p>loose</p>", 5),
        ]

        for testCase in cases {
            XCTAssertEqual(
                SourceCharacterCounter.sourceCharacters(inXHTML: testCase.xhtml),
                testCase.expected,
                testCase.name
            )
        }
    }

    // MARK: - Helpers

    private func loadGolden() throws -> Golden {
        let url = try XCTUnwrap(
            Bundle(for: Self.self).url(forResource: "quote-golden", withExtension: "json"),
            "quote-golden.json missing from the test bundle"
        )
        return try JSONDecoder().decode(Golden.self, from: Data(contentsOf: url))
    }

    /// The fixture books ship as app-target resources, and the test bundle is
    /// hosted by the app, so `Bundle.main` is where they live at run time.
    private func bundledEPUB(named file: String) -> URL? {
        Bundle.main.url(
            forResource: (file as NSString).deletingPathExtension, withExtension: "epub"
        )
    }

    private func parseUnzipped(_ epubURL: URL) throws -> ParsedEPUB {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("quote-golden-\(UUID().uuidString)")
        try FileManager.default.unzipItem(at: epubURL, to: root)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return try EPUBParser.parse(extractedRoot: root)
    }

    private func sha256(of data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
