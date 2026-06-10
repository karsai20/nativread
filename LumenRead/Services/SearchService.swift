import Foundation

struct SearchResult: Identifiable, Equatable {
    let id = UUID()
    let spineIndex: Int
    /// Ordinal of this match inside its chapter (for in-page location).
    let occurrenceInChapter: Int
    let snippet: String
    let chapterTitle: String

    static func == (lhs: SearchResult, rhs: SearchResult) -> Bool {
        lhs.spineIndex == rhs.spineIndex
            && lhs.occurrenceInChapter == rhs.occurrenceInChapter
    }
}

/// Whole-book full-text search over the unpacked spine documents.
/// Pure string work — no WebKit — so it is unit-testable and fast.
enum SearchService {

    static let maxResults = 80

    /// Strips tags, scripts, styles and entities from chapter XHTML.
    static func plainText(fromXHTML xhtml: String) -> String {
        var text = xhtml
        for pattern in [
            "(?is)<script.*?</script>",
            "(?is)<style.*?</style>",
            "(?is)<head.*?</head>",
            "(?s)<[^>]+>"
        ] {
            text = text.replacingOccurrences(
                of: pattern, with: " ", options: .regularExpression
            )
        }
        let entities = [
            "&nbsp;": " ", "&amp;": "&", "&lt;": "<", "&gt;": ">",
            "&quot;": "\"", "&#39;": "'", "&apos;": "'",
            "&mdash;": "—", "&ndash;": "–", "&hellip;": "…"
        ]
        for (entity, replacement) in entities {
            text = text.replacingOccurrences(of: entity, with: replacement)
        }
        return text.replacingOccurrences(
            of: "\\s+", with: " ", options: .regularExpression
        ).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Case-insensitive matches of `query` in one chapter's plain text.
    static func matches(
        in text: String, query: String, spineIndex: Int, chapterTitle: String
    ) -> [SearchResult] {
        guard query.count >= 2 else { return [] }
        var results: [SearchResult] = []
        var searchRange = text.startIndex..<text.endIndex
        var ordinal = 0
        while let found = text.range(
            of: query, options: [.caseInsensitive, .diacriticInsensitive],
            range: searchRange
        ) {
            results.append(SearchResult(
                spineIndex: spineIndex,
                occurrenceInChapter: ordinal,
                snippet: snippet(around: found, in: text),
                chapterTitle: chapterTitle
            ))
            ordinal += 1
            searchRange = found.upperBound..<text.endIndex
            if results.count >= maxResults { break }
        }
        return results
    }

    /// Searches every spine document of a parsed book.
    static func search(query: String, in parsed: ParsedEPUB) -> [SearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return [] }
        var all: [SearchResult] = []
        for (index, url) in parsed.spineURLs.enumerated() {
            guard let xhtml = try? String(contentsOf: url, encoding: .utf8)
            else { continue }
            let title = chapterTitle(forSpineIndex: index, in: parsed)
            all.append(contentsOf: matches(
                in: plainText(fromXHTML: xhtml),
                query: trimmed,
                spineIndex: index,
                chapterTitle: title
            ))
            if all.count >= maxResults {
                return Array(all.prefix(maxResults))
            }
        }
        return all
    }

    static func chapterTitle(
        forSpineIndex index: Int, in parsed: ParsedEPUB
    ) -> String {
        let candidates = parsed.toc.filter {
            ($0.spineIndex ?? .max) <= index
        }
        return candidates.last?.title ?? "Chapter \(index + 1)"
    }

    private static func snippet(
        around range: Range<String.Index>, in text: String
    ) -> String {
        let radius = 60
        let start = text.index(
            range.lowerBound, offsetBy: -radius,
            limitedBy: text.startIndex
        ) ?? text.startIndex
        let end = text.index(
            range.upperBound, offsetBy: radius,
            limitedBy: text.endIndex
        ) ?? text.endIndex
        let prefix = start > text.startIndex ? "…" : ""
        let suffix = end < text.endIndex ? "…" : ""
        return prefix + text[start..<end]
            .trimmingCharacters(in: .whitespaces) + suffix
    }
}
