import Foundation
import Observation

/// Identifies one bundled StarDict dictionary by its resource folder and the
/// shared basename of its `.ifo`/`.idx`/`.dict.dz` files.
struct BundledDictionary: Sendable, Equatable {
    let folder: String
    let basename: String

    static let wordnet = BundledDictionary(folder: "wordnet", basename: "wordnet")

    /// All dictionaries shipped in the app bundle. Add EN→HU here later.
    static let bundled: [BundledDictionary] = [.wordnet]
}

/// Errors raised while preparing bundled dictionaries.
enum DictionaryProviderError: Error, Equatable {
    case missingResource(String)
    case unpackProducedEmptyFile(URL)
}

/// Loads bundled StarDict dictionaries for the app.
///
/// On `prepare()` each dictionary's gzip-compressed `.dict.dz` is decompressed
/// once into Application Support as a plain `.dict` (skipped if already present
/// and non-empty), then a `StarDictionary` is built from the bundled
/// `.ifo`/`.idx` plus the unpacked `.dict`. Heavy work runs off the main
/// thread; `service`/`isReady` are published on the main actor.
@Observable
@MainActor
final class DictionaryProvider {

    private(set) var service: DictionaryService?
    var isReady: Bool { service != nil }

    private let dictionaries: [BundledDictionary]
    private let resourceLoader: ResourceLoader
    private let supportDirectory: URL
    private var didStart = false

    /// Resolves a bundled resource trio. Injectable so tests avoid `Bundle.main`.
    struct ResourceLoader: Sendable {
        /// Returns the bundled `.ifo`, `.idx`, and `.dict.dz` URLs for a dictionary.
        let urls: @Sendable (BundledDictionary) throws -> (
            ifo: URL, idx: URL, dictDZ: URL
        )

        static let main = ResourceLoader { dict in
            func resource(_ ext: String) throws -> URL {
                let name = "\(dict.basename).\(ext)"
                // Resources may be flattened or kept under a folder reference.
                if let url = Bundle.main.url(
                    forResource: dict.basename,
                    withExtension: ext,
                    subdirectory: dict.folder
                ) {
                    return url
                }
                if let url = Bundle.main.url(
                    forResource: dict.basename, withExtension: ext
                ) {
                    return url
                }
                throw DictionaryProviderError.missingResource(name)
            }
            return (
                ifo: try resource("ifo"),
                idx: try resource("idx"),
                dictDZ: try resource("dict.dz")
            )
        }
    }

    init(
        dictionaries: [BundledDictionary] = BundledDictionary.bundled,
        resourceLoader: ResourceLoader = .main,
        supportDirectory: URL? = nil
    ) {
        self.dictionaries = dictionaries
        self.resourceLoader = resourceLoader
        self.supportDirectory = supportDirectory ?? Self.defaultSupportDirectory()
    }

    /// Decompresses and builds every dictionary, then publishes the service.
    /// Safe to call multiple times — only the first call does work.
    func prepare() async {
        guard !didStart else { return }
        didStart = true

        let dictionaries = self.dictionaries
        let loader = self.resourceLoader
        let support = self.supportDirectory

        let built = await Task.detached(priority: .utility) {
            Self.buildService(
                dictionaries: dictionaries,
                loader: loader,
                supportDirectory: support
            )
        }.value

        service = built
    }

    /// Forwards to the loaded service. Empty until `prepare()` finishes.
    func lookup(_ word: String) -> [DictionaryResult] {
        service?.lookup(word) ?? []
    }

    // MARK: - Build (off the main actor)

    /// Builds a `DictionaryService` from the given dictionaries, unpacking each
    /// `.dict.dz` into `supportDirectory` as needed. Returns `nil` only if no
    /// dictionary could be loaded. Pure of `@MainActor` state, so it runs on a
    /// detached task and is directly testable with injected URLs.
    nonisolated static func buildService(
        dictionaries: [BundledDictionary],
        loader: ResourceLoader,
        supportDirectory: URL
    ) -> DictionaryService? {
        let loaded: [StarDictionary] = dictionaries.compactMap { dict in
            do {
                return try load(
                    dict, loader: loader, supportDirectory: supportDirectory
                )
            } catch {
                // One bad dictionary must not block the others.
                return nil
            }
        }
        return loaded.isEmpty ? nil : DictionaryService(dictionaries: loaded)
    }

    /// Loads one dictionary, unpacking its `.dict.dz` into Application Support
    /// if a non-empty plain `.dict` isn't already there.
    nonisolated static func load(
        _ dict: BundledDictionary,
        loader: ResourceLoader,
        supportDirectory: URL
    ) throws -> StarDictionary {
        let bundled = try loader.urls(dict)
        let dictURL = try unpackedDictURL(
            for: dict, source: bundled.dictDZ, in: supportDirectory
        )
        return try StarDictionary(
            ifoURL: bundled.ifo, idxURL: bundled.idx, dictURL: dictURL
        )
    }

    /// Returns the URL of the plain unpacked `.dict`, decompressing the source
    /// `.dict.dz` on first use. Skips work when a non-empty file already exists.
    nonisolated static func unpackedDictURL(
        for dict: BundledDictionary,
        source dictDZ: URL,
        in supportDirectory: URL
    ) throws -> URL {
        let fileManager = FileManager.default
        let folder = supportDirectory.appendingPathComponent(
            dict.folder, isDirectory: true
        )
        try fileManager.createDirectory(
            at: folder, withIntermediateDirectories: true
        )
        let dictURL = folder.appendingPathComponent("\(dict.basename).dict")

        if let size = try? fileManager.attributesOfItem(atPath: dictURL.path)[.size]
            as? Int, size > 0 {
            return dictURL
        }

        let compressed = try Data(contentsOf: dictDZ)
        let plain = try gunzip(compressed)
        guard !plain.isEmpty else {
            throw DictionaryProviderError.unpackProducedEmptyFile(dictURL)
        }
        // Write atomically so a crash mid-write can't leave a truncated file
        // that the size check above would wrongly accept.
        try plain.write(to: dictURL, options: .atomic)
        return dictURL
    }

    private nonisolated static func defaultSupportDirectory() -> URL {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("Dictionaries", isDirectory: true)
    }
}
