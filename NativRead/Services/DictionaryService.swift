import Foundation

/// One definition for a headword, as decoded from a `.dict` slice.
struct DictionaryEntry: Equatable {
    let headword: String
    /// Raw definition text. HTML when `type == "h"`, plain text otherwise.
    let definition: String
    /// StarDict field type, e.g. "h" (HTML) or "m" (plain text).
    let type: Character
}

/// All hits for a word from a single dictionary.
struct DictionaryResult: Equatable {
    let bookname: String
    let entries: [DictionaryEntry]
}

/// Errors raised while parsing or loading a StarDict dictionary.
enum DictionaryError: Error, Equatable {
    case unreadableFile(URL)
    case invalidIfoMagic
    case missingIfoField(String)
    case unsupportedOffsetBits(Int)
}

/// A single loaded StarDict dictionary (`.ifo` + `.idx` + `.dict`).
///
/// The `.dict` blob must already be plain (decompressed). Decompression of
/// `dictzip`/`.dict.dz` files is handled by a separate layer.
final class StarDictionary {

    let bookname: String

    /// Lowercased headword -> all (offset, size) slices into `dictData`.
    /// Lowercasing gives case-insensitive lookup without StarDict collation.
    private let index: [String: [Slice]]
    private let dictData: Data
    /// Field type from `sametypesequence`; defaults to plain text.
    private let defaultType: Character

    private struct Slice {
        let headword: String
        let offset: Int
        let size: Int
    }

    init(ifoURL: URL, idxURL: URL, dictURL: URL) throws {
        let ifo = try Self.parseIfo(at: ifoURL)
        self.bookname = ifo.bookname
        self.defaultType = ifo.sameTypeSequence ?? "m"

        guard let dictData = try? Data(contentsOf: dictURL) else {
            throw DictionaryError.unreadableFile(dictURL)
        }
        guard let idxData = try? Data(contentsOf: idxURL) else {
            throw DictionaryError.unreadableFile(idxURL)
        }
        self.dictData = dictData
        self.index = Self.buildIndex(from: idxData)
    }

    /// Case-insensitive lookup. Returns one entry per matching `.dict` slice.
    func lookup(_ word: String) -> [DictionaryEntry] {
        let key = word.lowercased()
        guard let slices = index[key] else { return [] }

        return slices.compactMap { slice in
            guard let text = decode(slice) else { return nil }
            return DictionaryEntry(
                headword: slice.headword,
                definition: text,
                type: defaultType
            )
        }
    }

    // MARK: - Decoding

    private func decode(_ slice: Slice) -> String? {
        let lower = slice.offset
        let upper = slice.offset + slice.size
        guard lower >= 0, upper <= dictData.count, lower <= upper else {
            return nil
        }
        var bytes = dictData.subdata(in: lower..<upper)
        // A single trailing 0x00 terminator may be included in the slice.
        if bytes.last == 0x00 {
            bytes.removeLast()
        }
        return String(data: bytes, encoding: .utf8)
    }

    // MARK: - .ifo parsing

    private struct IfoFields {
        let bookname: String
        let sameTypeSequence: Character?
    }

    private static func parseIfo(at url: URL) throws -> IfoFields {
        guard
            let data = try? Data(contentsOf: url),
            let text = String(data: data, encoding: .utf8)
        else {
            throw DictionaryError.unreadableFile(url)
        }

        let lines = text.split(
            separator: "\n", omittingEmptySubsequences: false
        ).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        guard let magic = lines.first,
              magic == "StarDict's dict ifo file" else {
            throw DictionaryError.invalidIfoMagic
        }

        var fields: [String: String] = [:]
        for line in lines.dropFirst() where !line.isEmpty {
            guard let eq = line.firstIndex(of: "=") else { continue }
            let key = String(line[line.startIndex..<eq])
            let value = String(line[line.index(after: eq)...])
            fields[key] = value
        }

        if let bits = fields["idxoffsetbits"], bits == "64" {
            throw DictionaryError.unsupportedOffsetBits(64)
        }

        guard let bookname = fields["bookname"], !bookname.isEmpty else {
            throw DictionaryError.missingIfoField("bookname")
        }

        let sameType: Character? = {
            guard let seq = fields["sametypesequence"],
                  seq.count == 1 else { return nil }
            return seq.first
        }()

        return IfoFields(bookname: bookname, sameTypeSequence: sameType)
    }

