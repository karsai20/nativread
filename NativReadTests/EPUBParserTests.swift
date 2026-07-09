import XCTest
@testable import NativRead

final class EPUBParserTests: XCTestCase {

    private var tempDirectory: URL!

    override func setUpWithError() throws {
        tempDirectory = try EPUBFixtures.makeTempDirectory()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    // MARK: - EPUB 3

    func testParsesEPUB3MetadataSpineAndCover() throws {
        try EPUBFixtures.writeEPUB3(
            to: tempDirectory, title: "Fixture Book",
            author: "Test Author", chapterCount: 3
        )

        let parsed = try EPUBParser.parse(extractedRoot: tempDirectory)

        XCTAssertEqual(parsed.title, "Fixture Book")
        XCTAssertEqual(parsed.author, "Test Author")
        XCTAssertEqual(parsed.spineURLs.count, 3)
        XCTAssertEqual(
            parsed.spineURLs.map(\.lastPathComponent),
            ["ch1.xhtml", "ch2.xhtml", "ch3.xhtml"]
        )
        XCTAssertEqual(
            parsed.coverImageURL?.lastPathComponent, "cover.png"
        )
        XCTAssertEqual(parsed.spineWeights.count, 3)
        XCTAssertTrue(parsed.spineWeights.allSatisfy { $0 > 0 })
    }

    func testParsesEPUB3NavTOC() throws {
        try EPUBFixtures.writeEPUB3(to: tempDirectory, chapterCount: 3)

        let parsed = try EPUBParser.parse(extractedRoot: tempDirectory)

        XCTAssertEqual(
            parsed.toc.map(\.title), ["Part 1", "Part 2", "Part 3"]
        )
        XCTAssertEqual(parsed.toc.map(\.spineIndex), [0, 1, 2])
    }

    // MARK: - EPUB 2

    func testParsesEPUB2WithNCXAndMetaCover() throws {
        try EPUBFixtures.writeEPUB2(to: tempDirectory)

        let parsed = try EPUBParser.parse(extractedRoot: tempDirectory)

        XCTAssertEqual(parsed.title, "Vintage Volume")
        XCTAssertEqual(parsed.author, "Old Hand")
        XCTAssertEqual(parsed.spineURLs.count, 2)
        XCTAssertEqual(parsed.coverImageURL?.lastPathComponent, "art.png")
        XCTAssertEqual(
            parsed.toc.map(\.title), ["Old Part 1", "Old Part 2"]
        )
        // The second NCX entry points at "old2.xhtml#frag" — the
        // fragment must not break spine matching.
        XCTAssertEqual(parsed.toc.map(\.spineIndex), [0, 1])
    }

    // MARK: - Failure modes

    func testMissingContainerThrows() {
        XCTAssertThrowsError(
            try EPUBParser.parse(extractedRoot: tempDirectory)
        ) { error in
            guard case EPUBError.missingContainer = error else {
                return XCTFail("unexpected error \(error)")
            }
        }
    }

    func testEmptySpineThrows() throws {
        try EPUBFixtures.writeEPUB3(to: tempDirectory, chapterCount: 1)
        // Remove the only chapter file: spine resolves to nothing.
        try FileManager.default.removeItem(
            at: tempDirectory.appendingPathComponent("OEBPS/ch1.xhtml")
        )

        XCTAssertThrowsError(
            try EPUBParser.parse(extractedRoot: tempDirectory)
        ) { error in
            guard case EPUBError.emptySpine = error else {
                return XCTFail("unexpected error \(error)")
            }
        }
    }

    // MARK: - Path helpers

    func testHrefJoiningResolvesRelativeSegments() {
        XCTAssertEqual(
            EPUBParser.join(base: "nav/toc.xhtml", relative: "ch1.xhtml"),
            "nav/ch1.xhtml"
        )
        XCTAssertEqual(
            EPUBParser.join(
                base: "nav/toc.xhtml", relative: "../text/ch1.xhtml"
            ),
            "text/ch1.xhtml"
        )
        XCTAssertEqual(
            EPUBParser.join(base: "toc.ncx", relative: "ch2.xhtml#frag"),
            "ch2.xhtml#frag"
        )
    }

    func testNormalizeStripsDotSlashAndDecodes() {
        XCTAssertEqual(
            EPUBParser.normalize(href: "./text/ch%201.xhtml"),
            "text/ch 1.xhtml"
        )
    }

    // MARK: - Script sanitizing

    func testStripScriptsRemovesPairedAndSelfClosingTags() {
        let html = """
        <html><head>\
        <script type="text/javascript">alert(1)</script>\
        <script src="evil.js"></script>\
        <SCRIPT>\nwindow.x = 2;\n</SCRIPT>\
        <script data-x="y"/>\
        </head><body><p>Keep me</p></body></html>
        """

        let cleaned = EPUBParser.stripScripts(from: html)

        XCTAssertFalse(cleaned.lowercased().contains("<script"))
        XCTAssertFalse(cleaned.contains("alert(1)"))
        XCTAssertFalse(cleaned.contains("window.x"))
        XCTAssertTrue(cleaned.contains("<p>Keep me</p>"))
    }

    func testStripScriptsLeavesScriptlessProseUntouched() {
        let html = "<body><p>No scripts here — just text.</p></body>"
        XCTAssertEqual(EPUBParser.stripScripts(from: html), html)
    }

    func testSanitizeScriptsRewritesSpineFilesInPlace() throws {
        let chapter = tempDirectory.appendingPathComponent("ch1.xhtml")
        try """
        <html><body><p>Hello</p>\
        <script>fetch("file:///etc/passwd")</script></body></html>
        """.write(to: chapter, atomically: true, encoding: .utf8)

        EPUBParser.sanitizeScripts(in: [chapter])

        let result = try String(contentsOf: chapter, encoding: .utf8)
        XCTAssertFalse(result.lowercased().contains("<script"))
        XCTAssertFalse(result.contains("file:///etc/passwd"))
        XCTAssertTrue(result.contains("<p>Hello</p>"))
    }

    func testSanitizeScriptsSkipsMissingFilesWithoutThrowing() {
        let missing = tempDirectory.appendingPathComponent("nope.xhtml")
        // Must not throw or crash on unreadable input.
        EPUBParser.sanitizeScripts(in: [missing])
    }

    func testSanitizeScriptsHandlesUTF16SpineFiles() throws {
        // A BOM'd UTF-16 chapter is valid EPUB content WKWebView renders;
        // it must be sanitized, not skipped as non-UTF-8.
        let chapter = tempDirectory.appendingPathComponent("utf16.xhtml")
        try """
        <html><body><p>Szia</p>\
        <script>fetch("file:///etc/passwd")</script></body></html>
        """.write(to: chapter, atomically: true, encoding: .utf16)

        EPUBParser.sanitizeScripts(in: [chapter])

        var encoding = String.Encoding.utf8
        let result = try String(contentsOf: chapter, usedEncoding: &encoding)
        XCTAssertFalse(result.lowercased().contains("<script"))
        XCTAssertTrue(result.contains("<p>Szia</p>"))
    }

    // MARK: - Network-supplied HTML hardening

    func testStripScriptsRemovesInlineEventHandlers() {
        let html = """
        <body>\
        <img src="c.png" onload="steal()">\
        <p onclick='alert(1)'>Tap</p>\
        <div onmouseover=go>Hover</div>\
        </body>
        """
        let cleaned = EPUBParser.stripScripts(from: html)
        XCTAssertFalse(cleaned.lowercased().contains("onload"))
        XCTAssertFalse(cleaned.lowercased().contains("onclick"))
        XCTAssertFalse(cleaned.lowercased().contains("onmouseover"))
        XCTAssertFalse(cleaned.contains("steal()"))
        XCTAssertFalse(cleaned.contains("alert(1)"))
        // Non-handler content survives.
        XCTAssertTrue(cleaned.contains("<p"))
        XCTAssertTrue(cleaned.contains("Tap"))
        XCTAssertTrue(cleaned.contains("src=\"c.png\""))
    }

    func testStripScriptsNeutralizesJavascriptURIs() {
        let html = """
        <a href="javascript:steal()">x</a>\
        <a href="JaVaScRiPt: alert(1)">y</a>\
        <img src='data:text/html,<b>z</b>'>
        """
        let cleaned = EPUBParser.stripScripts(from: html).lowercased()
        XCTAssertFalse(cleaned.contains("javascript:"))
        XCTAssertFalse(cleaned.contains("data:text/html"))
        XCTAssertFalse(cleaned.contains("steal()"))
        XCTAssertFalse(cleaned.contains("alert(1)"))
    }

    func testStripScriptsNeutralizesEntityEncodedJavascriptURIs() {
        let html = """
        <a href="java&#x73;cript:alert(1)">hex s</a>\
        <a href="javascript&#58;alert(1)">colon</a>\
        <a href="java&#115;cript:x">decimal s</a>\
        <a href="&#106;avascript:x">leading j</a>\
        <a href="chapter&#48;1.xhtml">chapter</a>
        """

        let cleaned = EPUBParser.stripScripts(from: html)

        XCTAssertFalse(cleaned.contains("href=\"java&#x73;cript:alert(1)\""))
        XCTAssertFalse(cleaned.contains("href=\"javascript&#58;alert(1)\""))
        XCTAssertFalse(cleaned.contains("href=\"java&#115;cript:x\""))
        XCTAssertFalse(cleaned.contains("href=\"&#106;avascript:x\""))
        XCTAssertTrue(cleaned.contains("href=\"chapter&#48;1.xhtml\""))
    }

    func testStripScriptsNeutralizesUnquotedAndFormActionURIs() {
        let html = """
        <body>\
        <a href=javascript:alert(1)>Unquoted</a>\
        <button formaction="javascript:steal()">Go</button>\
        <form action='javascript:steal()'><input/></form>\
        </body>
        """
        let cleaned = EPUBParser.stripScripts(from: html)
        XCTAssertFalse(cleaned.contains("alert(1)"))
        XCTAssertFalse(cleaned.contains("steal()"))
        XCTAssertTrue(cleaned.contains("Unquoted"))
        XCTAssertTrue(cleaned.contains("Go"))
    }

    func testStripScriptsRemovesIframeSrcdoc() {
        let html = """
        <body><iframe srcdoc="&lt;script&gt;steal()&lt;/script&gt;"></iframe>\
        <p>Prose</p></body>
        """
        let cleaned = EPUBParser.stripScripts(from: html)
        XCTAssertFalse(cleaned.lowercased().contains("srcdoc"))
        XCTAssertTrue(cleaned.contains("<p>Prose</p>"))
    }

    func testStripScriptsKeepsBenignAttributesAndProse() {
        // A normal link, an inline style, and prose that merely contains the
        // letters "onload"/"online" must all pass through unchanged.
        let html = "<a href=\"chapter2.xhtml\" style=\"color:red\">"
            + "The page onload felt slow; go online.</a>"
        XCTAssertEqual(EPUBParser.stripScripts(from: html), html)
    }

    // MARK: - Art 50 AI-marked EPUB (E2)

    /// The backend injects the EU AI Act machine-readable marker (IPTC
    /// DigitalSourceType meta + dc:description + colophon spine item) into
    /// every delivered EPUB. This mirrors that exact OPF shape and asserts
    /// the app still imports it — the regression gate for the T25 backend
    /// change. Spec: quire-translator lib/core/ai-marker.ts.
    func testParsesArt50AIMarkedEPUB() throws {
        try EPUBFixtures.writeEPUB3(
            to: tempDirectory, title: "Marked Book", chapterCount: 2
        )
        let oebps = tempDirectory.appendingPathComponent("OEBPS")
        let opfURL = oebps.appendingPathComponent("content.opf")
        var opf = try String(contentsOf: opfURL, encoding: .utf8)
        opf = opf.replacingOccurrences(
            of: "<package ",
            with: "<package prefix=\"iptc: "
                + "http://iptc.org/std/Iptc4xmpExt/2008-02-29/\" "
        )
        opf = opf.replacingOccurrences(
            of: "</metadata>",
            with: """
                <meta property="iptc:DigitalSourceType">http://cv.iptc.org/\
            newscodes/digitalsourcetype/trainedAlgorithmicMedia</meta>
                <dc:description id="nativbook-ai-marker">AI-generated \
            content: machine translation from English to Hungarian by \
            NativBook (EU AI Act Art 50).</dc:description>
              </metadata>
            """
        )
        opf = opf.replacingOccurrences(
            of: "</manifest>",
            with: "  <item id=\"nativbook-colophon\" "
                + "href=\"nativbook-colophon.xhtml\" "
                + "media-type=\"application/xhtml+xml\"/>\n  </manifest>"
        )
        opf = opf.replacingOccurrences(
            of: "</spine>",
            with: "  <itemref idref=\"nativbook-colophon\"/>\n  </spine>"
        )
        try opf.write(to: opfURL, atomically: true, encoding: .utf8)
        try EPUBFixtures.chapterXHTML(
            title: "Colophon", body: "AI translation by NativBook."
        ).write(
            to: oebps.appendingPathComponent("nativbook-colophon.xhtml"),
            atomically: true, encoding: .utf8
        )

        let parsed = try EPUBParser.parse(extractedRoot: tempDirectory)

        XCTAssertEqual(parsed.title, "Marked Book")
        XCTAssertEqual(parsed.spineURLs.count, 3)
        XCTAssertEqual(
            parsed.spineURLs.last?.lastPathComponent,
            "nativbook-colophon.xhtml"
        )
    }
}
