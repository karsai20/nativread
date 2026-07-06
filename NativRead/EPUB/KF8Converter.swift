import Foundation

/// Converts a pure-KF8 MOBI/AZW3 book into an EPUB, in pure Swift.
///
/// Constraints: supports plain PalmDOC-compressed (compression == 2),
/// unencrypted, KF8 (version >= 8) books only — no HUFF/CDIC, no DRM, and
/// no legacy MOBI6-only files. Those raise `MOBIError.unsupported`.
enum KF8Converter {
    /// Reassembled book pieces, ready to be written as an EPUB.
    struct Book {
        let title: String
        let author: String
        let parts: [(name: String, xhtml: String)]
        let styles: [(name: String, data: Data)]
        let images: [(name: String, data: Data, mediaType: String)]
        let coverImageName: String?
    }

    static func convertToEPUB(source: URL, destination: URL) throws {
        let data = try Data(contentsOf: source)
        let book = try makeBook(from: data)
        try KF8EPUBWriter.write(book, to: destination)
    }

    // MARK: - Reassembly

    static func makeBook(from data: Data) throws -> Book {
        let db = try PalmDatabase(data: data)
        guard db.creator == "MOBI" || db.creator == "TPZ0" else {
            throw MOBIError.notMOBI
        }
        let mobi = try MOBIHeader(record0: db.record(0))
        guard mobi.encryption == 0 else {
            throw MOBIError.unsupported("the book is DRM-protected")
        }
        guard mobi.compression == 2 else {
            throw MOBIError.unsupported("unsupported text compression")
        }
        guard mobi.version >= 8 else {
            throw MOBIError.unsupported("only KF8 (AZW3) books are supported")
        }

        // 1. Decompress + concatenate the text records into the raw markup blob.
        // textRecordCount is untrusted; clamp to the records that exist and
        // tolerate 0 (an empty blob falls through to the no-readable-text throw).
        var raw = Data()
        let lastTextRecord = min(mobi.textRecordCount, db.recordCount - 1)
        for i in stride(from: 1, through: lastTextRecord, by: 1) {
            let trimmed = mobi.trimTrailingData(db.record(i))
            raw.append(PalmDocDecompressor.decompress(trimmed))
        }

        // 2. Split the blob into flows via the FDST table.
        let flows = splitFlows(raw: raw, fdst: db.record(mobi.fdstIndex))

        // 3. Read the skeleton + fragment indices and reassemble the XHTML files.
        let skeleton = MOBIIndex.parse(headerIndex: mobi.skeletonIndex) { db.record($0) }
        let fragments = MOBIIndex.parse(headerIndex: mobi.fragmentIndex) { db.record($0) }
        let flow0 = flows.first ?? Data()
        let rawParts = reassemble(flow0: flow0, skeleton: skeleton, fragments: fragments)
        // Bogus header record indices yield empty skeleton/fragment tables and
        // no parts; surface an import failure instead of a blank, unopenable book.
        guard !rawParts.isEmpty else {
            throw MOBIError.unsupported("the book has no readable text")
        }

        // 4. Collect image resources and non-text flows (CSS/SVG).
        let images = collectImages(db: db, firstImageIndex: mobi.firstImageIndex)
        let recordName = Dictionary(
            uniqueKeysWithValues: images.map { ($0.record, $0.name) }
        )
        let styles = flowResources(flows: flows)

        // 5. Rewrite kindle: references to relative EPUB paths.
        let parts = rawParts.enumerated().map { index, markup -> (String, String) in
            let name = String(format: "part%04d.xhtml", index)
            let rewritten = rewriteReferences(
                in: markup, firstImageIndex: mobi.firstImageIndex,
                recordName: recordName, partCount: rawParts.count,
                fragments: fragments, styleName: styleName(_:)
            )
            return (name, rewritten)
        }

        let coverName = coverImageName(
            mobi: mobi, recordName: recordName
        )
        return Book(
            title: mobi.exthString(MOBIHeader.exthTitle) ?? "Untitled",
            author: mobi.exthString(MOBIHeader.exthAuthor) ?? "Unknown author",
            parts: parts,
            styles: styles.map { ($0.name, $0.data) },
            images: images.map { ($0.name, $0.data, $0.mediaType) },
            coverImageName: coverName
        )
    }

