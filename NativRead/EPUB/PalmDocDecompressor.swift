import Foundation

/// PalmDOC (LZ77) decompression — the only compression KF8 text uses in the
/// plain (non-HUFF/CDIC) case this converter supports.
///
/// Byte grammar: 0x00 literal NUL · 0x01–0x08 copy next N literal bytes ·
/// 0x09–0x7F literal char · 0x80–0xBF LZ77 back-reference (2 bytes: 11-bit
/// distance, 3-bit length+3) · 0xC0–0xFF space + (byte XOR 0x80).
enum PalmDocDecompressor {
    static func decompress(_ input: Data) -> Data {
        let bytes = [UInt8](input)
        var out: [UInt8] = []
        out.reserveCapacity(bytes.count * 2)
        var i = 0
        while i < bytes.count {
            let c = bytes[i]
            i += 1
            switch c {
            case 0x00:
                out.append(c)
            case 0x01 ... 0x08:
                let end = min(i + Int(c), bytes.count)
                out.append(contentsOf: bytes[i ..< end])
                i = end
            case 0x09 ... 0x7F:
                out.append(c)
            case 0x80 ... 0xBF:
                guard i < bytes.count else { break }
                let c2 = bytes[i]
                i += 1
                let pair = Int(c) << 8 | Int(c2)
                let distance = (pair >> 3) & 0x07FF
                let length = (Int(c2) & 0x07) + 3
                guard distance > 0, distance <= out.count else { break }
                for _ in 0 ..< length {
                    out.append(out[out.count - distance])
                }
            default: // 0xC0 ... 0xFF
                out.append(0x20)
                out.append(c ^ 0x80)
            }
        }
        return Data(out)
    }
}
