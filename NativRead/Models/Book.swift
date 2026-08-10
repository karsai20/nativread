import Foundation

/// Reading position inside a book. `spineIndex` identifies the chapter,
/// `pageFraction` the horizontal page position inside it (0...1).
struct ReadingProgress: Codable, Equatable {
    var spineIndex: Int = 0
    var pageFraction: Double = 0
    /// Whole-book completion (0...1), weighted by chapter length.
    var bookFraction: Double = 0
}

struct Bookmark: Codable, Equatable, Identifiable {
    let id: UUID
    let spineIndex: Int
    let pageFraction: Double
    let chapterTitle: String
    let snippet: String
    let createdAt: Date

    init(
        id: UUID = UUID(),
        spineIndex: Int,
        pageFraction: Double,
        chapterTitle: String,
        snippet: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.spineIndex = spineIndex
        self.pageFraction = pageFraction
        self.chapterTitle = chapterTitle
        self.snippet = snippet
        self.createdAt = createdAt
    }
}

/// A saved highlight. Anchored by its exact text and which occurrence
/// of that text it is within the chapter — a locator that survives
/// relayout (font size, margins, flow mode) unlike pixel positions.
struct Highlight: Codable, Equatable, Identifiable {
    let id: UUID
    let spineIndex: Int
    let text: String
    /// Zero-based index among equal-text matches in the chapter.
    let occurrence: Int
    let chapterTitle: String
    let createdAt: Date
    /// The reader's own annotation on this passage. Optional so highlights
    /// persisted before notes existed decode without a `note` key.
    var note: String?

    init(
        id: UUID = UUID(),
        spineIndex: Int,
        text: String,
        occurrence: Int,
        chapterTitle: String,
        createdAt: Date = .now,
        note: String? = nil
    ) {
        self.id = id
        self.spineIndex = spineIndex
        self.text = text
        self.occurrence = occurrence
        self.chapterTitle = chapterTitle
        self.createdAt = createdAt
        self.note = note
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
}

/// The source format of a book. Drives which reader opens it: `.epub`
/// and `.txt` use the reflowable web engine, `.pdf` the fixed-layout
/// PDFKit reader.
enum BookFormat: String, Codable {
    case epub, pdf, txt
}

enum BookVariant: String, Codable, Equatable {
    case original
    case translationPreview
    case fullTranslation

    /// Legacy fallback for older call sites. Prefer `Book.variantBadgeText`, which
    /// includes the translated target language when known.
    var badgeText: String? {
        switch self {
        case .original:
            return nil
        case .translationPreview:
            return "AI · HU PREVIEW"
        case .fullTranslation:
            return "AI · HU"
        }
    }
}

/// A book in the library. The source file lives in Documents/Books,
/// the unpacked/synthesized content in Library/Extracted/<id>.
struct Book: Codable, Equatable, Identifiable {
    let id: UUID
    var title: String
    var author: String
    var fileName: String
    var coverFileName: String?
    var format: BookFormat
    var addedAt: Date
    var lastOpenedAt: Date?
    var progress: ReadingProgress
    var bookmarks: [Bookmark]
    var highlights: [Highlight]
    /// Relative byte weight of every spine item, used for whole-book percentage.
    var spineWeights: [Double]
    /// Non-original imports, such as a partial translated preview, must be visibly
    /// separate from the user's source book.
    var variant: BookVariant
    var sourceBookID: UUID?
    var translatedFraction: Double?
    /// Target language for AI-translated variants. `nil` for original books and
    /// for legacy translated imports from before multi-language metadata existed.
    var translatedLanguage: TranslationTargetLanguage?
    /// SHA256 of the stored source file at the moment its quote was taken.
    /// The quote is a pure function of those bytes, so an unchanged hash means
    /// the cached price is still the one the backend would return — and a
    /// changed hash invalidates it without asking anyone.
    var quotedSourceHash: String?
    /// StoreKit product the backend picked from the source length. Display
    /// only: what the reader is actually charged is decided server-side from
    /// its own inspection at purchase time, never from this.
    var quotedProductId: String?
    /// `<dc:language>` as the EPUB itself declares it, captured at import so
    /// the translation sheet never has to re-parse the OPF to name the source
    /// language. `nil` for TXT/PDF imports, for EPUBs that omit the element,
    /// and for books shelved before this was recorded — all of which fall back
    /// to text detection.
    var declaredLanguage: String?

    init(
        id: UUID = UUID(),
        title: String,
        author: String,
        fileName: String,
        coverFileName: String? = nil,
        format: BookFormat = .epub,
        addedAt: Date = .now,
        lastOpenedAt: Date? = nil,
        progress: ReadingProgress = ReadingProgress(),
        bookmarks: [Bookmark] = [],
        highlights: [Highlight] = [],
        spineWeights: [Double] = [],
        variant: BookVariant = .original,
        sourceBookID: UUID? = nil,
        translatedFraction: Double? = nil,
        translatedLanguage: TranslationTargetLanguage? = nil,
        quotedSourceHash: String? = nil,
        quotedProductId: String? = nil,
        declaredLanguage: String? = nil
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.fileName = fileName
        self.coverFileName = coverFileName
        self.format = format
        self.addedAt = addedAt
        self.lastOpenedAt = lastOpenedAt
        self.progress = progress
        self.bookmarks = bookmarks
        self.highlights = highlights
        self.spineWeights = spineWeights
        self.variant = variant
        self.sourceBookID = sourceBookID
        self.translatedFraction = translatedFraction
        self.translatedLanguage = translatedLanguage
        self.quotedSourceHash = quotedSourceHash
        self.quotedProductId = quotedProductId
        self.declaredLanguage = declaredLanguage
    }

