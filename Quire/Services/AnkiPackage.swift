import Foundation
import CryptoKit
import SQLite3
import ZIPFoundation

/// Builds a native Anki `.apkg` deck from saved vocabulary, so the reader
/// can open the file and have a "Quire Vocabulary" deck appear in Anki
/// with no import-mapping step. The package is a ZIP containing a
/// `collection.anki2` SQLite database (Anki's schema v11) plus an empty
/// `media` manifest.
///
/// The schema, default `col` JSON blobs, and the base91 GUID scheme are
/// ported from the canonical Python `genanki`
/// (github.com/kerrickstaley/genanki). No Python/Go runtime is used — the
/// SQLite is generated directly here via the C API.
///
/// Determinism: a fixed model id, fixed deck id, and a stable per-word
/// GUID mean re-importing an updated deck UPDATES existing notes in Anki
/// rather than creating duplicates.
enum AnkiPackage {

    // MARK: - Stable identity constants

    /// Fixed note-type (model) id. genanki-style: a large integer derived
    /// from a millisecond epoch, frozen so every export uses the same model.
    static let modelID: Int64 = 1_718_500_000_001

    /// Fixed deck id, frozen so re-imports merge into the same deck.
    static let deckID: Int64 = 1_718_500_000_002

    static let deckName = "Quire Vocabulary"
    static let modelName = "Quire Vocabulary"

    /// SQLite wants a non-default deck id; deck `1` ("Default") always
    /// exists in the seed `col` row alongside ours.

    // MARK: - Public API

