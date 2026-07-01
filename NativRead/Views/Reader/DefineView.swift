import SwiftUI

/// Dictionary lookup sheet for a selected word or short phrase. Renders the
/// bundled WordNet (HTML) definitions as themed `AttributedString`s, with
/// loading and empty states. Presented from the reader's selection menu.
struct DefineView: View {
    let word: String
    let palette: ReaderPalette
    /// The sentence the word was read in, for saving as context; nil when
    /// the reader could not capture it.
    var context: String? = nil
    /// Invoked with the chosen plain-text definition and its dictionary
    /// when the reader taps Save; nil disables saving (e.g. previews).
    var onSave: ((_ definition: String, _ source: String) -> Void)? = nil
    /// Whether this word is already in the saved vocabulary, reflected on
    /// open so the action reads "Saved" rather than offering a duplicate.
    var isAlreadySaved: Bool = false

    @Environment(DictionaryProvider.self) private var provider
    @Environment(\.dismiss) private var dismiss

    /// nil while the lookup is in flight, then the (possibly empty) results.
    @State private var results: [DictionaryResult]?

    /// Flips to true once the reader taps Save in this session.
    @State private var didSave = false

    var body: some View {
        NavigationStack {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(palette.background.ignoresSafeArea())
                .navigationTitle("Define")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    if onSave != nil {
                        ToolbarItem(placement: .cancellationAction) {
                            saveButton
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                            .tint(palette.accent)
                    }
                }
        }
        .presentationDetents([.medium, .large])
        .accessibilityIdentifier("define.sheet")
        .task(id: word) { await runLookup() }
    }

    // MARK: - States

    @ViewBuilder
    private var content: some View {
        if !provider.isReady {
            preparingState
        } else if let results, results.isEmpty {
            emptyState
        } else if let results {
            resultsScroll(results)
        } else {
            // Dictionary is ready but the lookup hasn't returned yet.
            preparingState
        }
    }

    private var preparingState: some View {
        VStack(spacing: Spacing.md) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(palette.accent)
            Text("Preparing dictionary…")
                .font(Typography.body(14))
                .foregroundStyle(palette.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Preparing dictionary")
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.xs) {
            Image(systemName: "character.book.closed")
                .font(.system(size: 30))
                .foregroundStyle(palette.secondaryText)
            wordTitle
            Text("No definition found")
                .font(Typography.meta())
                .foregroundStyle(palette.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Spacing.xl)
        .accessibilityIdentifier("define.empty")
    }

    private func resultsScroll(_ results: [DictionaryResult]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                wordTitle
                    .padding(.bottom, Spacing.xxs)

                ForEach(Array(results.enumerated()), id: \.offset) { _, result in
                    resultBlock(result)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md + 2)
        }
        .accessibilityIdentifier("define.result")
    }

    private var wordTitle: some View {
        // Display role: Cormorant Garamond at 28pt anchors the definition sheet
        // with the same grand editorial presence used on covers and pull-quotes.
        Text(word)
            .font(Typography.display(28))
            .foregroundStyle(palette.text)
            .accessibilityAddTraits(.isHeader)
    }

    // MARK: - Save

    /// "Save" → "Saved": disabled once saved (this session or already in
    /// the list) or while there's nothing to save. Reduced-motion friendly
    /// — only the label and tint change, no implicit movement.
    private var saveButton: some View {
        let saved = didSave || isAlreadySaved
        return Button {
            performSave()
        } label: {
            Label(saved ? "Saved" : "Save",
                  systemImage: saved ? "checkmark" : "plus")
                .font(Typography.body(15))
        }
        .tint(palette.accent)
        .disabled(saved || saveDefinition == nil)
        .accessibilityIdentifier("define.save")
    }

    private func performSave() {
        guard let onSave, let definition = saveDefinition,
              !didSave, !isAlreadySaved else { return }
        onSave(definition, saveSource ?? "")
        didSave = true
    }

