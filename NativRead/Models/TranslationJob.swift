import Foundation

enum TranslationTargetLanguage: String, Codable, CaseIterable, Equatable {
    case hu

    var displayName: String {
        switch self {
        case .hu: return "Hungarian"
        }
    }
}

enum TranslationJobPhase: String, Codable, Equatable {
    case draft
    case attested
    case previewQueued
    case uploading
    case translating
    case importingResult
    case finished
    case failed
    case waitingForBackend
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
