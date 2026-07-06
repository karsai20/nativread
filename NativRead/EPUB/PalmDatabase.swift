import Foundation

/// Big-endian integer reads at an absolute offset from a Data's own
/// `startIndex`, so they work on both a whole file and a sliced record.
/// Out-of-range reads return 0 (and `magic` returns "") instead of trapping:
/// every offset here ultimately comes from an untrusted file, and a short
/// record must degrade to an import failure downstream, never a crash —
/// the same posture as `PalmDatabase.record(_:)`.
extension Data {
    func be8(_ offset: Int) -> Int {
        guard offset >= 0, offset < count else { return 0 }
        return Int(self[startIndex + offset])
    }
    func be16(_ offset: Int) -> Int { be8(offset) << 8 | be8(offset + 1) }
    func be32(_ offset: Int) -> Int {
        be8(offset) << 24 | be8(offset + 1) << 16
            | be8(offset + 2) << 8 | be8(offset + 3)
    }
    /// ASCII magic string of `length` bytes at `offset`.
    func magic(_ offset: Int, _ length: Int = 4) -> String {
        guard offset >= 0, length >= 0, offset + length <= count else { return "" }
        return String(
            decoding: subdata(in: startIndex + offset ..< startIndex + offset + length),
            as: UTF8.self
        )
    }
}

enum MOBIError: LocalizedError {
    case notPalmDB
    case notMOBI
    case unsupported(String)

    var errorDescription: String? {
        switch self {
        case .notPalmDB: return "The file is not a valid Palm database."
        case .notMOBI: return "The file is not a MOBI/AZW3 book."
        case .unsupported(let why): return "This MOBI/AZW3 book is unsupported: \(why)."
        }
    }
}

/// A parsed Palm Database (the container format MOBI/AZW3 use). Holds the
/// backing file bytes and record boundaries; records are sliced on demand.
struct PalmDatabase {
    let type: String
    let creator: String
    private let data: Data
    /// `recordCount + 1` byte offsets; record N spans offsets[N]..<offsets[N+1].
    private let offsets: [Int]

    var recordCount: Int { offsets.count - 1 }

    /// Slices record `index`, or returns empty `Data` when the index is out of
    /// range. Header-supplied record numbers (FDST/skeleton/fragment) come from
    /// untrusted files; an out-of-range subscript would trap, so callers get an
    /// empty record instead and degrade to an import failure downstream.
    func record(_ index: Int) -> Data {
        guard index >= 0, index < recordCount else { return Data() }
        return data.subdata(in: offsets[index] ..< offsets[index + 1])
    }

    init(data: Data) throws {
        guard data.count >= 78 else { throw MOBIError.notPalmDB }
        self.data = data
        type = data.magic(60)
        creator = data.magic(64)
        let numRecords = data.be16(76)
        // The record-info list is 8 bytes/entry starting at offset 78; only
        // the leading 4-byte record offset is needed (attrs/uid ignored).
        guard 78 + numRecords * 8 <= data.count else { throw MOBIError.notPalmDB }
        var starts: [Int] = []
        starts.reserveCapacity(numRecords + 1)
        for i in 0 ..< numRecords {
            let offset = data.be32(78 + i * 8)
            guard offset <= data.count else { throw MOBIError.notPalmDB }
            starts.append(offset)
        }
        starts.append(data.count)
        // Guard monotonicity so record slicing can never form an invalid range.
        for i in 0 ..< numRecords where starts[i] > starts[i + 1] {
            throw MOBIError.notPalmDB
        }
        offsets = starts
    }
}
