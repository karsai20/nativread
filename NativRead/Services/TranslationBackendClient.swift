import AuthenticationServices
import Foundation
import Observation
import Security

struct TranslationBackendClient: Sendable {
    enum ClientError: LocalizedError, Equatable {
        case invalidBackendURL
        case unsupportedFormat
        case server(String)
        case invalidResponse
        case failedStatus(String)
        case timeout

        var errorDescription: String? {
            switch self {
            case .invalidBackendURL:
                return "Set the translator backend URL in Settings first."
            case .unsupportedFormat:
                return "Only EPUB books can be translated right now."
            case .server(let message):
                return message
            case .invalidResponse:
                return "The translator backend returned an invalid response."
            case .failedStatus(let message):
                return message
            case .timeout:
                return "The translation did not finish in time."
            }
        }
    }

    struct UploadResponse: Decodable, Equatable, Sendable {
        struct Quote: Decodable, Equatable, Sendable {
            let version: String
            let sourceCharacters: Int
            let requiredCredits: Int
            let charactersPerCredit: Int
        }

        /// The App Store product this book is sold as. The tier is chosen
        /// server-side from the source length; the app never computes a price.
        struct Price: Decodable, Equatable, Sendable {
            let productId: String
            let tier: Int
            let sourceCharacters: Int
        }

        let id: String
        let title: String?
        let spineItemCount: Int?
        let provider: String?
        let alreadyTranslated: Bool?
        let sourceHash: String?
        let entitledLanguages: [String]?
        let quote: Quote?
        let price: Price?
    }

    struct StartResponse: Decodable, Equatable, Sendable {
        let ok: Bool
    }

    struct SessionResponse: Decodable, Equatable, Sendable {
        let token: String
        let expiresIn: Int
        /// Attached to every StoreKit purchase so Apple signs the account into
        /// the receipt itself.
        let appAccountToken: String?
    }

    struct PurchaseResponse: Decodable, Equatable, Sendable {
        let ok: Bool
        let applied: Bool
        let entitledLanguages: [String]?
    }

    struct StatusResponse: Decodable, Equatable, Sendable {
        struct Chunks: Decodable, Equatable, Sendable {
            let total: Int
            let done: Int
        }

        let id: String
        let status: String
        let title: String?
        let chunks: Chunks?
        let error: String?
    }

    var baseURL: URL
    var userID: String? = nil
    var bearerToken: String? = nil
    var session: URLSession = .shared

