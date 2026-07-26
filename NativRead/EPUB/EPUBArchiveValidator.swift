import Foundation
import ZIPFoundation

/// Rejects hostile ZIP shapes before ZIPFoundation writes anything to disk.
/// EPUB imports are untrusted input even when they come from the Files picker.
enum EPUBArchiveValidator {
    static let maximumArchiveBytes: UInt64 = 128 * 1_024 * 1_024
    static let maximumExpandedBytes: UInt64 = 512 * 1_024 * 1_024
    static let maximumEntryBytes: UInt64 = 64 * 1_024 * 1_024
    static let maximumEntryCount = 10_000

    static func validate(at archiveURL: URL) throws {
        let attributes = try FileManager.default.attributesOfItem(
            atPath: archiveURL.path
        )
        let archiveBytes = (attributes[.size] as? NSNumber)?.uint64Value ?? 0
        guard archiveBytes > 0, archiveBytes <= maximumArchiveBytes else {
            throw EPUBError.unreadableArchive(
                "The EPUB exceeds the safe compressed-size limit."
            )
        }

        let archive: Archive
        do {
            archive = try Archive(url: archiveURL, accessMode: .read)
        } catch {
            throw EPUBError.unreadableArchive(error.localizedDescription)
        }

        var count = 0
        var expandedBytes: UInt64 = 0
        var paths = Set<String>()
        for entry in archive {
            count += 1
            guard count <= maximumEntryCount else {
                throw EPUBError.unreadableArchive(
                    "The EPUB contains too many files."
                )
            }
            let path = entry.path.replacingOccurrences(of: "\\", with: "/")
            guard isSafeRelativePath(path), paths.insert(path).inserted else {
                throw EPUBError.unreadableArchive(
                    "The EPUB contains an unsafe or duplicate file path."
                )
            }
            // EPUB has no use for symlinks. Rejecting them also closes the
            // classic symlink-then-write-outside extraction chain.
            guard entry.type != .symlink else {
                throw EPUBError.unreadableArchive(
                    "Symbolic links are not allowed in EPUB files."
                )
            }
            let entryBytes = UInt64(entry.uncompressedSize)
            guard entryBytes <= maximumEntryBytes else {
                throw EPUBError.unreadableArchive(
                    "The EPUB contains an oversized file."
                )
            }
            let (nextTotal, overflowed) = expandedBytes.addingReportingOverflow(
                entryBytes
            )
            guard !overflowed, nextTotal <= maximumExpandedBytes else {
                throw EPUBError.unreadableArchive(
                    "The EPUB expands beyond the safe size limit."
                )
            }
            expandedBytes = nextTotal
        }
        guard count > 0 else {
            throw EPUBError.unreadableArchive("The EPUB archive is empty.")
        }
    }

    static func isSafeRelativePath(_ path: String) -> Bool {
        let normalized = path.replacingOccurrences(of: "\\", with: "/")
        guard !normalized.isEmpty,
              !normalized.contains("\0"),
              !normalized.hasPrefix("/"),
              normalized.range(
                of: "^[A-Za-z]:/", options: .regularExpression
              ) == nil
        else { return false }

        let components = normalized.split(
            separator: "/", omittingEmptySubsequences: false
        )
        // Reject canonical aliases too (`a/./b`, `a//b`). Besides traversal,
        // those can make two ZIP entries overwrite the same extracted path.
        for (index, component) in components.enumerated() {
            if component == "." || component == ".." { return false }
            if component.isEmpty && index != components.indices.last {
                return false
            }
        }
        return true
    }
}
