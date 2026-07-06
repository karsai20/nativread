import XCTest
import ZIPFoundation
@testable import NativRead

/// End-to-end acceptance test: the bundled Alice AZW3 (pure KF8) must convert
/// to a readable EPUB and import through the existing library pipeline.
@MainActor
final class KF8ConverterTests: XCTestCase {

    private func fixtureURL() throws -> URL {
        let url = Bundle(for: Self.self)
            .url(forResource: "alice", withExtension: "azw3")
        return try XCTUnwrap(url, "alice.azw3 fixture missing from test bundle")
    }

    func testConvertsAliceAZW3ToReadableEPUB() throws {
        let source = try fixtureURL()
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("kf8-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: temp, withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: temp) }

        let epubURL = temp.appendingPathComponent("alice.epub")
        try KF8Converter.convertToEPUB(source: source, destination: epubURL)

        // The result must unzip and expose container.xml + OPF.
        let unpacked = temp.appendingPathComponent("unpacked")
        try FileManager.default.unzipItem(at: epubURL, to: unpacked)
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: unpacked.appendingPathComponent("META-INF/container.xml").path
        ))
        let opfURL = unpacked.appendingPathComponent("OEBPS/content.opf")
        let opf = try String(contentsOf: opfURL, encoding: .utf8)
        XCTAssertTrue(opf.contains("<spine"))

        // Multiple XHTML spine files with real prose.
        let oebps = unpacked.appendingPathComponent("OEBPS")
        let xhtmlFiles = try FileManager.default
            .contentsOfDirectory(atPath: oebps.path)
            .filter { $0.hasSuffix(".xhtml") }
        XCTAssertGreaterThan(xhtmlFiles.count, 1,
            "expected reassembly into multiple XHTML files")

        let combined = try xhtmlFiles
            .map { try String(
                contentsOf: oebps.appendingPathComponent($0), encoding: .utf8
            ) }
            .joined()
        for keyword in ["Alice", "Rabbit", "Wonderland"] {
            XCTAssertTrue(combined.contains(keyword),
                "converted text should contain \"\(keyword)\"")
        }
        // No unresolved Kindle-internal URIs should survive rewriting.
        XCTAssertFalse(combined.contains("kindle:"),
            "kindle: references must be rewritten")

        // The Tenniel illustrations must survive as image resources.
        let images = try FileManager.default
            .contentsOfDirectory(atPath: oebps.path)
            .filter { $0.hasSuffix(".png") || $0.hasSuffix(".jpg") }
        XCTAssertGreaterThan(images.count, 10,
            "expected the Tenniel illustrations to be extracted")
    }

    func testImportsThroughLibraryStore() throws {
        let source = try fixtureURL()
        let root = try EPUBFixtures.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = LibraryStore(rootDirectory: root)

        let book = try store.importBook(from: source)

        XCTAssertEqual(store.books.count, 1)
        XCTAssertEqual(book.format, .epub)
        XCTAssertGreaterThan(book.spineWeights.count, 1)
        XCTAssertNotNil(store.coverURL(for: book), "a cover should be extracted")
        XCTAssertTrue(book.title.localizedCaseInsensitiveContains("Alice"))
    }
}