    /// The shortest plain-text definition across all results — the most
    /// flashcard-friendly gloss. HTML entries are stripped to plain text.
    private var saveDefinition: String? {
        guard let results else { return nil }
        let plains = results
            .flatMap(\.entries)
            .map { DefinitionFormatter.plainText($0) }
            .filter { !$0.isEmpty }
        return plains.min(by: { $0.count < $1.count })
    }

    /// The dictionary name of the first result, used as the saved source.
    private var saveSource: String? {
        results?.first?.bookname
    }

    private func resultBlock(_ result: DictionaryResult) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            // Dictionary source name as an eyebrow — tracked uppercase,
            // consistent with how chapter labels appear in search results.
            Text(result.bookname)
                .font(Typography.eyebrow)
                .tracking(Typography.eyebrowTracking)
                .textCase(.uppercase)
                .foregroundStyle(palette.accent)

            ForEach(Array(result.entries.enumerated()), id: \.offset) { _, entry in
                Text(DefinitionFormatter.attributed(entry, palette: palette))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Lookup

    private func runLookup() async {
        guard provider.isReady else {
            results = nil
            return
        }
        // The lookup itself is fast (in-memory index) but kept off the
        // initial layout pass so the sheet animates in cleanly.
        let found = provider.lookup(word)
        results = found
    }
}

/// Converts a `DictionaryEntry` into a palette-themed `AttributedString`.
/// WordNet definitions are small HTML fragments (`<i>n.</i>`, `<br>`,
/// `<small>Hypernyms:</small>`, `<a href="word">word</a>`); plain-text
/// entries pass through unchanged. Kept pure and `Sendable`-friendly so it
/// is directly unit-testable.
enum DefinitionFormatter {

    static func attributed(
        _ entry: DictionaryEntry, palette: ReaderPalette
    ) -> AttributedString {
        var result = render(entry)
        // Theme the whole fragment with the reader's body colour so it
        // reads as part of the sheet rather than as system body text.
        result.foregroundColor = palette.text
        // Body role: Crimson Pro at 16pt matches the reader's default feel.
        result.font = Typography.body(16)
        return result
    }

