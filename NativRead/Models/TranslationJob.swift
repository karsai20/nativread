import Foundation
import NaturalLanguage

enum TranslationTerms {
    /// Change this whenever the accepted terms change materially. Existing
    /// translations keep working, but a new upload asks for acceptance again.
    /// 2026-08-03: rights attestation folded into the Terms (v1.1); the sheet
    /// checkbox now accepts the Terms as a whole.
    static let currentVersion = "2026-08-03"
    static let rightsAttestationVersion = "2026-07-22"

    static let appleStandardEULAURL = URL(
        string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"
    )!
}

struct TranslationTermsAcceptance: Equatable {
    let id: UUID
    let acceptedAt: Date
    let localeIdentifier: String
}

enum DetectedBookLanguage: Equatable {
    case language(code: String, name: String, confidence: Double)
    case unknown

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

struct TranslationJob: Codable, Equatable, Identifiable {
    var id: UUID { bookID }

    let bookID: UUID
    var bookTitle: String
    var targetLanguage: TranslationTargetLanguage
    var phase: TranslationJobPhase
    var attestedAt: Date?
    var acceptedTermsVersion: String?
    var termsAcceptanceID: UUID?
    var termsAcceptanceLocale: String?
    var acceptedAIProcessingVersion: String?
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
        case acceptedTermsVersion, termsAcceptanceID, termsAcceptanceLocale
        case acceptedAIProcessingVersion
        case backendJobID, activeRequestKind
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
        acceptedTermsVersion = try c.decodeIfPresent(
            String.self, forKey: .acceptedTermsVersion
        )
        termsAcceptanceID = try c.decodeIfPresent(
            UUID.self, forKey: .termsAcceptanceID
        )
        termsAcceptanceLocale = try c.decodeIfPresent(
            String.self, forKey: .termsAcceptanceLocale
        )
        acceptedAIProcessingVersion = try c.decodeIfPresent(
            String.self, forKey: .acceptedAIProcessingVersion
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
        acceptedTermsVersion: String? = nil,
        termsAcceptanceID: UUID? = nil,
        termsAcceptanceLocale: String? = nil,
        acceptedAIProcessingVersion: String? = nil,
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
        self.acceptedTermsVersion = acceptedTermsVersion
        self.termsAcceptanceID = termsAcceptanceID
        self.termsAcceptanceLocale = termsAcceptanceLocale
        self.acceptedAIProcessingVersion = acceptedAIProcessingVersion
        self.backendJobID = backendJobID
        self.activeRequestKind = activeRequestKind
        self.previewCompletedAt = previewCompletedAt
        self.fullCompletedAt = fullCompletedAt
        self.translatedChunks = translatedChunks
        self.totalChunks = totalChunks
        self.errorMessage = errorMessage
        self.updatedAt = updatedAt
    }
}
