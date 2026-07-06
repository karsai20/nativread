import Foundation

/// The PalmDOC + MOBI headers from record 0, plus EXTH metadata. Field
/// offsets are taken relative to the start of record 0 (the MOBI header
/// begins at byte 16, right after the 16-byte PalmDOC header).
struct MOBIHeader {
    // EXTH record types this converter reads.
    static let exthAuthor = 100
    static let exthCoverOffset = 201
    static let exthTitle = 503

    let compression: Int
    let encryption: Int
    let textRecordCount: Int
    let version: Int
    let firstImageIndex: Int
    let trailingFlags: Int
    let fdstIndex: Int
    let fdstCount: Int
    let fragmentIndex: Int
    let skeletonIndex: Int
    /// EXTH type → raw content bytes.
    let exth: [Int: Data]

    init(record0: Data) throws {
        guard record0.count >= 16 else { throw MOBIError.notMOBI }
        compression = record0.be16(0)
        textRecordCount = record0.be16(8)
        encryption = record0.be16(12)

        guard record0.count >= 16 + 24, record0.magic(16) == "MOBI" else {
            throw MOBIError.notMOBI
        }
        let headerLength = record0.be32(20)
        version = record0.be32(36)
        firstImageIndex = record0.be32(0x6C)
        // KF8 index record numbers live at fixed offsets in the MOBI header.
        fdstIndex = record0.be32(0xC0)
        fdstCount = record0.be32(0xC4)
        fragmentIndex = record0.be32(0xF8)
        skeletonIndex = record0.be32(0xFC)
        // The trailing-data flags word only exists in longer headers.
        trailingFlags = headerLength >= 0xF4 ? record0.be16(0xF2) : 0

        // EXTH follows the fixed MOBI header when flag 0x40 is set at 0x80.
        let exthFlags = record0.be32(0x80)
        if exthFlags & 0x40 != 0 {
            exth = MOBIHeader.parseEXTH(record0, at: 16 + headerLength)
        } else {
            exth = [:]
        }
    }

    /// Reads an EXTH block: magic "EXTH", 4-byte length, 4-byte count, then
    /// `count` records of (4-byte type, 4-byte size, size-8 content bytes).
    private static func parseEXTH(_ data: Data, at start: Int) -> [Int: Data] {
        guard start + 12 <= data.count, data.magic(start) == "EXTH" else {
            return [:]
        }
        let count = data.be32(start + 8)
        var result: [Int: Data] = [:]
        var pos = start + 12
        for _ in 0 ..< count {
            guard pos + 8 <= data.count else { break }
            let type = data.be32(pos)
            let size = data.be32(pos + 4)
            guard size >= 8, pos + size <= data.count else { break }
            result[type] = data.subdata(
                in: data.startIndex + pos + 8 ..< data.startIndex + pos + size
            )
            pos += size
        }
        return result
    }

    func exthString(_ type: Int) -> String? {
        guard let data = exth[type], !data.isEmpty else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    /// Trims trailing multibyte/extra-data entries a text record carries
    /// before it can be PalmDOC-decompressed. Each set bit above bit 0 marks
    /// one backward-varint-sized entry; bit 0 marks a multibyte overlap.
    func trimTrailingData(_ record: Data) -> Data {
        var bytes = [UInt8](record)
        var flags = trailingFlags >> 1
        while flags != 0 {
            if flags & 1 != 0 {
                let size = MOBIHeader.trailingEntrySize(bytes)
                guard size <= bytes.count else { return Data() }
                bytes.removeLast(size)
            }
            flags >>= 1
        }
        if trailingFlags & 1 != 0, !bytes.isEmpty {
            let size = Int(bytes[bytes.count - 1] & 0x03) + 1
            guard size <= bytes.count else { return Data() }
            bytes.removeLast(size)
        }
        return Data(bytes)
    }

    /// Decodes the backward big-endian base-128 varint in the last bytes of a
    /// record that gives the size of one trailing data entry (size included).
    private static func trailingEntrySize(_ bytes: [UInt8]) -> Int {
        var value = 0
        for byte in bytes.suffix(4) {
            if byte & 0x80 != 0 { value = 0 }
            value = (value << 7) | Int(byte & 0x7F)
        }
        return value
    }
}