    /// The entry's definition as collapsed plain text — HTML stripped for
    /// `type == "h"` entries, otherwise the raw text trimmed. The basis
    /// for a saved vocabulary gloss. Pure and `Sendable`-friendly.
    static func plainText(_ entry: DictionaryEntry) -> String {
        let raw = entry.type == "h"
            ? stripTags(entry.definition)
            : entry.definition
        return raw
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// Renders the entry's definition to an `AttributedString`, parsing
    /// the lightweight HTML subset WordNet uses. Falls back to the raw
    /// text (as plain) if parsing somehow yields nothing.
    static func render(_ entry: DictionaryEntry) -> AttributedString {
        guard entry.type == "h" else {
            return AttributedString(entry.definition)
        }
        let parsed = renderHTML(entry.definition)
        return parsed.characters.isEmpty
            ? AttributedString(stripTags(entry.definition))
            : parsed
    }

    /// A tiny, dependency-free HTML→AttributedString pass for the tag set
    /// WordNet actually emits. Unknown tags are dropped, their text kept.
    /// Runs synchronously and is safe off the main thread.
    static func renderHTML(_ html: String) -> AttributedString {
        var output = AttributedString()
        var italic = false
        var small = false

        // Split on tags while keeping the tag tokens.
        let tokens = tokenize(html)
        for token in tokens {
            switch token {
            case .text(let raw):
                let text = decodeEntities(raw)
                guard !text.isEmpty else { continue }
                var run = AttributedString(text)
                if italic { run.inlinePresentationIntent = .emphasized }
                if small {
                    run.font = .system(size: 13, weight: .semibold)
                }
                output.append(run)
            case .tag(let name):
                switch name {
                case "br", "br/", "br /":
                    output.append(AttributedString("\n"))
                case "i", "em":
                    italic = true
                case "/i", "/em":
                    italic = false
                case "small":
                    small = true
                    output.append(AttributedString("\n"))
                case "/small":
                    small = false
                default:
                    break // <a>, </a>, <b>, etc. — keep their text only.
                }
            }
        }
        return output
    }

    // MARK: - Tokenizing

    private enum Token {
        case text(String)
        case tag(String) // lowercased tag body without angle brackets
    }

    private static func tokenize(_ html: String) -> [Token] {
        var tokens: [Token] = []
        var buffer = ""
        var insideTag = false
        var tagBuffer = ""

        for character in html {
            if character == "<" {
                if !buffer.isEmpty {
                    tokens.append(.text(buffer))
                    buffer = ""
                }
                insideTag = true
                tagBuffer = ""
            } else if character == ">" && insideTag {
                insideTag = false
                let name = tagName(from: tagBuffer)
                tokens.append(.tag(name))
            } else if insideTag {
                tagBuffer.append(character)
            } else {
                buffer.append(character)
            }
        }
        if !buffer.isEmpty { tokens.append(.text(buffer)) }
        return tokens
    }

    /// Reduces a raw tag body (e.g. `a href="word"`) to its name, keeping
    /// a leading slash for closing tags (`/a`). Lowercased.
    private static func tagName(from body: String) -> String {
        let trimmed = body.trimmingCharacters(in: .whitespaces)
        guard let first = trimmed.first else { return "" }
        if first == "/" {
            let rest = trimmed.dropFirst()
                .prefix { !$0.isWhitespace }
            return "/" + rest.lowercased()
        }
        return trimmed.prefix { !$0.isWhitespace && $0 != "/" }
            .lowercased()
    }

    /// Strips all tags, leaving decoded text — the plain-text fallback.
    static func stripTags(_ html: String) -> String {
        var output = ""
        var insideTag = false
        for character in html {
            if character == "<" { insideTag = true }
            else if character == ">" { insideTag = false }
            else if !insideTag { output.append(character) }
        }
        return decodeEntities(output)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Decodes the handful of named/numeric entities WordNet uses.
    private static func decodeEntities(_ text: String) -> String {
        let named = text
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&nbsp;", with: " ")
        // Numeric character references: decimal (&#39;) and hex (&#x27;) — the
        // EN→HU dictionary emits the hex form, which named-only decoding misses.
        let numeric = decodeNumericEntities(named)
        // Decode &amp; last so an escaped "&amp;#x27;" round-trips literally.
        return numeric.replacingOccurrences(of: "&amp;", with: "&")
    }

    /// Decodes decimal (`&#39;`) and hexadecimal (`&#x27;` / `&#X27;`) numeric
    /// character references to their Unicode characters. Malformed or
    /// out-of-range references are left untouched.
    private static func decodeNumericEntities(_ text: String) -> String {
        guard text.contains("&#"),
              let regex = try? NSRegularExpression(
                  pattern: "&#([xX])?([0-9A-Fa-f]+);"
              ) else { return text }
        let ns = text as NSString
        var output = ""
        var cursor = 0
        for match in regex.matches(
            in: text, range: NSRange(location: 0, length: ns.length)
        ) {
            let full = match.range
            output += ns.substring(
                with: NSRange(location: cursor, length: full.location - cursor)
            )
            let isHex = match.range(at: 1).location != NSNotFound
            let digits = ns.substring(with: match.range(at: 2))
            if let code = UInt32(digits, radix: isHex ? 16 : 10),
               let scalar = Unicode.Scalar(code) {
                output.append(Character(scalar))
            } else {
                output += ns.substring(with: full)
            }
            cursor = full.location + full.length
        }
        output += ns.substring(
            with: NSRange(location: cursor, length: ns.length - cursor)
        )
        return output
    }
}