    // MARK: - FDST flows

    /// FDST: magic "FDST", 4-byte count at 0x08, then a table of (start,end)
    /// uint32 pairs. Slices the raw blob at each start boundary.
    private static func splitFlows(raw: Data, fdst: Data) -> [Data] {
        guard fdst.count >= 12, fdst.magic(0) == "FDST" else { return [raw] }
        let sectionCount = fdst.be32(8)
        guard sectionCount > 0, 12 + sectionCount * 8 <= fdst.count else { return [raw] }
        var starts: [Int] = []
        for i in 0 ..< sectionCount {
            starts.append(fdst.be32(12 + i * 8))
        }
        starts.append(raw.count)
        return (0 ..< sectionCount).map { j in
            let lo = min(starts[j], raw.count)
            let hi = min(starts[j + 1], raw.count)
            guard lo <= hi else { return Data() }
            return raw.subdata(in: raw.startIndex + lo ..< raw.startIndex + hi)
        }
    }

    // MARK: - Skeleton/fragment reassembly

    /// Rebuilds each XHTML file by inserting fragment slices from flow 0 into
    /// their skeleton shell at the recorded byte positions (KindleUnpack logic).
    private static func reassemble(
        flow0: Data, skeleton: [MOBIIndexEntry], fragments: [MOBIIndexEntry]
    ) -> [String] {
        let text = [UInt8](flow0)
        var parts: [String] = []
        var fragmentPointer = 0

        for skel in skeleton {
            let fragmentCount = skel.tags[1]?.first ?? 0
            guard let geometry = skel.tags[6], geometry.count >= 2 else { continue }
            let skelPos = geometry[0]
            let skelLen = geometry[1]
            var basePointer = skelPos + skelLen
            guard skelPos >= 0, basePointer <= text.count else { continue }
            var shell = Array(text[skelPos ..< basePointer])

            for _ in 0 ..< fragmentCount where fragmentPointer < fragments.count {
                let fragment = fragments[fragmentPointer]
                fragmentPointer += 1
                let length = fragment.tags[6]?.count == 2
                    ? fragment.tags[6]![1] : 0
                let insertPos = Int(fragment.name) ?? basePointer
                guard basePointer + length <= text.count else { continue }
                let slice = Array(text[basePointer ..< basePointer + length])
                let insertion = min(max(insertPos - skelPos, 0), shell.count)
                shell.insert(contentsOf: slice, at: insertion)
                basePointer += length
            }
            parts.append(String(decoding: shell, as: UTF8.self))
        }
        return parts
    }

    // MARK: - Resources

    private struct ImageResource {
        let record: Int
        let name: String
        let data: Data
        let mediaType: String
    }

    /// Resource records run from `firstImageIndex` until the first record that
    /// is not a recognised image (JPEG/PNG/GIF) — that boundary is the FDST/
    /// FLIS/FCIS/index block that follows the images.
    private static func collectImages(
        db: PalmDatabase, firstImageIndex: Int
    ) -> [ImageResource] {
        var result: [ImageResource] = []
        var index = firstImageIndex
        while index < db.recordCount {
            let record = db.record(index)
            guard let (ext, mediaType) = imageKind(record) else { break }
            result.append(ImageResource(
                record: index,
                name: String(format: "img%05d.%@", index, ext),
                data: record, mediaType: mediaType
            ))
            index += 1
        }
        return result
    }

    private static func imageKind(_ data: Data) -> (ext: String, mediaType: String)? {
        guard data.count >= 4 else { return nil }
        let b = [UInt8](data.prefix(8))
        if b[0] == 0xFF, b[1] == 0xD8, b[2] == 0xFF { return ("jpg", "image/jpeg") }
        if b.count >= 8, b[0] == 0x89, b[1] == 0x50, b[2] == 0x4E, b[3] == 0x47 {
            return ("png", "image/png")
        }
        if b[0] == 0x47, b[1] == 0x49, b[2] == 0x46, b[3] == 0x38 { return ("gif", "image/gif") }
        return nil
    }