    // MARK: - .idx parsing

    /// Parses the flat `.idx` blob into a lowercased index. Each record is:
    /// `headword UTF-8` + `0x00` + UInt32 BE offset + UInt32 BE size.
    /// A truncated trailing record is skipped rather than crashing.
    private static func buildIndex(from data: Data) -> [String: [Slice]] {
        var index: [String: [Slice]] = [:]
        let bytes = [UInt8](data)
        let count = bytes.count
        var cursor = 0

        while cursor < count {
            guard let nul = nextNul(in: bytes, from: cursor) else { break }
            // Need 8 bytes (offset + size) after the terminator.
            let numbersStart = nul + 1
            guard numbersStart + 8 <= count else { break }

            let headwordBytes = bytes[cursor..<nul]
            guard let headword = String(
                bytes: headwordBytes, encoding: .utf8
            ), !headword.isEmpty else {
                cursor = numbersStart + 8
                continue
            }

            let offset = readUInt32BE(bytes, at: numbersStart)
            let size = readUInt32BE(bytes, at: numbersStart + 4)
            let slice = Slice(
                headword: headword,
                offset: Int(offset),
                size: Int(size)
            )
            index[headword.lowercased(), default: []].append(slice)
            cursor = numbersStart + 8
        }

        return index
    }

    private static func nextNul(in bytes: [UInt8], from start: Int) -> Int? {
        var i = start
        while i < bytes.count {
            if bytes[i] == 0x00 { return i }
            i += 1
        }
        return nil
    }

    /// Reads a big-endian UInt32 at `offset`. Caller guarantees bounds.
    private static func readUInt32BE(_ bytes: [UInt8], at offset: Int) -> UInt32 {
        (UInt32(bytes[offset]) << 24)
            | (UInt32(bytes[offset + 1]) << 16)
            | (UInt32(bytes[offset + 2]) << 8)
            | UInt32(bytes[offset + 3])
    }
}

/// Holds several loaded dictionaries and looks up a word across all of them.
final class DictionaryService {

    private(set) var dictionaries: [StarDictionary]

    init(dictionaries: [StarDictionary] = []) {
        self.dictionaries = dictionaries
    }

    func add(_ dictionary: StarDictionary) {
        dictionaries.append(dictionary)
    }

    /// Looks up `word` in every dictionary, in insertion order. Dictionaries
    /// with no match are skipped.
    ///
    /// An exact match always wins. When no dictionary has the exact form, the
    /// word is reduced to base-form candidates (`moved` → `move`, `wolves` →
    /// `wolf`) and the first candidate that hits anywhere is returned — the
    /// indices store lemmas only, so an inflected selection would otherwise
    /// find nothing.
    func lookup(_ word: String) -> [DictionaryResult] {
        let exact = results(for: word)
        if !exact.isEmpty { return exact }

        for candidate in Lemmatizer.candidates(for: word) {
            let hit = results(for: candidate)
            if !hit.isEmpty { return hit }
        }
        return []
    }

    /// One pass over every dictionary for an exact (case-insensitive) form.
    private func results(for word: String) -> [DictionaryResult] {
        dictionaries.compactMap { dictionary in
            let entries = dictionary.lookup(word)
            guard !entries.isEmpty else { return nil }
            return DictionaryResult(
                bookname: dictionary.bookname,
                entries: entries
            )
        }
    }
}
