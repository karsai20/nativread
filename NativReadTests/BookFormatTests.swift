import XCTest
@testable import NativRead

final class BookFormatTests: XCTestCase {

    /// A library persisted before multi-format support carries no `format`
    /// key; it must decode as `.epub` so the existing shelf keeps loading.
    func testLegacyBookWithoutFormatDecodesAsEpub() throws {
        let json = """
        {
          "id": "\(UUID().uuidString)",
          "title": "Legacy",
          "author": "Anon",
          "fileName": "legacy.epub",
          "addedAt": 0,
          "progress": {
            "spineIndex": 0, "pageFraction": 0, "bookFraction": 0
          },
          "bookmarks": [],
          "highlights": [],
          "spineWeights": []
        }
        """
        let book = try JSONDecoder().decode(
            Book.self, from: Data(json.utf8)
        )
        XCTAssertEqual(book.format, .epub)
    }

    func testFormatRoundTrips() throws {
        for format in [BookFormat.epub, .pdf, .txt] {
            let book = Book(
                title: "T", author: "A", fileName: "f", format: format
            )
            let data = try JSONEncoder().encode(book)
            let decoded = try JSONDecoder().decode(Book.self, from: data)
            XCTAssertEqual(decoded.format, format)
        }
    }

    func testDefaultFormatIsEpub() {
        let book = Book(title: "T", author: "A", fileName: "f")
        XCTAssertEqual(book.format, .epub)
    }
}
