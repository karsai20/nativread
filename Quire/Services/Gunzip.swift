import Foundation
import zlib

/// Errors raised while decompressing gzip data.
enum GunzipError: Error, Equatable {
    case emptyInput
    case initFailed(Int32)
    case inflateFailed(Int32)
}

/// Decompresses standard gzip data (as produced by `gzip`) into plain bytes.
///
/// Uses zlib's streaming `inflate` with `windowBits = 47` so the gzip header
/// is auto-detected. Streaming in fixed-size chunks keeps memory bounded and
/// makes no assumption about the decompressed size — suitable for large
/// (e.g. 14 MB → 75 MB) dictionary blobs.
func gunzip(_ data: Data) throws -> Data {
    guard !data.isEmpty else { throw GunzipError.emptyInput }

    // 47 = 32 (auto-detect gzip/zlib header) + 15 (max window bits).
    let windowBits: Int32 = 47
    let chunkSize = 256 * 1024

    var stream = z_stream()
    let initStatus = inflateInit2_(
        &stream, windowBits, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size)
    )
    guard initStatus == Z_OK else {
        throw GunzipError.initFailed(initStatus)
    }
    defer { inflateEnd(&stream) }

    var output = Data()
    var outBuffer = [UInt8](repeating: 0, count: chunkSize)

    // `withUnsafeBytes` over the input keeps a single contiguous source buffer
    // alive for the whole inflate loop; the cursor advances via `next_in`.
    let result: Result<Data, GunzipError> = data.withUnsafeBytes { rawInput in
        guard let inBase = rawInput.bindMemory(to: UInt8.self).baseAddress else {
            return .failure(.inflateFailed(Z_DATA_ERROR))
        }
        stream.next_in = UnsafeMutablePointer(mutating: inBase)
        stream.avail_in = uInt(data.count)

        while true {
            let status: Int32 = outBuffer.withUnsafeMutableBufferPointer { outPtr in
                stream.next_out = outPtr.baseAddress
                stream.avail_out = uInt(chunkSize)
                return inflate(&stream, Z_NO_FLUSH)
            }

            let produced = chunkSize - Int(stream.avail_out)
            if produced > 0 {
                output.append(contentsOf: outBuffer[0..<produced])
            }

            switch status {
            case Z_STREAM_END:
                return .success(output)
            case Z_OK, Z_BUF_ERROR:
                // Z_BUF_ERROR with no progress and no input left means done/stuck.
                if stream.avail_in == 0 && produced == 0 {
                    return .success(output)
                }
                continue
            default:
                return .failure(.inflateFailed(status))
            }
        }
    }

    return try result.get()
}