    func exchangeAppleIdentityToken(_ identityToken: String) async throws -> SessionResponse {
        var request = makeRequest(path: "api/auth/apple")
        request.httpMethod = "POST"
        request.setValue("Bearer \(identityToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        return try decode(SessionResponse.self, from: data, response: response)
    }

    /// Permanently deletes the authenticated backend account and its
    /// associated data. The backend owns Sign in with Apple token revocation
    /// because the client never receives or stores Apple's server refresh
    /// token.
    func deleteAccount(
        appleIdentityToken: String,
        appleAuthorizationCode: String
    ) async throws {
        var request = makeRequest(path: "api/account")
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(
            withJSONObject: [
                "appleIdentityToken": appleIdentityToken,
                "appleAuthorizationCode": appleAuthorizationCode
            ]
        )
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
    }

    /// Uploads the book so the backend can quote it. `onProgress` receives the
    /// sent fraction (0...1) so the caller can say more than "please wait":
    /// this is the slowest step in the whole quote, and a whole book goes over
    /// the wire before the price comes back.
    func upload(
        epubURL: URL,
        onProgress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> UploadResponse {
        var request = makeRequest(path: "api/upload")
        request.httpMethod = "POST"
        request.setValue("application/epub+zip", forHTTPHeaderField: "Content-Type")

        var progressDelegate: UploadProgressDelegate?
        if let onProgress {
            progressDelegate = UploadProgressDelegate(onProgress: onProgress)
        }
        // `fromFile` streams off disk. Reading a 32 MB book into a Data first
        // spikes memory by its whole size for no gain.
        let (data, response) = try await session.upload(
            for: request, fromFile: epubURL, delegate: progressDelegate
        )
        return try decode(UploadResponse.self, from: data, response: response)
    }

    /// Hands a StoreKit transaction to the backend, which verifies it with
    /// Apple before granting the book. Only a success here means the purchase
    /// is safe to finish.
    func confirmPurchase(
        jobID: String,
        transactionID: String
    ) async throws -> PurchaseResponse {
        var request = makeRequest(path: "api/purchase")
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(
            withJSONObject: [
                "id": jobID,
                "transactionId": transactionID
            ]
        )
        let (data, response) = try await session.data(for: request)
        return try decode(PurchaseResponse.self, from: data, response: response)
    }

    func start(
        jobID: String,
        sample: Bool,
        sourceLanguage: String? = nil,
        targetLanguage: TranslationTargetLanguage = .hu,
        termsAcceptance: TranslationTermsAcceptance
    ) async throws {
        var request = makeRequest(path: "api/translate")
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(
            withJSONObject: [
                "id": jobID,
                "sample": sample,
                "targetLanguage": targetLanguage.rawValue,
                // Detected on device; the backend re-detects and validates the
                // pair, so this is a hint, never a trusted input. Omitted when
                // detection came up empty, which the backend reads as English.
                "sourceLanguage": sourceLanguage ?? DetectedBookLanguage.defaultSourceCode,
                // Keep the legacy field until the backend contract migrates;
                // the accepted Terms contain the same book-rights rule.
                "rightsAttested": true,
                "termsAccepted": true,
                "termsVersion": TranslationTerms.currentVersion,
                "termsAcceptance": [
                    "id": termsAcceptance.id.uuidString.lowercased(),
                    "acceptedAt": ISO8601DateFormatter().string(
                        from: termsAcceptance.acceptedAt
                    ),
                    "locale": termsAcceptance.localeIdentifier,
                    "method": "ios-clickwrap",
                    "statementVersion":
                        TranslationTerms.rightsAttestationVersion
                ],
                "aiProcessingConsent": true,
                "aiConsentVersion":
                    TranslationPrivacy.currentAIConsentVersion,
                "aiProvider": TranslationPrivacy.aiProviderName
            ]
        )
        let (data, response) = try await session.data(for: request)
        let start = try decode(StartResponse.self, from: data, response: response)
        guard start.ok else {
            throw ClientError.server("The translator backend rejected the job.")
        }
    }

    func status(jobID: String) async throws -> StatusResponse {
        var components = URLComponents(
            url: endpoint("api/status"), resolvingAgainstBaseURL: false
        )
        components?.queryItems = [URLQueryItem(name: "id", value: jobID)]
        guard let url = components?.url else {
            throw ClientError.invalidBackendURL
        }
        let (data, response) = try await session.data(
            for: makeRequest(url: url)
        )
        return try decode(StatusResponse.self, from: data, response: response)
    }

    func waitUntilDone(
        jobID: String,
        pollInterval: Duration = .seconds(1),
        timeout: Duration = .seconds(3600),
        maxConsecutiveFailures: Int = 8,
        onStatus: @escaping (StatusResponse) async -> Void = { _ in }
    ) async throws -> StatusResponse {
        let start = ContinuousClock.now
        var consecutiveFailures = 0
        while start.duration(to: .now) < timeout {
            let current: StatusResponse
            do {
                current = try await status(jobID: jobID)
                consecutiveFailures = 0
            } catch {
                // A single poll failing (Wi-Fi roam, screen lock, backend
                // restart) must not fail an hour-long job while the backend
                // keeps translating. Tolerate a run of blips, then give up.
                consecutiveFailures += 1
                if consecutiveFailures >= maxConsecutiveFailures { throw error }
                try await Task.sleep(for: pollInterval)
                continue
            }
            await onStatus(current)
            switch current.status {
            case "done":
                return current
            case "error", "cancelled", "failed":
                throw ClientError.failedStatus(
                    current.error ?? "Translation failed."
                )
            default:
                try await Task.sleep(for: pollInterval)
            }
        }
        throw ClientError.timeout
    }

    func downloadResult(jobID: String) async throws -> Data {
        var components = URLComponents(
            url: endpoint("api/result"), resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "id", value: jobID),
            URLQueryItem(name: "download", value: "1"),
            // The server buffers the finished EPUB into this response, then
            // removes both the uploaded source and its translated copy. The
            // imported book lives only in the user's local NativRead library.
            URLQueryItem(name: "consume", value: "1")
        ]
        guard let url = components?.url else {
            throw ClientError.invalidBackendURL
        }
        let (data, response) = try await session.data(
            for: makeRequest(url: url)
        )
        try validate(response: response, data: data)
        return data
    }

    private func endpoint(_ path: String) -> URL {
        path.split(separator: "/").reduce(baseURL) { partialURL, component in
            partialURL.appendingPathComponent(String(component))
        }
    }

    private func makeRequest(path: String) -> URLRequest {
        makeRequest(url: endpoint(path))
    }

    private func makeRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        if let bearerToken, !bearerToken.isEmpty {
            request.setValue(
                "Bearer \(bearerToken)", forHTTPHeaderField: "Authorization"
            )
        } else if let userID, !userID.isEmpty {
            request.setValue(userID, forHTTPHeaderField: "x-nativread-user-id")
        }
        return request
    }

    private func decode<T: Decodable>(
        _ type: T.Type, from data: Data, response: URLResponse
    ) throws -> T {
        try validate(response: response, data: data)
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw ClientError.invalidResponse
        }
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw ClientError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? JSONDecoder().decode(
                BackendError.self, from: data
            ).error) ?? HTTPURLResponse.localizedString(
                forStatusCode: http.statusCode
            )
            throw ClientError.server(message)
        }
    }

    private struct BackendError: Decodable {
        let error: String
    }
}

/// Reports how much of the book has gone over the wire. `URLSession` calls
/// this on its own delegate queue, so the closure must be safe to invoke off
/// the main actor — callers hop back themselves.
private final class UploadProgressDelegate: NSObject, URLSessionTaskDelegate, Sendable {
    private let onProgress: @Sendable (Double) -> Void

