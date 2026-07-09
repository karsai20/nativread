import Foundation
import NaturalLanguage

enum DetectedBookLanguage: Equatable {
    case language(code: String, name: String, confidence: Double)
    case unknown

    var displayText: String {
        switch self {
        case .language(_, let name, let confidence):
            return "\(name) · \(Int((confidence * 100).rounded()))% confidence"
        case .unknown:
            return "Could not detect source language"
        }
    }

    static func detect(from sample: String) -> DetectedBookLanguage {
        let trimmed = sample.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 80 else { return .unknown }
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(String(trimmed.prefix(4_000)))
        guard let language = recognizer.dominantLanguage else { return .unknown }
        let hypotheses = recognizer.languageHypotheses(withMaximum: 1)
        let confidence = hypotheses[language] ?? 0
        let code = language.rawValue
        let name = Locale.current.localizedString(forLanguageCode: code) ?? code.uppercased()
        return .language(code: code, name: name.capitalized, confidence: confidence)
    }
}

enum TranslationTargetLanguage: String, Codable, CaseIterable, Equatable, Hashable {
    case hu
    case de
    case es

    /// Languages that cleared the raised quality gate (full-novel pipeline
    /// run + native-speaker read, dated go/no-go — blueprint §3). Only these
    /// appear in the picker; the rest are waitlist-only. Deliberately a
    /// hardcoded list (eng D7): a new language is a release event, not a
    /// hotfix.
    static let passed: [TranslationTargetLanguage] = [.hu]

    var displayName: String {
        switch self {
        case .hu: return "Hungarian"
        case .de: return "German"
        case .es: return "Spanish"
        }
    }

    var shortCode: String { rawValue.uppercased() }

    var validationNote: String {
        switch self {
        case .hu:
            return "Validated baseline language"
        case .de, .es:
            return "Needs full-novel quality validation before launch"
        }
    }
}

enum TranslationJobPhase: String, Codable, Equatable {
    case draft
    case attested
    case uploading
    case translating
    case importingResult
    case finished
    case failed

    /// The backend request is in progress. Reloading a job in one of these
    /// phases from disk means the app died mid-request; the store fails it.
    var isInFlight: Bool {
        switch self {
        case .uploading, .translating, .importingResult:
            return true
        default:
            return false
        }
    }

    /// Tolerant decoding: raw values from earlier builds that no longer exist
    /// (e.g. the removed `previewQueued`/`waitingForBackend` scaffolding) map to
    /// `.failed` instead of throwing, which would make `load()`'s `try?` wipe
    /// every persisted job.
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = TranslationJobPhase(rawValue: raw) ?? .failed
    }
}

enum TranslationRequestKind: String, Codable, Equatable {
    case preview
    case full
}

enum TranslationPriceTier: String, Codable, CaseIterable, Equatable {
    case under100
    case pages100To199
    case pages200To349
    case pages350To549
    case pages550To799
    case pages800Plus

    var displayName: String {
        switch self {
        case .under100: return "Under 100 pages"
        case .pages100To199: return "100-199 pages"
        case .pages200To349: return "200-349 pages"
        case .pages350To549: return "350-549 pages"
        case .pages550To799: return "550-799 pages"
        case .pages800Plus: return "800+ pages"
        }
    }

    var priceText: String {
        switch self {
        case .under100: return "$2.99"
        case .pages100To199: return "$3.99"
        case .pages200To349: return "$4.99"
        case .pages350To549: return "$6.99"
        case .pages550To799: return "$8.99"
        case .pages800Plus: return "$11.99"
        }
    }

    static func tier(forEstimatedPages pages: Int) -> TranslationPriceTier {
        switch pages {
        case ..<100: return .under100
        case 100..<200: return .pages100To199
        case 200..<350: return .pages200To349
        case 350..<550: return .pages350To549
        case 550..<800: return .pages550To799
        default: return .pages800Plus
        }
    }
}

struct TranslationJob: Codable, Equatable, Identifiable {
    var id: UUID { bookID }