    /// Tolerant decoding: libraries persisted before highlights existed
    /// must keep loading without resetting the shelf.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        author = try container.decode(String.self, forKey: .author)
        fileName = try container.decode(String.self, forKey: .fileName)
        coverFileName = try container.decodeIfPresent(
            String.self, forKey: .coverFileName)
        // Libraries persisted before multi-format support carry no `format`
        // key; they were all EPUBs, so default to `.epub`.
        format = try container.decodeIfPresent(
            BookFormat.self, forKey: .format) ?? .epub
        addedAt = try container.decode(Date.self, forKey: .addedAt)
        lastOpenedAt = try container.decodeIfPresent(
            Date.self, forKey: .lastOpenedAt)
        progress = try container.decode(
            ReadingProgress.self, forKey: .progress)
        bookmarks = try container.decodeIfPresent(
            [Bookmark].self, forKey: .bookmarks) ?? []
        highlights = try container.decodeIfPresent(
            [Highlight].self, forKey: .highlights) ?? []
        spineWeights = try container.decodeIfPresent(
            [Double].self, forKey: .spineWeights) ?? []
        variant = try container.decodeIfPresent(
            BookVariant.self, forKey: .variant) ?? .original
        sourceBookID = try container.decodeIfPresent(
            UUID.self, forKey: .sourceBookID)
        translatedFraction = try container.decodeIfPresent(
            Double.self, forKey: .translatedFraction)
        translatedLanguage = try container.decodeIfPresent(
            TranslationTargetLanguage.self, forKey: .translatedLanguage)
        quotedSourceHash = try container.decodeIfPresent(
            String.self, forKey: .quotedSourceHash)
        quotedProductId = try container.decodeIfPresent(
            String.self, forKey: .quotedProductId)
        declaredLanguage = try container.decodeIfPresent(
            String.self, forKey: .declaredLanguage)
    }

    var percentText: String {
        let percent = Int((progress.bookFraction * 100).rounded())
        return "\(percent)%"
    }

    var isTranslationPreview: Bool { variant == .translationPreview }
    var isTranslatedCopy: Bool { variant != .original }
    /// The visible EU AI Act transparency marker for translated output.
    var variantBadgeText: String? {
        guard variant != .original else { return nil }
        let code = translatedLanguage?.shortCode ?? "HU"
        switch variant {
        case .original:
            return nil
        case .translationPreview:
            return "AI · \(code) PREVIEW"
        case .fullTranslation:
            return "AI · \(code)"
        }
    }
    var canExportTranslatedEPUB: Bool {
        format == .epub && isTranslatedCopy
    }

    var isTranslatableSource: Bool {
        format == .epub && variant == .original
    }
    var isFinished: Bool { progress.bookFraction >= 0.995 }
    var isStarted: Bool { progress.bookFraction > 0.001 }

    /// Inverse of `bookFraction`: maps a whole-book fraction back to a
    /// chapter index and an in-chapter fraction (for the scrubber).
    static func position(
        forBookFraction fraction: Double,
        weights: [Double]
    ) -> (spineIndex: Int, pageFraction: Double) {
        guard !weights.isEmpty else { return (0, 0) }
        let total = weights.reduce(0, +)
        guard total > 0 else { return (0, 0) }
        let target = min(max(fraction, 0), 1) * total
        var cumulative = 0.0
        for (index, weight) in weights.enumerated() {
            if target <= cumulative + weight || index == weights.count - 1 {
                let inner = weight > 0 ? (target - cumulative) / weight : 0
                return (index, min(max(inner, 0), 1))
            }
            cumulative += weight
        }
        return (weights.count - 1, 1)
    }

    /// Whole-book fraction for a position, weighted by chapter size.
    static func bookFraction(
        spineIndex: Int,
        pageFraction: Double,
        weights: [Double]
    ) -> Double {
        guard !weights.isEmpty, spineIndex < weights.count else { return 0 }
        let total = weights.reduce(0, +)
        guard total > 0 else { return 0 }
        let before = weights.prefix(spineIndex).reduce(0, +)
        let inside = weights[spineIndex] * min(max(pageFraction, 0), 1)
        return min(max((before + inside) / total, 0), 1)
    }

    /// Whole-book page estimate scaled from the current chapter's
    /// measured density (its page count vs its spine weight), so the
    /// number tracks the live typography instead of a fixed chars-per-
    /// page heuristic. Falls back to the measured chapter alone when
    /// weights are missing or degenerate.
    static func estimatedBookPages(
        chapterPageCount: Int,
        spineIndex: Int,
        weights: [Double]
    ) -> Int {
        let total = weights.reduce(0, +)
        guard spineIndex < weights.count, weights[spineIndex] > 0,
              total > 0 else { return max(1, chapterPageCount) }
        let scaled = Double(chapterPageCount) * total / weights[spineIndex]
        return max(1, Int(scaled.rounded()))
    }
}
