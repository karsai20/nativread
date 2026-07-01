import XCTest
import UIKit
@testable import NativRead

@MainActor
final class PDFImporterTests: XCTestCase {

    private var root: URL!

    override func setUp() async throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("pdf-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: root, withIntermediateDirectories: true
        )
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: root)
    }

    /// Writes a minimal multi-page PDF with title/author document info.
    private func makePDF(
        at url: URL, pages: Int, title: String?, author: String?
    ) throws {
        let format = UIGraphicsPDFRendererFormat()
        var info: [String: Any] = [:]
        if let title { info[kCGPDFContextTitle as String] = title }
        if let author { info[kCGPDFContextAuthor as String] = author }
        format.documentInfo = info
        let bounds = CGRect(x: 0, y: 0, width: 200, height: 300)
        let renderer = UIGraphicsPDFRenderer(bounds: bounds, format: format)
        try renderer.writePDF(to: url) { context in
            for index in 0..<pages {
                context.beginPage()
                ("Page \(index + 1)" as NSString).draw(
                    at: CGPoint(x: 20, y: 20), withAttributes: nil
                )
            }
        }
    }

    private func makeStore() -> LibraryStore {
        LibraryStore(rootDirectory: root.appendingPathComponent("store"))
    }

    func testImportPDFExtractsMetadataCoverAndPageWeights() throws {
        let pdfURL = root.appendingPathComponent("source.pdf")
        try makePDF(at: pdfURL, pages: 4, title: "PDF Title", author: "PDF Author")

        let store = makeStore()
        let book = try store.importBook(from: pdfURL)

        XCTAssertEqual(book.format, .pdf)
        XCTAssertEqual(book.title, "PDF Title")
        XCTAssertEqual(book.author, "PDF Author")
        XCTAssertEqual(book.spineWeights.count, 4)
        XCTAssertEqual(book.spineWeights, Array(repeating: 1.0, count: 4))
        XCTAssertNotNil(store.coverURL(for: book))
    }

    func testImportPDFFallsBackToFilenameTitle() throws {
        let pdfURL = root.appendingPathComponent("My Untitled Doc.pdf")
        try makePDF(at: pdfURL, pages: 1, title: nil, author: nil)

        let book = try makeStore().importBook(from: pdfURL)

        XCTAssertEqual(book.title, "My Untitled Doc")
        XCTAssertEqual(book.author, "")
        XCTAssertEqual(book.spineWeights.count, 1)
    }

    func testImportPDFPersistsAcrossInstances() throws {
        let pdfURL = root.appendingPathComponent("source.pdf")
        try makePDF(at: pdfURL, pages: 2, title: "Persisted", author: "A")
        let book = try makeStore().importBook(from: pdfURL)

        let reloaded = makeStore()

        XCTAssertEqual(reloaded.books.map(\.id), [book.id])
        XCTAssertEqual(reloaded.books.first?.format, .pdf)
    }

    func testImportUnreadablePDFThrowsAndLeavesNoStoredCopy() throws {
        // Bytes that aren't a valid PDF, but with a .pdf extension so the
        // store routes them through importPDF.
        let badURL = root.appendingPathComponent("broken.pdf")
        try Data("this is not a pdf".utf8).write(to: badURL)

        let store = makeStore()
        XCTAssertThrowsError(try store.importBook(from: badURL)) { error in
            guard case PDFImportError.unreadable = error else {
                return XCTFail("expected .unreadable, got \(error)")
            }
        }
        XCTAssertTrue(store.books.isEmpty)

        // Cleanup-on-failure must leave no orphan copy behind.
        let contents = try? FileManager.default.contentsOfDirectory(
            atPath: store.booksDirectory.path
        )
        XCTAssertEqual(contents ?? [], [])
    }
}
