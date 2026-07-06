import Foundation

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
        let id: String
        let title: String?
        let spineItemCount: Int?
        let provider: String?
        let alreadyTranslated: Bool?
    }

    struct StartResponse: Decodable, Equatable, Sendable {
        let ok: Bool
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
    var session: URLSession = .shared

    func upload(epubURL: URL) async throws -> UploadResponse {
        let boundary = "nativread-\(UUID().uuidString)"
        var request = makeRequest(path: "api/upload")
        request.httpMethod = "POST"
        request.setValue(
            "multipart/form-data; boundary=\(boundary)",
            forHTTPHeaderField: "Content-Type"
        )

        let fileData = try Data(contentsOf: epubURL)
        let body = multipartBody(
            fieldName: "epub",
            fileName: epubURL.lastPathComponent,
            mimeType: "application/epub+zip",
            fileData: fileData,
            boundary: boundary
        )
        let (data, response) = try await session.upload(for: request, from: body)
        return try decode(UploadResponse.self, from: data, response: response)
    }

    func start(jobID: String, sample: Bool) async throws {
        var request = makeRequest(path: "api/translate")
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(
            withJSONObject: ["id": jobID, "sample": sample]
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
            URLQueryItem(name: "download", value: "1")
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
        if let userID, !userID.isEmpty {
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

    private func multipartBody(
        fieldName: String,
        fileName: String,
        mimeType: String,
        fileData: Data,
        boundary: String
    ) -> Data {
        var body = Data()
        body.append("--\(boundary)\r\n")
        body.append(
            "Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n"
        )
        body.append("Content-Type: \(mimeType)\r\n\r\n")
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n")
        return body
    }

    private struct BackendError: Decodable {
        let error: String
    }
}

private extension Data {
    mutating func append(_ string: String) {
        append(Data(string.utf8))
    }
}
