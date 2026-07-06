import Foundation

/// One entry of a parsed MOBI INDX index: its name plus a tag→values map
/// decoded from the TAGX control bytes.
struct MOBIIndexEntry {
    let name: String
    let tags: [Int: [Int]]
}

/// Parses a MOBI INDX index (the KF8 skeleton and fragment tables). The
/// header record supplies the data-record count and the TAGX tag table;
/// each data record holds an IDXT offset table pointing at its entries.
enum MOBIIndex {
    private struct TagDef { let tag, valuesPerEntry, mask, endFlag: Int }

    static func parse(headerIndex: Int, record: (Int) -> Data) -> [MOBIIndexEntry] {
        let header = record(headerIndex)
        guard header.count >= 0x1C, header.magic(0) == "INDX" else { return [] }
        let dataRecordCount = header.be32(0x18)
        let (controlByteCount, tagTable) = readTagSection(header)
        guard !tagTable.isEmpty else { return [] }

        var entries: [MOBIIndexEntry] = []
        for r in 0 ..< dataRecordCount {
            let data = record(headerIndex + 1 + r)
            guard data.count >= 0x1C, data.magic(0) == "INDX" else { continue }
            let idxtPos = data.be32(0x14)
            let entryCount = data.be32(0x18)
            guard idxtPos + 4 + entryCount * 2 <= data.count else { continue }

            var positions: [Int] = []
            positions.reserveCapacity(entryCount + 1)
            for j in 0 ..< entryCount {
                positions.append(data.be16(idxtPos + 4 + j * 2))
            }
            positions.append(idxtPos) // end boundary for the last entry

            for j in 0 ..< entryCount {
                let start = positions[j]
                let end = positions[j + 1]
                guard start < end, end <= data.count else { continue }
                let nameLength = data.be8(start)
                let nameEnd = start + 1 + nameLength
                guard nameEnd <= end else { continue }
                let name = String(
                    decoding: data.subdata(
                        in: data.startIndex + start + 1 ..< data.startIndex + nameEnd
                    ), as: UTF8.self
                )
                let tags = getTagMap(
                    controlByteCount: controlByteCount, tagTable: tagTable,
                    data: data, start: nameEnd, end: end
                )
                entries.append(MOBIIndexEntry(name: name, tags: tags))
            }
        }
        return entries
    }

    /// Reads the TAGX section (tag definitions) from the header record.
    private static func readTagSection(_ data: Data) -> (Int, [TagDef]) {
        let count = data.count
        var start = -1
        // TAGX sits after the fixed header; locate it by magic.
        for i in 0 ..< max(0, count - 4) where data.magic(i) == "TAGX" {
            start = i
            break
        }
        guard start >= 0, start + 12 <= count else { return (0, []) }
        let firstEntryOffset = data.be32(start + 4)
        let controlByteCount = data.be32(start + 8)
        var tags: [TagDef] = []
        var i = 12
        while start + i + 4 <= count, i < firstEntryOffset {
            let p = start + i
            tags.append(TagDef(
                tag: data.be8(p), valuesPerEntry: data.be8(p + 1),
                mask: data.be8(p + 2), endFlag: data.be8(p + 3)
            ))
            i += 4
        }
        return (controlByteCount, tags)
    }

    /// Decodes an entry's control bytes + values into a tag→values map,
    /// following the TAGX mask/bitcount rules.
    private static func getTagMap(
        controlByteCount: Int, tagTable: [TagDef], data: Data, start: Int, end: Int
    ) -> [Int: [Int]] {
        // (tag, valueCount?, valueBytes?, valuesPerEntry) pending descriptors.
        var pending: [(tag: Int, count: Int?, bytes: Int?, vpe: Int)] = []
        var controlByteIndex = 0
        var dataStart = start + controlByteCount

        for def in tagTable {
            if def.endFlag == 0x01 {
                controlByteIndex += 1
                continue
            }
            guard start + controlByteIndex < end else { break }
            var value = data.be8(start + controlByteIndex) & def.mask
            guard value != 0 else { continue }
            if value == def.mask {
                if bitCount(def.mask) > 1 {
                    let (consumed, v) = variableWidthValue(data, dataStart, end)
                    dataStart += consumed
                    pending.append((def.tag, nil, v, def.valuesPerEntry))
                } else {
                    pending.append((def.tag, 1, nil, def.valuesPerEntry))
                }
            } else {
                var mask = def.mask
                while mask & 0x01 == 0 {
                    mask >>= 1
                    value >>= 1
                }
                pending.append((def.tag, value, nil, def.valuesPerEntry))
            }
        }

        var result: [Int: [Int]] = [:]
        for item in pending {
            var values: [Int] = []
            if let count = item.count {
                for _ in 0 ..< count {
                    for _ in 0 ..< item.vpe {
                        let (consumed, v) = variableWidthValue(data, dataStart, end)
                        dataStart += consumed
                        values.append(v)
                    }
                }
            } else if let byteBudget = item.bytes {
                var consumedTotal = 0
                while consumedTotal < byteBudget {
                    let (consumed, v) = variableWidthValue(data, dataStart, end)
                    dataStart += consumed
                    consumedTotal += consumed
                    values.append(v)
                }
            }
            result[item.tag] = values
        }
        return result
    }

    /// Big-endian base-128 varint terminated by a high bit set (that final
    /// byte's low 7 bits are still part of the value).
    private static func variableWidthValue(
        _ data: Data, _ offset: Int, _ end: Int
    ) -> (consumed: Int, value: Int) {
        var value = 0
        var consumed = 0
        while offset + consumed < end {
            let byte = data.be8(offset + consumed)
            consumed += 1
            value = (value << 7) | (byte & 0x7F)
            if byte & 0x80 != 0 { break }
        }
        return (consumed, value)
    }

    private static func bitCount(_ x: Int) -> Int { x.nonzeroBitCount }
}
