import SwiftUI
import UIKit

/// Dictionary lookup sheet for a selected word or short phrase. Uses Apple's
/// built-in Dictionary UI so readers get the same installed dictionaries and
/// Manage Dictionaries path available system-wide. iOS does not expose system
/// dictionary definition text to apps, so saving keeps the word and context.
struct DefineView: View {
    let word: String
    let palette: ReaderPalette
    /// The sentence the word was read in, for saving as context; nil when
    /// the reader could not capture it.
    var context: String? = nil
    /// Invoked when the reader taps Save; nil disables saving (e.g. previews).
    /// The definition is empty because Apple's Dictionary text is display-only.
    var onSave: ((_ definition: String, _ source: String) -> Void)? = nil
    /// Whether this word is already in the saved vocabulary, reflected on
    /// open so the action reads "Saved" rather than offering a duplicate.
    var isAlreadySaved: Bool = false

    @Environment(\.dismiss) private var dismiss

    /// Flips to true once the reader taps Save in this session.
    @State private var didSave = false
    @State private var showDictionaryManager = false

    var body: some View {
        NavigationStack {
            SystemDictionaryController(term: word)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(palette.background.ignoresSafeArea())
                .navigationTitle(word)
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
                    ToolbarItem(placement: .bottomBar) {
                        Button {
                            showDictionaryManager = true
                        } label: {
                            Label(
                                "Dictionaries",
                                systemImage: "character.book.closed"
                            )
                        }
                        .tint(palette.accent)
                    }
                }
        }
        .presentationDetents([.medium, .large])
        .accessibilityIdentifier("define.sheet")
        .sheet(isPresented: $showDictionaryManager) {
            NavigationStack {
                SystemDictionaryController(term: Self.dictionaryManagementTerm)
                    .navigationTitle("Dictionaries")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showDictionaryManager = false }
                                .tint(palette.accent)
                        }
                    }
            }
        }
    }

    // MARK: - Save

    /// "Save" -> "Saved": disabled once saved (this session or already in
    /// the list). Reduced-motion friendly - only the label and tint change,
    /// no implicit movement.
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
        .disabled(saved)
        .accessibilityIdentifier("define.save")
    }

    private func performSave() {
        guard let onSave, !didSave, !isAlreadySaved else { return }
        onSave("", "Apple Dictionary")
        didSave = true
    }

    /// No public iOS API opens Settings > General > Dictionary directly. A
    /// guaranteed-missing lookup surfaces Apple's own Manage Dictionaries path
    /// inside the reference-library controller without using private URLs.
    private static let dictionaryManagementTerm =
        "nativread_dictionary_settings_probe"
}

/// Thin SwiftUI bridge for `UIReferenceLibraryViewController`, the same system
/// dictionary surface that exposes the installed Apple dictionaries and its
/// Manage Dictionaries entry.
private struct SystemDictionaryController: UIViewControllerRepresentable {
    let term: String

    func makeUIViewController(
        context: Context
    ) -> UIReferenceLibraryViewController {
        UIReferenceLibraryViewController(term: term)
    }

    func updateUIViewController(
        _ uiViewController: UIReferenceLibraryViewController,
        context: Context
    ) {}
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

    /// The gloss to surface for a set of lookup results, with its dictionary.
    /// Results are bilingual-first, so the *first* dictionary with a usable
    /// plain-text entry wins — keeping the chosen language over a shorter
    /// English WordNet fallback. Within that dictionary the shortest entry is
    /// kept (flashcard-friendly). Shared by the Define save path and the
    /// live-resolved vocabulary list.
    static func preferredGloss(
        _ results: [DictionaryResult]
    ) -> (definition: String, source: String)? {
        for result in results {
            let plains = result.entries
                .map { plainText($0) }
                .filter { !$0.isEmpty }
            if let best = plains.min(by: { $0.count < $1.count }) {
                return (best, result.bookname)
            }
        }
        return nil
    }

    /// The entry's definition as collapsed plain text — HTML stripped for
    /// `type == "h"` entries, otherwise the raw text trimmed. The basis
    /// for a saved vocabulary gloss. Pure and `Sendable`-friendly.
    static func plainText(_ entry: DictionaryEntry) -> String {
        let raw = entry.type == "h"
            ? stripTags(entry.definition)
            : entry.definition
        let collapsed = raw
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return stripLeadingPartOfSpeech(from: collapsed)
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
                var text = decodeEntities(raw)
                if italic && isDictionaryPartOfSpeechLabel(text) { continue }
                if output.characters.isEmpty {
                    text = text.trimmingCharacters(in: .whitespacesAndNewlines)
                }
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

    private static func stripLeadingPartOfSpeech(from text: String) -> String {
        let parts = text.split(separator: " ")
        guard let first = parts.first,
              isDictionaryPartOfSpeechLabel(String(first)) else {
            return text
        }
        return parts.dropFirst().joined(separator: " ")
    }

    /// The EN→HU dictionary stores Hungarian part-of-speech labels as italic
    /// body text (`<i>fn</i> lámpás`). They are useful source metadata but read
    /// like broken words in the Define UI and saved vocabulary list.
    private static func isDictionaryPartOfSpeechLabel(_ text: String) -> Bool {
        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ":;,"))
            .lowercased()
        return [
            "fn", "ige", "mn", "hsz", "proper_noun", "phrase",
            "preposition", "prepositional_phrase", "prefix", "interjection"
        ].contains(normalized)
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
