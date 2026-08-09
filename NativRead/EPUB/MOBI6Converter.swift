import Foundation

/// Converts a legacy MOBI6 book — every `.mobi` without a KF8 half — into the
/// same `KF8Converter.Book` the EPUB writer consumes.
///
/// MOBI6 keeps the whole book as one HTML blob: chapters separated by
/// `<mbp:pagebreak>`, images referenced by a 1-based `recindex` into the image
/// records, and internal links by `filepos`, a **byte** offset into that blob.
/// Splitting and anchoring therefore happen on raw bytes — a `filepos` means
/// nothing once the text has been decoded into a `String`.
enum MOBI6Converter {

    static func makeBook(
        db: PalmDatabase, mobi: MOBIHeader, raw: Data
    ) throws -> KF8Converter.Book {
        let bytes = [UInt8](raw)
        let targets = fileposTargets(in: bytes).sorted()
        let chunks = split(bytes, at: pagebreakRanges(in: bytes))

        // Which part each link target lands in, so cross-chapter links resolve.
        var partOfTarget: [Int: Int] = [:]
        for (index, chunk) in chunks.enumerated() {
            let end = chunk.start + chunk.bytes.count
            for target in targets where target >= chunk.start && target < end {
                partOfTarget[target] = index
            }
        }

        let images = KF8Converter.collectImages(
            db: db, firstImageIndex: mobi.firstImageIndex
        )
        let recordName = Dictionary(
            uniqueKeysWithValues: images.map { ($0.record, $0.name) }
        )

        var parts: [(name: String, xhtml: String)] = []
        for (index, chunk) in chunks.enumerated() {
            let anchored = anchored(chunk, targets: targets)
            let decoded = sanitised(
                String(bytes: anchored, encoding: mobi.stringEncoding)
                    ?? String(decoding: anchored, as: UTF8.self)
            )
            let body = rewrite(
                decoded,
                firstImageIndex: mobi.firstImageIndex,
                recordName: recordName,
                partOfTarget: partOfTarget
            )
            guard !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else { continue }
            parts.append((Self.partName(index), wrap(body)))
        }

        // An empty or non-HTML blob must fail the import rather than produce a
        // book with no openable chapter.
        guard !parts.isEmpty else {
            throw MOBIError.unsupported("the book has no readable text")
        }

        return KF8Converter.Book(
            title: mobi.exthString(MOBIHeader.exthTitle) ?? "Untitled",
            author: mobi.exthString(MOBIHeader.exthAuthor) ?? "Unknown author",
            parts: parts,
            styles: [],
            images: images.map { ($0.name, $0.data, $0.mediaType) },
            coverImageName: KF8Converter.coverImageName(
                mobi: mobi, recordName: recordName
            )
        )
    }

    // MARK: - Byte scanning

    /// Byte ranges of every `<mbp:pagebreak …>` tag — the chapter separators.
    private static func pagebreakRanges(in bytes: [UInt8]) -> [Range<Int>] {
        let needle = [UInt8]("<mbp:pagebreak".utf8)
        var result: [Range<Int>] = []
        var index = 0
        while index + needle.count <= bytes.count {
            guard matches(bytes, at: index, needle) else {
                index += 1
                continue
            }
            var end = index + needle.count
            while end < bytes.count, bytes[end] != UInt8(ascii: ">") { end += 1 }
            result.append(index ..< min(end + 1, bytes.count))
            index = end + 1
        }
        return result
    }

    /// Every byte offset an internal `filepos=` link points at.
    private static func fileposTargets(in bytes: [UInt8]) -> Set<Int> {
        let needle = [UInt8]("filepos=".utf8)
        var result: Set<Int> = []
        var index = 0
        while index + needle.count <= bytes.count {
            guard matches(bytes, at: index, needle) else {
                index += 1
                continue
            }
            var cursor = index + needle.count
            if cursor < bytes.count, isQuote(bytes[cursor]) { cursor += 1 }
            var value = 0
            var digits = 0
            // Cap the digit run: the offsets are 10 digits at most, and an
            // absurdly long one from a corrupt file must not overflow.
            while cursor < bytes.count, isDigit(bytes[cursor]), digits < 12 {
                value = value * 10 + Int(bytes[cursor] - UInt8(ascii: "0"))
                cursor += 1
                digits += 1
            }
            if digits > 0, value < bytes.count { result.insert(value) }
            index = cursor
        }
        return result
    }

    private struct Chunk {
        let start: Int
        let bytes: ArraySlice<UInt8>
    }

    /// The blob cut at each pagebreak, separators dropped, each piece carrying
    /// its offset in the original blob so `filepos` targets stay resolvable.
    private static func split(
        _ bytes: [UInt8], at breaks: [Range<Int>]
    ) -> [Chunk] {
        var chunks: [Chunk] = []
        var cursor = 0
        for range in breaks where range.lowerBound >= cursor {
            chunks.append(Chunk(start: cursor, bytes: bytes[cursor ..< range.lowerBound]))
            cursor = range.upperBound
        }
        chunks.append(Chunk(start: cursor, bytes: bytes[cursor ..< bytes.count]))
        return chunks
    }