    init(onProgress: @escaping @Sendable (Double) -> Void) {
        self.onProgress = onProgress
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didSendBodyData bytesSent: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64
    ) {
        // Chunked or unknown-length bodies report -1; there is no fraction to
        // show then, and dividing by it would report nonsense progress.
        guard totalBytesExpectedToSend > 0 else { return }
        let fraction = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
        onProgress(min(max(fraction, 0), 1))
    }
}

@MainActor
@Observable
final class TranslationAuthStore {
    private(set) var sessionToken: String?
    /// The UUID the backend expects on every StoreKit purchase.
    private(set) var appAccountToken: UUID?
    private(set) var isSigningIn = false
    private(set) var isDeletingAccount = false
    private(set) var errorMessage: String?
    private(set) var accountDeletionErrorMessage: String?

    private let keychain = TranslationSessionKeychain()

    init(initialSessionToken: String? = nil) {
        if let initialSessionToken, !initialSessionToken.isEmpty {
            sessionToken = initialSessionToken
            return
        }
        guard let record = keychain.load(), record.expiresAt > .now else {
            keychain.delete()
            return
        }
        sessionToken = record.token
        appAccountToken = record.appAccountToken.flatMap(UUID.init(uuidString:))
    }

    var isSignedIn: Bool { sessionToken != nil }

    func completeAppleSignIn(
        _ result: Result<ASAuthorization, Error>,
        backendURL: URL
    ) async {
        isSigningIn = true
        errorMessage = nil
        defer { isSigningIn = false }

        do {
            let authorization = try result.get()
            guard let credential = authorization.credential
                    as? ASAuthorizationAppleIDCredential,
                  let identityData = credential.identityToken,
                  let identityToken = String(
                    data: identityData, encoding: .utf8
                  )
            else {
                throw TranslationBackendClient.ClientError.invalidResponse
            }

            let response = try await TranslationBackendClient(baseURL: backendURL)
                .exchangeAppleIdentityToken(identityToken)
            let record = TranslationSessionRecord(
                token: response.token,
                expiresAt: .now.addingTimeInterval(
                    TimeInterval(response.expiresIn)
                ),
                appAccountToken: response.appAccountToken
            )
            try keychain.save(record)
            sessionToken = response.token
            appAccountToken = response.appAccountToken
                .flatMap(UUID.init(uuidString:))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signOut() {
        keychain.delete()
        sessionToken = nil
        appAccountToken = nil
        errorMessage = nil
        accountDeletionErrorMessage = nil
    }

    /// Returns only after the backend confirms permanent deletion. A network
    /// or server failure keeps the local session so the reader can retry and
    /// is never falsely told that the account was erased.
    func deleteAccount(
        _ result: Result<ASAuthorization, Error>,
        backendURL: URL
    ) async -> Bool {
        guard let sessionToken else {
            accountDeletionErrorMessage = "Sign in again before deleting your account."
            return false
        }

        isDeletingAccount = true
        accountDeletionErrorMessage = nil
        defer { isDeletingAccount = false }

        do {
            let authorization = try result.get()
            guard let credential = authorization.credential
                    as? ASAuthorizationAppleIDCredential,
                  let identityData = credential.identityToken,
                  let authorizationCodeData = credential.authorizationCode,
                  let identityToken = String(
                    data: identityData, encoding: .utf8
                  ),
                  let authorizationCode = String(
                    data: authorizationCodeData, encoding: .utf8
                  )
            else {
                throw TranslationBackendClient.ClientError.invalidResponse
            }
            try await TranslationBackendClient(
                baseURL: backendURL,
                bearerToken: sessionToken
            ).deleteAccount(
                appleIdentityToken: identityToken,
                appleAuthorizationCode: authorizationCode
            )
            signOut()
            return true
        } catch {
            accountDeletionErrorMessage = error.localizedDescription
            return false
        }
    }
}

private struct TranslationSessionRecord: Codable {
    let token: String
    let expiresAt: Date
    /// Absent for sessions minted before per-book purchases existed.
    var appAccountToken: String?
}

private struct TranslationSessionKeychain {
    private let service = "com.karsai.nativread.translation-session"
    private let account = "backend"

    func load() -> TranslationSessionRecord? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data
        else { return nil }
        return try? JSONDecoder().decode(TranslationSessionRecord.self, from: data)
    }

    func save(_ record: TranslationSessionRecord) throws {
        let data = try JSONEncoder().encode(record)
        let attributes = [kSecValueData as String: data]
        let status = SecItemUpdate(
            baseQuery as CFDictionary, attributes as CFDictionary
        )
        if status == errSecItemNotFound {
            var query = baseQuery
            query[kSecValueData as String] = data
            query[kSecAttrAccessible as String] =
                kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let addStatus = SecItemAdd(query as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError(status: addStatus)
            }
        } else if status != errSecSuccess {
            throw KeychainError(status: status)
        }
    }

    func delete() {
        SecItemDelete(baseQuery as CFDictionary)
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    private struct KeychainError: LocalizedError {
        let status: OSStatus

        var errorDescription: String? {
            SecCopyErrorMessageString(status, nil) as String?
                ?? "Could not store the secure login session."
        }
    }
}