    let bookID: UUID
    var bookTitle: String
    var targetLanguage: TranslationTargetLanguage
    var phase: TranslationJobPhase
    var attestedAt: Date?
    var estimatedPages: Int
    var priceTier: TranslationPriceTier
    var backendJobID: String?
    var activeRequestKind: TranslationRequestKind?
    var previewCompletedAt: Date?
    var fullCompletedAt: Date?
    var translatedChunks: Int?
    var totalChunks: Int?
    var errorMessage: String?
    var updatedAt: Date

    private enum CodingKeys: String, CodingKey {
        case bookID, bookTitle, targetLanguage, phase, attestedAt
        case estimatedPages, priceTier, backendJobID, activeRequestKind
        case previewCompletedAt, fullCompletedAt, translatedChunks
        case totalChunks, errorMessage, updatedAt
    }

    /// Custom decode so jobs persisted by v3.2 (before multi-language
    /// metadata) still load: a missing `targetLanguage` means Hungarian,
    /// the only language that existed. Without this, one missing key makes
    /// the whole `translation-jobs.json` decode fail and silently drops
    /// every job (attestation, completion markers, backend IDs).
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        bookID = try c.decode(UUID.self, forKey: .bookID)
        bookTitle = try c.decode(String.self, forKey: .bookTitle)
        targetLanguage = try c.decodeIfPresent(
            TranslationTargetLanguage.self, forKey: .targetLanguage
        ) ?? .hu
        phase = try c.decode(TranslationJobPhase.self, forKey: .phase)
        attestedAt = try c.decodeIfPresent(Date.self, forKey: .attestedAt)
        estimatedPages = try c.decode(Int.self, forKey: .estimatedPages)
        priceTier = try c.decode(
            TranslationPriceTier.self, forKey: .priceTier
        )
        backendJobID = try c.decodeIfPresent(
            String.self, forKey: .backendJobID
        )
        activeRequestKind = try c.decodeIfPresent(
            TranslationRequestKind.self, forKey: .activeRequestKind
        )
        previewCompletedAt = try c.decodeIfPresent(
            Date.self, forKey: .previewCompletedAt
        )
        fullCompletedAt = try c.decodeIfPresent(
            Date.self, forKey: .fullCompletedAt
        )
        translatedChunks = try c.decodeIfPresent(
            Int.self, forKey: .translatedChunks
        )
        totalChunks = try c.decodeIfPresent(Int.self, forKey: .totalChunks)
        errorMessage = try c.decodeIfPresent(
            String.self, forKey: .errorMessage
        )
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
    }

    init(
        bookID: UUID,
        bookTitle: String,
        targetLanguage: TranslationTargetLanguage = .hu,
        phase: TranslationJobPhase = .draft,
        attestedAt: Date? = nil,
        estimatedPages: Int,
        priceTier: TranslationPriceTier,
        backendJobID: String? = nil,
        activeRequestKind: TranslationRequestKind? = nil,
        previewCompletedAt: Date? = nil,
        fullCompletedAt: Date? = nil,
        translatedChunks: Int? = nil,
        totalChunks: Int? = nil,
        errorMessage: String? = nil,
        updatedAt: Date = .now
    ) {
        self.bookID = bookID
        self.bookTitle = bookTitle
        self.targetLanguage = targetLanguage
        self.phase = phase
        self.attestedAt = attestedAt
        self.estimatedPages = estimatedPages
        self.priceTier = priceTier
        self.backendJobID = backendJobID
        self.activeRequestKind = activeRequestKind
        self.previewCompletedAt = previewCompletedAt
        self.fullCompletedAt = fullCompletedAt
        self.translatedChunks = translatedChunks
        self.totalChunks = totalChunks
        self.errorMessage = errorMessage
        self.updatedAt = updatedAt
    }

    var progressText: String? {
        guard let translatedChunks,
              let totalChunks,
              totalChunks > 0
        else { return nil }
        return "\(translatedChunks)/\(totalChunks) sections"
    }
}