    private struct StyleResource { let flowIndex: Int; let name: String; let data: Data }

    /// Flows 1+ are stylesheet/SVG resources; flow 0 is the XHTML text.
    private static func flowResources(flows: [Data]) -> [StyleResource] {
        guard flows.count > 1 else { return [] }
        return (1 ..< flows.count).map { i in
            StyleResource(flowIndex: i, name: styleName(i), data: flows[i])
        }
    }

    private static func styleName(_ flowIndex: Int) -> String {
        String(format: "flow%04d.css", flowIndex)
    }

    // MARK: - Reference rewriting

    /// Rewrites `kindle:flow:`, `kindle:embed:` and `kindle:pos:fid:` URIs to
    /// relative EPUB paths (all resources sit beside the XHTML in OEBPS/).
    private static func rewriteReferences(
        in markup: String, firstImageIndex: Int, recordName: [Int: String],
        partCount: Int, fragments: [MOBIIndexEntry], styleName: (Int) -> String
    ) -> String {
        var text = markup
        text = replace(text, #"kindle:flow:([0-9A-V]{4})(\?[^"'\s)>]*)?"#) { groups in
            styleName(base32(groups[0]))
        }
        text = replace(text, #"kindle:embed:([0-9A-V]{4})(\?[^"'\s)>]*)?"#) { groups in
            let record = firstImageIndex + base32(groups[0]) - 1
            return recordName[record] ?? "#"
        }
        text = replace(text, #"kindle:pos:fid:([0-9A-V]+):off:([0-9A-V]+)"#) { groups in
            let fid = base32(groups[0])
            // ponytail: link to the target file's top, not the exact aid anchor —
            // the reader navigates by spine index, so a file-level link suffices.
            let fileNum = fid < fragments.count
                ? (fragments[fid].tags[3]?.first ?? 0) : 0
            let clamped = min(max(fileNum, 0), max(partCount - 1, 0))
            return String(format: "part%04d.xhtml", clamped)
        }
        // Neutralise any remaining kindle: URIs so no dangling scheme ships.
        text = replace(text, #"kindle:[^"'\s)>]*"#) { _ in "#" }
        return text
    }

    private static let base32Alphabet = Array("0123456789ABCDEFGHIJKLMNOPQRSTUV")

    private static func base32(_ string: String) -> Int {
        // The digit string comes from untrusted book markup; a long fake FID
        // must degrade to 0 (an unresolvable reference), never overflow-trap.
        var value = 0
        for character in string.uppercased() {
            guard let digit = base32Alphabet.firstIndex(of: character) else { continue }
            let (shifted, overflow1) = value.multipliedReportingOverflow(by: 32)
            guard !overflow1 else { return 0 }
            let (sum, overflow2) = shifted.addingReportingOverflow(digit)
            guard !overflow2 else { return 0 }
            value = sum
        }
        return value
    }

    /// Regex replace where `transform` receives the captured groups (1-based).
    private static func replace(
        _ input: String, _ pattern: String, _ transform: ([String]) -> String
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return input }
        let full = NSRange(input.startIndex..., in: input)
        var result = ""
        var last = input.startIndex
        for match in regex.matches(in: input, range: full) {
            guard let matchRange = Range(match.range, in: input) else { continue }
            var groups: [String] = []
            for i in 1 ..< match.numberOfRanges {
                if let r = Range(match.range(at: i), in: input) {
                    groups.append(String(input[r]))
                } else {
                    groups.append("")
                }
            }
            result += input[last ..< matchRange.lowerBound]
            result += transform(groups)
            last = matchRange.upperBound
        }
        result += input[last...]
        return result
    }

    private static func coverImageName(
        mobi: MOBIHeader, recordName: [Int: String]
    ) -> String? {
        if let data = mobi.exth[MOBIHeader.exthCoverOffset], data.count >= 4 {
            let record = mobi.firstImageIndex + data.be32(0)
            if let name = recordName[record] { return name }
        }
        // Fall back to the first image so the library always shows a cover.
        return recordName.min(by: { $0.key < $1.key })?.value
    }
}