    /// Rebuilds the chunk with `<a id="filepos…"></a>` at every link target it
    /// contains. Built in one forward pass — repeatedly inserting into the
    /// array would be quadratic on a chapter with a large table of contents.
    private static func anchored(_ chunk: Chunk, targets: [Int]) -> [UInt8] {
        let source = Array(chunk.bytes)
        let end = chunk.start + source.count
        let placements = targets
            .filter { $0 >= chunk.start && $0 < end }
            .map { (target: $0, position: tagStart(in: source, from: $0 - chunk.start)) }
        guard !placements.isEmpty else { return source }

        var result: [UInt8] = []
        result.reserveCapacity(source.count + placements.count * 32)
        var cursor = 0
        // `targets` is ascending and the nudge is monotone, so positions are too.
        for (target, position) in placements where position >= cursor {
            result.append(contentsOf: source[cursor ..< position])
            result.append(contentsOf: anchorTag(target).utf8)
            cursor = position
        }
        result.append(contentsOf: source[cursor...])
        return result
    }

    /// A filepos is meant to point at the start of a tag. When it does not,
    /// skip to the next `<`: landing mid-tag would corrupt the markup, while a
    /// slightly late anchor only shifts where the link lands.
    private static func tagStart(in bytes: [UInt8], from offset: Int) -> Int {
        var position = max(offset, 0)
        while position < bytes.count, bytes[position] != UInt8(ascii: "<") {
            position += 1
        }
        return position
    }

    private static func matches(
        _ bytes: [UInt8], at index: Int, _ lowercaseNeedle: [UInt8]
    ) -> Bool {
        for (offset, expected) in lowercaseNeedle.enumerated()
        where lowercased(bytes[index + offset]) != expected {
            return false
        }
        return true
    }

    private static func lowercased(_ byte: UInt8) -> UInt8 {
        byte >= UInt8(ascii: "A") && byte <= UInt8(ascii: "Z") ? byte + 32 : byte
    }

    private static func isDigit(_ byte: UInt8) -> Bool {
        byte >= UInt8(ascii: "0") && byte <= UInt8(ascii: "9")
    }

    private static func isQuote(_ byte: UInt8) -> Bool {
        byte == UInt8(ascii: "\"") || byte == UInt8(ascii: "'")
    }

    // MARK: - Markup rewriting

    /// MOBI6 output is HTML, never XHTML — see `wrap`.
    static func partName(_ index: Int) -> String {
        KF8Converter.partName(index, ext: "html")
    }

    private static func anchorID(_ target: Int) -> String {
        String(format: "filepos%010d", target)
    }

    private static func anchorTag(_ target: Int) -> String {
        "<a id=\"\(anchorID(target))\"></a>"
    }

    /// Turns Kindle-only markup into EPUB markup: `filepos` links into real
    /// hrefs, `recindex` images into file references, and everything the
    /// reader cannot use into nothing.
    private static func rewrite(
        _ markup: String,
        firstImageIndex: Int,
        recordName: [Int: String],
        partOfTarget: [Int: Int]
    ) -> String {
        var text = markup

        text = KF8Converter.replace(text, #"filepos=['"]?(\d+)['"]?"#) { groups in
            guard let target = Int(groups[0]),
                  let part = partOfTarget[target] else { return "href=\"#\"" }
            return "href=\"\(partName(part))#\(anchorID(target))\""
        }

        text = KF8Converter.replace(text, #"recindex=['"]?(\d+)['"]?"#) { groups in
            // recindex is 1-based from the first image record.
            guard let recindex = Int(groups[0]),
                  let name = recordName[firstImageIndex + recindex - 1]
            else { return "" }
            return "src=\"\(name)\""
        }

        // Kindle-private elements and the OPF guide have no EPUB meaning.
        text = KF8Converter.replace(text, #"(?i)</?mbp:[^>]*>"#) { _ in "" }
        text = KF8Converter.replace(text, #"(?is)<guide>.*?</guide>"#) { _ in "" }
        // Document-level tags are re-added by `wrap`, one set per part.
        text = KF8Converter.replace(text, #"(?is)<head[^>]*>.*?</head>"#) { _ in "" }
        text = KF8Converter.replace(text, #"(?i)</?(html|body)[^>]*>"#) { _ in "" }
        return text
    }

    /// Drops the C0 control characters PalmDOC records carry between text
    /// runs. They are never content, they render as nothing, and a NUL makes a
    /// strict parser abandon the document outright. Tab, newline and carriage
    /// return are legitimate whitespace and stay.
    private static func sanitised(_ text: String) -> String {
        text.unicodeScalars.contains(where: isStrippable)
            ? String(String.UnicodeScalarView(text.unicodeScalars.filter { !isStrippable($0) }))
            : text
    }

    private static func isStrippable(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x09, 0x0A, 0x0D: return false
        case 0x00 ... 0x1F, 0x7F: return true
        default: return false
        }
    }

    /// Plain HTML, not XHTML: a MOBI6 blob is legacy markup with unclosed
    /// tags and bare ampersands, and making it XML-valid would mean rewriting
    /// the book. The `.html` name routes it to WebKit's tolerant parser.
    private static func wrap(_ body: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head><meta charset="utf-8"><title></title></head>
        <body>
        \(body)
        </body>
        </html>
        """
    }
}
