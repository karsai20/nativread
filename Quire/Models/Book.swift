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

/// A book in the library. The EPUB itself lives in Documents/Books,
/// the unpacked content in Library/Extracted/<id>.
struct Book: Codable, Equatable, Identifiable {
    let id: UUID
    var title: String
    var author: String
    var fileName: String
    var coverFileName: String?
    var addedAt: Date
    var lastOpenedAt: Date?
    var progress: ReadingProgress
    var bookmarks: [Bookmark]
    /// Relative byte weight of every spine item, used for whole-book percentage.
    var spineWeights: [Double]

    init(
        id: UUID = UUID(),
        title: String,
        author: String,
        fileName: String,
        coverFileName: String? = nil,
        addedAt: Date = .now,
        lastOpenedAt: Date? = nil,
        progress: ReadingProgress = ReadingProgress(),
        bookmarks: [Bookmark] = [],
        spineWeights: [Double] = []
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.fileName = fileName
        self.coverFileName = coverFileName
        self.addedAt = addedAt
        self.lastOpenedAt = lastOpenedAt
        self.progress = progress
        self.bookmarks = bookmarks
        self.spineWeights = spineWeights
    }

    var percentText: String {
        let percent = Int((progress.bookFraction * 100).rounded())
        return "\(percent)%"
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
}
