import Foundation
import PDFKit
import UIKit

enum PDFImportError: LocalizedError {
    case unreadable

    var errorDescription: String? {
        switch self {
        case .unreadable:
            return "The file could not be opened as a PDF."
        }
    }
}

/// Builds a `Book` from an already-copied PDF: title/author from the
/// document attributes (filename fallback), a cover rendered from page 0,
/// and one unit of `spineWeight` per page so the shared progress math
/// treats each page as a chapter.
enum PDFImporter {
    static func makeBook(
        id: UUID,
        storedURL: URL,
        originalName: String,
        coversDirectory: URL
    ) throws -> Book {
        guard let document = PDFDocument(url: storedURL) else {
            throw PDFImportError.unreadable
        }
        // PDFKit returns a non-nil but locked document for password-encrypted
        // files, and a zero-page document for some malformed ones; both would
        // otherwise land in the library as a blank, unopenable book.
        guard !document.isLocked, document.pageCount > 0 else {
            throw PDFImportError.unreadable
        }
        let pageCount = document.pageCount
        let attributes = document.documentAttributes ?? [:]

        let metaTitle = (attributes[PDFDocumentAttribute.titleAttribute]
            as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = (metaTitle?.isEmpty == false ? metaTitle : nil)
            ?? originalName
        let author = (attributes[PDFDocumentAttribute.authorAttribute]
            as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        var coverFileName: String?
        if let page = document.page(at: 0) {
            let thumbnail = page.thumbnail(
                of: CGSize(width: 320, height: 480), for: .cropBox
            )
            if let data = thumbnail.pngData() {
                let name = "\(id.uuidString).png"
                let url = coversDirectory.appendingPathComponent(name)
                try? data.write(to: url)
                if FileManager.default.fileExists(atPath: url.path) {
                    coverFileName = name
                }
            }
        }

        return Book(
            id: id,
            title: title,
            author: author,
            fileName: storedURL.lastPathComponent,
            coverFileName: coverFileName,
            format: .pdf,
            spineWeights: Array(repeating: 1.0, count: pageCount)
        )
    }
}
