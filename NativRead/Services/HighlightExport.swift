import Foundation

/// Renders a book's highlights into shareable plain-text formats.
/// Pure string work — no FileManager, no WebKit — so it is fully
/// unit-testable and free of side effects.
enum HighlightExport {

    /// Human-readable Markdown: a title header, optional author line,
    /// then highlights grouped under a heading per chapter (in the order
    /// chapters first appear in the highlights array). Each highlight is a
    /// blockquote with the creation date as a small caption.
    static func markdown(for book: Book) -> String {
        var lines: [String] = ["# \(book.title)"]
        if !book.author.isEmpty {
            lines.append("")
            lines.append("by \(book.author)")
        }

        for chapter in orderedChapters(of: book.highlights) {
            lines.append("")
            lines.append("## \(chapter)")
            for highlight in book.highlights where highlight.chapterTitle == chapter {
                lines.append("")
                lines.append(blockquote(highlight.text))
                if let note = highlight.trimmedNote {
                    lines.append("")
                    lines.append("*Note: \(note)*")
                }
                lines.append("")
                lines.append("*\(displayDateFormatter.string(from: highlight.createdAt))*")
            }
        }

        return lines.joined(separator: "\n") + "\n"
    }

    /// RFC-4180-style CSV. Header `Chapter,Highlight,Date,Note` followed by
    /// one row per highlight; dates are ISO-8601 and the note is empty when
    /// absent. Fields are quoted and escaped so commas, quotes, and newlines
    /// survive a round-trip to a spreadsheet.
    static func csv(for book: Book) -> String {
        var rows: [String] = [csvRow(["Chapter", "Highlight", "Date", "Note"])]
        for highlight in book.highlights {
            rows.append(csvRow([
                highlight.chapterTitle,
                highlight.text,
                isoDateFormatter.string(from: highlight.createdAt),
                highlight.trimmedNote ?? ""
            ]))
        }
        return rows.joined(separator: "\r\n") + "\r\n"
    }

    // MARK: - Markdown helpers

    /// Chapter titles in first-appearance order, without duplicates.
    private static func orderedChapters(of highlights: [Highlight]) -> [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for highlight in highlights where seen.insert(highlight.chapterTitle).inserted {
            ordered.append(highlight.chapterTitle)
        }
        return ordered
    }

    /// Prefixes every line of `text` with `> ` so multi-line highlights stay
    /// inside one Markdown blockquote.
    private static func blockquote(_ text: String) -> String {
        text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { "> \($0)" }
            .joined(separator: "\n")
    }

    private static let displayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    // MARK: - CSV helpers

    private static func csvRow(_ fields: [String]) -> String {
        fields.map(escapeCSVField).joined(separator: ",")
    }

    /// Wraps a field in double-quotes and doubles embedded quotes when it
    /// contains a comma, quote, CR, or LF — otherwise returns it untouched.
    private static func escapeCSVField(_ field: String) -> String {
        let needsQuoting = field.contains(where: { $0 == "," || $0 == "\"" || $0 == "\r" || $0 == "\n" })
        guard needsQuoting else { return field }
        let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    private static let isoDateFormatter = ISO8601DateFormatter()
}