    /// Builds the `.apkg` and returns its file URL, or throws on failure.
    /// `now` is injectable so tests can pin timestamps; identity (guids,
    /// model/deck ids) is independent of it, so re-runs stay stable.
    static func build(
        for entries: [VocabularyEntry],
        now: Date = .now,
        directory: URL = FileManager.default.temporaryDirectory
    ) throws -> URL {
        let workDir = directory.appendingPathComponent(
            "anki-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: workDir, withIntermediateDirectories: true)

        let dbURL = workDir.appendingPathComponent("collection.anki2")
        try writeCollection(entries: entries, now: now, to: dbURL)

        // Anki expects a `media` manifest at the archive root; with no
        // referenced media it is the JSON object `{}`.
        let mediaURL = workDir.appendingPathComponent("media")
        try Data("{}".utf8).write(to: mediaURL)

        let packageURL = directory.appendingPathComponent(
            "\(deckName).apkg")
        try? FileManager.default.removeItem(at: packageURL)

        let archive = try Archive(
            url: packageURL, accessMode: .create)
        try archive.addEntry(
            with: "collection.anki2",
            relativeTo: workDir, compressionMethod: .deflate)
        try archive.addEntry(
            with: "media",
            relativeTo: workDir, compressionMethod: .deflate)

        try? FileManager.default.removeItem(at: workDir)
        return packageURL
    }

    // MARK: - Stable GUID / checksum (ported from genanki util)

    /// Anki's base91 alphabet (genanki `BASE91_TABLE`).
    private static let base91: [Character] = Array(
        "abcdefghijklmnopqrstuvwxyz"
        + "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        + "0123456789"
        + "!#$%&()*+,-./:;<=>?@[]^_`{|}~")

    /// A stable GUID for a word: base91 of the first 8 bytes of the
    /// SHA-256 of a deterministic key (the lowercased, trimmed word). Same
    /// word ⇒ same GUID across exports ⇒ Anki updates instead of dupes.
    static func guid(for entry: VocabularyEntry) -> String {
        let key = entry.dedupKey
        let digest = SHA256.hash(data: Data(key.utf8))
        var value: UInt64 = 0
        for byte in digest.prefix(8) {
            value = (value << 8) | UInt64(byte)
        }
        guard value > 0 else { return String(base91[0]) }
        var chars: [Character] = []
        let radix = UInt64(base91.count)
        while value > 0 {
            chars.append(base91[Int(value % radix)])
            value /= radix
        }
        return String(chars.reversed())
    }

    /// `csum`: the integer value of the first 8 hex chars of SHA-1 of the
    /// sort field, as Anki computes it for the `ix_notes_csum` index.
    static func checksum(forSortField field: String) -> Int64 {
        let digest = Insecure.SHA1.hash(data: Data(field.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        let prefix = String(hex.prefix(8))
        return Int64(prefix, radix: 16) ?? 0
    }

    // MARK: - Field rendering

    /// The four model fields, in declared order, for one entry. HTML in
    /// the definition/context is escaped so user text never breaks card
    /// rendering. Fields are joined with the `\u{1f}` unit separator.
    static func fields(for entry: VocabularyEntry) -> [String] {
        [
            htmlEscape(entry.word),
            htmlEscape(entry.contextSentence?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""),
            htmlEscape(entry.definition),
            htmlEscape(entry.dictionarySource)
        ]
    }

    private static func htmlEscape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    // MARK: - Collection writer

    private static func writeCollection(
        entries: [VocabularyEntry], now: Date, to url: URL
    ) throws {
        try? FileManager.default.removeItem(at: url)

        let db = try SQLiteDatabase(path: url.path)
        try db.execute(Self.schemaSQL)

        let crt = Int64(now.timeIntervalSince1970)
        let modMillis = Int64(now.timeIntervalSince1970 * 1000)
        let modSeconds = crt

        try insertCollectionRow(
            db: db, crt: crt, mod: modMillis,
            modSeconds: modSeconds, now: now)

        // Notes and their single front/back card. `due`/note id/card id use
        // the entry index so the deck is ordered and ids are stable.
        for (index, entry) in entries.enumerated() {
            let noteID = modMillis + Int64(index)
            let cardID = noteID + 1_000_000
            let joined = fields(for: entry)
                .joined(separator: "\u{1f}")
            let sortField = htmlEscape(entry.word)

            try db.execute(
                "INSERT INTO notes VALUES(?,?,?,?,?,?,?,?,?,?,?);",
                bind: { stmt in
                    stmt.bindInt(1, noteID)
                    stmt.bindText(2, guid(for: entry))
                    stmt.bindInt(3, modelID)
                    stmt.bindInt(4, modSeconds)
                    stmt.bindInt(5, -1)             // usn
                    stmt.bindText(6, "")            // tags
                    stmt.bindText(7, joined)        // flds
                    stmt.bindText(8, sortField)     // sfld
                    stmt.bindInt(9, checksum(forSortField: sortField))
                    stmt.bindInt(10, 0)             // flags
                    stmt.bindText(11, "")           // data
                })

            try db.execute(
                "INSERT INTO cards VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?);",
                bind: { stmt in
                    stmt.bindInt(1, cardID)
                    stmt.bindInt(2, noteID)         // nid
                    stmt.bindInt(3, deckID)         // did
                    stmt.bindInt(4, 0)              // ord
                    stmt.bindInt(5, modSeconds)
                    stmt.bindInt(6, -1)             // usn
                    stmt.bindInt(7, 0)              // type (new)
                    stmt.bindInt(8, 0)              // queue (new)
                    stmt.bindInt(9, Int64(index))   // due
                    stmt.bindInt(10, 0)             // ivl
                    stmt.bindInt(11, 0)             // factor
                    stmt.bindInt(12, 0)             // reps
                    stmt.bindInt(13, 0)             // lapses
                    stmt.bindInt(14, 0)             // left
                    stmt.bindInt(15, 0)             // odue
                    stmt.bindInt(16, 0)             // odid
                    stmt.bindInt(17, 0)             // flags
                    stmt.bindText(18, "")           // data
                })
        }
    }

    private static func insertCollectionRow(
        db: SQLiteDatabase, crt: Int64, mod: Int64,
        modSeconds: Int64, now: Date
    ) throws {
        let models = modelsJSON(mod: modSeconds)
        let decks = decksJSON(mod: modSeconds)

        try db.execute(
            "INSERT INTO col VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?);",
            bind: { stmt in
                stmt.bindInt(1, 1)            // id
                stmt.bindInt(2, crt)          // crt
                stmt.bindInt(3, mod)          // mod (ms)
                stmt.bindInt(4, mod)          // scm (ms)
                stmt.bindInt(5, 11)           // ver
                stmt.bindInt(6, 0)            // dty
                stmt.bindInt(7, 0)            // usn
                stmt.bindInt(8, 0)            // ls
                stmt.bindText(9, Self.confJSON)
                stmt.bindText(10, models)
                stmt.bindText(11, decks)
                stmt.bindText(12, Self.dconfJSON)
                stmt.bindText(13, "{}")       // tags
            })
    }
}

// MARK: - JSON blobs (single model + Default/Quire decks)

extension AnkiPackage {

    /// The single Basic-style note type, serialised as Anki's `models`
    /// map keyed by model id. Front shows the word large with the context
    /// below; back adds a rule and the definition, with the source as a
    /// small footer. `req` marks the `Word` field (ord 0) as required.
    static func modelsJSON(mod: Int64) -> String {
        let css = """
        .card {
          font-family: Georgia, 'Times New Roman', serif;
          font-size: 20px;
          text-align: center;
          color: #1c1c1e;
          background: #fbfaf7;
          padding: 24px;
        }
        .word { font-size: 30px; font-weight: 600; }
        .context {
          margin-top: 14px;
          font-style: italic;
          color: #6b6b6b;
          font-size: 17px;
        }
        .definition { margin-top: 8px; font-size: 18px; }
        .source {
          margin-top: 18px;
          font-size: 12px;
          color: #9a9a9a;
        }
        hr { border: none; border-top: 1px solid #d8d4cc; margin: 16px 0; }
        """

        let front = """
        <div class="word">{{Word}}</div>
        {{#Context}}<div class="context">{{Context}}</div>{{/Context}}
        """

        let back = """
        {{FrontSide}}
        <hr>
        <div class="definition">{{Definition}}</div>
        {{#Source}}<div class="source">{{Source}}</div>{{/Source}}
        """

        let model: [String: Any] = [
            "id": String(modelID),
            "name": modelName,
            "type": 0,                 // FRONT_BACK (not cloze)
            "mod": mod,
            "usn": -1,
            "sortf": 0,
            "did": deckID,
            "tags": [],
            "vers": [],
            "latexPre": "",
            "latexPost": "",
            "latexsvg": false,
            "css": css,
            "flds": ["Word", "Context", "Definition", "Source"]
                .enumerated().map { ord, name in
                    [
                        "name": name, "ord": ord, "sticky": false,
                        "rtl": false, "font": "Georgia", "size": 20,
                        "media": []
                    ] as [String: Any]
                },
            "tmpls": [
                [
                    "name": "Card 1", "ord": 0,
                    "qfmt": front, "afmt": back,
                    "bqfmt": "", "bafmt": "",
                    "did": NSNull(), "bfont": "", "bsize": 0
                ] as [String: Any]
            ],
            "req": [[0, "all", [0]]]
        ]

        return jsonString([String(modelID): model])
    }

    /// The `decks` map: Anki's mandatory "Default" deck (id 1) plus our
    /// "Quire Vocabulary" deck.
    static func decksJSON(mod: Int64) -> String {
        func deck(id: Int64, name: String) -> [String: Any] {
            [
                "id": id, "name": name, "mod": mod, "usn": -1,
                "collapsed": false, "browserCollapsed": false,
                "desc": "", "dyn": 0, "conf": 1,
                "extendNew": 0, "extendRev": 50,
                "lrnToday": [0, 0], "newToday": [0, 0],
                "revToday": [0, 0], "timeToday": [0, 0]
            ]
        }
        return jsonString([
            "1": deck(id: 1, name: "Default"),
            String(deckID): deck(id: deckID, name: deckName)
        ])
    }

    /// genanki's default `conf` blob (collection-level configuration).
    static let confJSON = """
    {"activeDecks":[1],"addToCur":true,"collapseTime":1200,"curDeck":1,\
    "curModel":"\(modelID)","dueCounts":true,"estTimes":true,\
    "newBury":true,"newSpread":0,"nextPos":1,"sortBackwards":false,\
    "sortType":"noteFld","timeLim":0}
    """

    /// genanki's default `dconf` blob (deck options, id 1).
    static let dconfJSON = """
    {"1":{"autoplay":true,"id":1,"lapse":{"delays":[10],"leechAction":0,\
    "leechFails":8,"minInt":1,"mult":0},"maxTaken":60,"mod":0,\
    "name":"Default","new":{"bury":true,"delays":[1,10],\
    "initialFactor":2500,"ints":[1,4,7],"order":1,"perDay":20,\
    "separate":true},"replayq":true,"rev":{"bury":true,"ease4":1.3,\
    "fuzz":0.05,"ivlFct":1,"maxIvl":36500,"minSpace":1,"perDay":100},\
    "timer":0,"usn":0}}
    """

    private static func jsonString(_ object: Any) -> String {
        guard
            let data = try? JSONSerialization.data(
                withJSONObject: object, options: [.sortedKeys]),
            let string = String(data: data, encoding: .utf8)
        else { return "{}" }
        return string
    }
}

// MARK: - Anki schema (genanki apkg_schema.py, ver 11)

extension AnkiPackage {
    static let schemaSQL = """
    CREATE TABLE col (
        id integer primary key, crt integer not null, mod integer not null,
        scm integer not null, ver integer not null, dty integer not null,
        usn integer not null, ls integer not null, conf text not null,
        models text not null, decks text not null, dconf text not null,
        tags text not null
    );
    CREATE TABLE notes (
        id integer primary key, guid text not null, mid integer not null,
        mod integer not null, usn integer not null, tags text not null,
        flds text not null, sfld integer not null, csum integer not null,
        flags integer not null, data text not null
    );
    CREATE TABLE cards (
        id integer primary key, nid integer not null, did integer not null,
        ord integer not null, mod integer not null, usn integer not null,
        type integer not null, queue integer not null, due integer not null,
        ivl integer not null, factor integer not null, reps integer not null,
        lapses integer not null, left integer not null, odue integer not null,
        odid integer not null, flags integer not null, data text not null
    );
    CREATE TABLE revlog (
        id integer primary key, cid integer not null, usn integer not null,
        ease integer not null, ivl integer not null, lastIvl integer not null,
        factor integer not null, time integer not null, type integer not null
    );
    CREATE TABLE graves (
        usn integer not null, oid integer not null, type integer not null
    );
    CREATE INDEX ix_notes_usn on notes (usn);
    CREATE INDEX ix_cards_usn on cards (usn);
    CREATE INDEX ix_revlog_usn on revlog (usn);
    CREATE INDEX ix_cards_nid on cards (nid);
    CREATE INDEX ix_cards_sched on cards (did, queue, due);
    CREATE INDEX ix_revlog_cid on revlog (cid);
    CREATE INDEX ix_notes_csum on notes (csum);
    """
}

// MARK: - Minimal SQLite3 wrapper

/// A tiny prepared-statement wrapper over the SQLite3 C API, scoped to
/// what the Anki writer needs (execute schema, insert rows with bound
/// text/int). Text is bound with `SQLITE_TRANSIENT` so SQLite copies it
/// and binding lifetime never matters.
private final class SQLiteDatabase {
    private var handle: OpaquePointer?

    private static let transient = unsafeBitCast(
        -1, to: sqlite3_destructor_type.self)

    enum SQLiteError: Error {
        case open(String)
        case prepare(String)
        case step(String)
    }

    init(path: String) throws {
        guard sqlite3_open(path, &handle) == SQLITE_OK, handle != nil else {
            let message = handle.map { String(cString: sqlite3_errmsg($0)) }
                ?? "unknown"
            sqlite3_close(handle)
            throw SQLiteError.open(message)
        }
    }

    deinit {
        sqlite3_close(handle)
    }

    /// Runs one or more statements with no bindings (used for the schema).
    func execute(_ sql: String) throws {
        var errorPointer: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(handle, sql, nil, nil, &errorPointer)
            == SQLITE_OK
        else {
            let message = errorPointer.map { String(cString: $0) }
                ?? "unknown"
            sqlite3_free(errorPointer)
            throw SQLiteError.step(message)
        }
    }

    /// Prepares `sql`, lets `bind` set parameters, then steps once.
    func execute(
        _ sql: String, bind: (Statement) -> Void
    ) throws {
        var stmtHandle: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &stmtHandle, nil)
            == SQLITE_OK, let stmtHandle
        else {
            throw SQLiteError.prepare(
                String(cString: sqlite3_errmsg(handle)))
        }
        defer { sqlite3_finalize(stmtHandle) }

        bind(Statement(handle: stmtHandle))

        guard sqlite3_step(stmtHandle) == SQLITE_DONE else {
            throw SQLiteError.step(
                String(cString: sqlite3_errmsg(handle)))
        }
    }

    /// Thin binder around a prepared statement; 1-based parameter indices.
    struct Statement {
        let handle: OpaquePointer

        func bindInt(_ index: Int32, _ value: Int64) {
            sqlite3_bind_int64(handle, index, value)
        }

        func bindText(_ index: Int32, _ value: String) {
            sqlite3_bind_text(
                handle, index, value, -1, SQLiteDatabase.transient)
        }
    }
}
