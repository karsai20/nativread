import Foundation

/// Renders the saved vocabulary into shareable plain-text formats.
/// Pure string work — no FileManager, no WebKit — so it is fully
/// unit-testable and free of side effects. The CSV is Anki-import-ready;
/// the Markdown is a human-readable study sheet.
enum VocabularyExport {

    /// RFC-4180-style CSV. Header `Word,Context,Definition,Source,Note,Date`
    /// followed by one row per entry; dates are ISO-8601 and absent fields
    /// are empty. When `cloze` is true the Context column wraps the target
    /// word as `{{c1::word}}` so Anki's Cloze note type makes a card with
    /// the word blanked out — the standard read-in-context workflow.
    static func csv(for entries: [VocabularyEntry], cloze: Bool) -> String {
        var rows: [String] = [csvRow([
            "Word", "Context", "Definition", "Source", "Note", "Date"
        ])]
        for entry in entries {
            let context = cloze
                ? clozeContext(for: entry)
                : (entry.contextSentence ?? "")
            rows.append(csvRow([
                entry.word,
                context,
                entry.definition,
                entry.dictionarySource,
                entry.trimmedNote ?? "",
                isoDateFormatter.string(from: entry.createdAt)
            ]))
        }
        return rows.joined(separator: "\r\n") + "\r\n"
    }

    /// Human-readable Markdown study sheet: a title header then one block
    /// per saved word — the word as a heading, the context as an italic
    /// blockquote, the definition, an optional note, and the save date.
    static func markdown(for entries: [VocabularyEntry]) -> String {
        var lines: [String] = ["# My Vocabulary"]

        for entry in entries {
            lines.append("")
            lines.append("## \(entry.word)")
            if let context = entry.trimmedContext {
                lines.append("")
                lines.append("> *\(context)*")
            }
            if !entry.definition.isEmpty {
                lines.append("")
                lines.append(entry.definition)
            }
            if let note = entry.trimmedNote {
                lines.append("")
                lines.append("*Note: \(note)*")
            }
            lines.append("")
            lines.append(
                "*\(entry.dictionarySource) · "
                + "\(displayDateFormatter.string(from: entry.createdAt))*"
            )
        }

        return lines.joined(separator: "\n") + "\n"
    }

    // MARK: - Cloze

    /// The context sentence with the first case-insensitive occurrence of
    /// the target word wrapped as `{{c1::word}}` (the original casing is
    /// kept inside the cloze). Falls back to `{{c1::word}}` alone when
    /// there is no context, or no match within it — so every cloze row
    /// still yields a usable Anki card.
    static func clozeContext(for entry: VocabularyEntry) -> String {
        let word = entry.word.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard let context = entry.trimmedContext, !word.isEmpty else {
            return "{{c1::\(word)}}"
        }
        guard let range = context.range(
            of: word, options: [.caseInsensitive]
        ) else {
            return "{{c1::\(word)}}"
        }
        let matched = String(context[range])
        return context.replacingCharacters(
            in: range, with: "{{c1::\(matched)}}"
        )
    }

    // MARK: - Helpers

    private static func csvRow(_ fields: [String]) -> String {
        fields.map(escapeCSVField).joined(separator: ",")
    }

    /// Wraps a field in double-quotes and doubles embedded quotes when it
    /// contains a comma, quote, CR, or LF — otherwise returns it untouched.
    private static func escapeCSVField(_ field: String) -> String {
        let needsQuoting = field.contains(
            where: { $0 == "," || $0 == "\"" || $0 == "\r" || $0 == "\n" }
        )
        guard needsQuoting else { return field }
        let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    private static let isoDateFormatter = ISO8601DateFormatter()

    private static let displayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}
