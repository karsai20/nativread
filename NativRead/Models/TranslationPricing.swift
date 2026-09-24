import Foundation

/// The backend's price table: which App Store product a book of a given length
/// is sold as. Served by `GET /api/pricing`.
///
/// The app keeps this rather than baking the tiers in, so moving a price
/// boundary is a Worker deploy instead of an App Store release. It is only ever
/// used to *show* a price: the server re-derives the tier from its own count at
/// purchase time and refuses a transaction for the wrong product.
struct TranslationPricing: Codable, Equatable, Sendable {

    struct Tier: Codable, Equatable, Sendable {
        let tier: Int
        let maxSourceCharacters: Int
        let productId: String
    }

    /// A language pair the backend will start a translation on right now.
    struct LanguagePair: Codable, Equatable, Sendable {
        let source: String
        let target: String
        /// False while the pair is only open for testing (shown as Beta).
        let validated: Bool
    }

    /// The counting rules the table was published for. When this differs from
    /// `TranslationQuote.version` the on-device counter is a different counter
    /// from the server's, and nothing it produces may be priced.
    let quoteVersion: String
    let charactersPerCredit: Int
    let tiers: [Tier]
    /// Absent from tables served before the backend advertised its pairs.
    var languagePairs: [LanguagePair]? = nil

    /// Whether this app's port of the character counter still matches the
    /// server's rules.
    var matchesLocalCounter: Bool {
        quoteVersion == TranslationQuote.version
    }

    /// Every product the table sells, cheapest first — what the sheet shows as
    /// the price bands before any particular book is priced.
    var productIDs: [String] {
        tiers.sorted { $0.maxSourceCharacters < $1.maxSourceCharacters }
            .map(\.productId)
    }

    /// The tier a book of this length falls into, or `nil` when it is longer
    /// than the top tier covers — the same rule as the server's `bookTierFor`,
    /// which is why the table is taken from the server rather than guessed.
    func tier(forSourceCharacters characters: Int) -> Tier? {
        tiers
            .sorted { $0.maxSourceCharacters < $1.maxSourceCharacters }
            .first { characters <= $0.maxSourceCharacters }
    }

    /// True when the book is longer than anything the backend sells, so the
    /// reader can be told now instead of after sending a large file.
    func exceedsLongestTier(sourceCharacters characters: Int) -> Bool {
        guard let longest = tiers.map(\.maxSourceCharacters).max() else {
            return false
        }
        return characters > longest
    }

    /// Targets on offer for a book in `source` (`nil` until detected), in
    /// the picker's order. Without an advertised list, only the languages
    /// this build knows passed the quality gate.
    func targetLanguages(from source: String?) -> [TranslationTargetLanguage] {
        guard let languagePairs else {
            return TranslationTargetLanguage.passed.filter { $0.rawValue != source }
        }
        let open = Set(languagePairs.filter { source == nil || $0.source == source }.map(\.target))
        return TranslationTargetLanguage.allCases.filter {
            open.contains($0.rawValue) && $0.rawValue != source
        }
    }

    /// Whether translating into `target` has passed the quality gate —
    /// otherwise the picker marks it Beta.
    func isApproved(from source: String?, to target: TranslationTargetLanguage) -> Bool {
        guard let languagePairs else { return TranslationTargetLanguage.passed.contains(target) }
        return languagePairs.contains {
            $0.target == target.rawValue && $0.validated && (source == nil || $0.source == source)
        }
    }
}
