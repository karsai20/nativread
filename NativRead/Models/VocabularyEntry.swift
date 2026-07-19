import Foundation

/// A word the reader saved from the in-reader Define popup, kept in a
/// global list that spans every book. Carries optional definition text
/// for older saved entries and, when the reader could capture it, the
/// sentence the word was read in: the basis for context-rich flashcards
/// and Anki export.
struct VocabularyEntry: Codable, Equatable, Identifiable {
    let id: UUID
    /// The saved word or short phrase, as selected.
    let word: String
    /// A plain-text definition chosen at save time. Empty when the word
    /// was saved from Apple's system Dictionary, which does not expose
    /// definition text through a public API.
    let definition: String
    /// The enclosing sentence the word was read in, or nil when the
    /// reader could not capture surrounding text. Optional by design so
    /// a missed capture degrades gracefully rather than blocking a save.
    let contextSentence: String?
    /// The dictionary surface the word was saved from.
    let dictionarySource: String
    let createdAt: Date
    /// The reader's own annotation on this word. Optional so entries
    /// persisted before notes existed decode without a `note` key.
    var note: String?
    /// The book the word was saved from, when known.
    let bookID: UUID?
    /// The chapter the word was saved from, when known.
    let chapterTitle: String?

    init(
        id: UUID = UUID(),
        word: String,
        definition: String,
        contextSentence: String? = nil,
        dictionarySource: String,
        createdAt: Date = .now,
        note: String? = nil,
        bookID: UUID? = nil,
        chapterTitle: String? = nil
    ) {
        self.id = id
        self.word = word
        self.definition = definition
        self.contextSentence = contextSentence
        self.dictionarySource = dictionarySource
        self.createdAt = createdAt
        self.note = note
        self.bookID = bookID
        self.chapterTitle = chapterTitle
    }

    /// Tolerant decoding: vocabulary persisted before a field existed
    /// (or written by an older build) must keep loading without wiping
    /// the saved list. Only `id`, `word`, `definition`, `dictionarySource`
    /// and `createdAt` are required.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        word = try container.decode(String.self, forKey: .word)
        definition = try container.decode(String.self, forKey: .definition)
        contextSentence = try container.decodeIfPresent(
            String.self, forKey: .contextSentence)
        dictionarySource = try container.decode(
            String.self, forKey: .dictionarySource)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        bookID = try container.decodeIfPresent(UUID.self, forKey: .bookID)
        chapterTitle = try container.decodeIfPresent(
            String.self, forKey: .chapterTitle)
    }

    /// The dedup key: a word is the same regardless of case or which
    /// book it came from, so re-saving it from anywhere is a no-op.
    var dedupKey: String {
        word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// The note with surrounding whitespace stripped, or nil when absent
    /// or blank — so a blank note never exports or renders.
    var trimmedNote: String? {
        guard let note = note?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !note.isEmpty
        else { return nil }
        return note
    }

    /// The context sentence with surrounding whitespace stripped, or nil
    /// when absent or blank.
    var trimmedContext: String? {
        guard let context = contextSentence?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !context.isEmpty
        else { return nil }
        return context
    }

    /// Provenance recorded when a word is saved from Apple's system Dictionary,
    /// which does not expose definition text through a public API. Persisted in
    /// entries, so it must stay identical everywhere it is written.
    static let appleDictionarySource = "Apple Dictionary"
}
