import Foundation

/// Turns a plain-text file into a single synthesized XHTML "chapter" so it
/// can be read by the same reflowable web engine the EPUB reader uses —
/// themes, fonts, search and the native iOS text-selection menu come for free.
enum TextImporter {
    /// The synthesized chapter file written into the book's extracted dir.
    static let chapterFileName = "content.xhtml"

    /// Reads the copied text file, synthesizes the chapter HTML into
    /// `extractedRoot`, and returns the `Book`. Title is the first
    /// non-empty line; falls back to the original filename.
    static func makeBook(
        id: UUID,
        storedURL: URL,
        extractedRoot: URL,
        originalName: String
    ) throws -> Book {
        let data = try Data(contentsOf: storedURL)
        // UTF-8 is the overwhelming common case; latin-1 never fails to
        // decode, so it is the safety net for legacy encodings.
        let raw = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1)
            ?? ""

        let title = raw
            .split(whereSeparator: \.isNewline)
            .first { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            ?? originalName

        try FileManager.default.createDirectory(
            at: extractedRoot, withIntermediateDirectories: true
        )
        try render(raw, title: title).write(
            to: extractedRoot.appendingPathComponent(chapterFileName),
            atomically: true, encoding: .utf8
        )

        return Book(
            id: id,
            title: title,
            author: "",
            fileName: storedURL.lastPathComponent,
            coverFileName: nil,
            format: .txt,
            spineWeights: [1.0]
        )
    }

    /// A `ParsedEPUB` view over the synthesized chapter so the reader's
    /// EPUB pipeline opens a TXT unchanged.
    static func parsed(extractedRoot: URL, title: String) -> ParsedEPUB {
        let url = extractedRoot.appendingPathComponent(chapterFileName)
        return ParsedEPUB(
            title: title,
            author: "",
            spineURLs: [url],
            spineHrefs: [chapterFileName],
            coverImageURL: nil,
            toc: [TOCEntry(
                title: title, href: chapterFileName, spineIndex: 0, depth: 0
            )],
            spineWeights: [1.0],
            // A plain .txt import declares nothing; detection has to guess.
            declaredLanguage: nil
        )
    }

    /// Wraps the raw text in a minimal XHTML document, splitting on blank
    /// lines into paragraphs and HTML-escaping every run.
    static func render(_ raw: String, title: String) -> String {
        let paragraphs = raw
            // A blank line (optionally whitespace) separates paragraphs.
            .components(separatedBy: "\n\n")
            .flatMap { $0.components(separatedBy: "\r\n\r\n") }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { "<p>\(escape($0))</p>" }
            .joined(separator: "\n")

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE html>
        <html xmlns="http://www.w3.org/1999/xhtml">
        <head><meta charset="utf-8"/><title>\(escape(title))</title></head>
        <body>
        \(paragraphs)
        </body>
        </html>
        """
    }

    /// Escapes the five XML-significant characters and collapses single
    /// newlines inside a paragraph into `<br/>` so soft line breaks survive.
    private static func escape(_ text: String) -> String {
        let escaped = text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
        return escaped
            .replacingOccurrences(of: "\r\n", with: "<br/>")
            .replacingOccurrences(of: "\n", with: "<br/>")
    }
}
