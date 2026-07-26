import XCTest
@testable import NativRead

/// Offline coverage for `TranslationBackendClient` via a `URLProtocol` stub.
/// The client injects its `URLSession`, so every request/response path — error
/// bodies, malformed JSON, and the `waitUntilDone` polling loop — is testable
/// without a live backend.
final class TranslationBackendClientTests: XCTestCase {

    private func makeClient() -> TranslationBackendClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return TranslationBackendClient(
            baseURL: URL(string: "http://backend.test")!,
            userID: "user-1",
            session: URLSession(configuration: config)
        )
    }

    private func makeTermsAcceptance() -> TranslationTermsAcceptance {
        TranslationTermsAcceptance(
            id: UUID(uuidString: "018F6F4D-90A7-7D8F-8F9A-1D4CF6B9A021")!,
            acceptedAt: Date(timeIntervalSince1970: 1_753_184_400),
            localeIdentifier: "hu-HU"
        )
    }

    override func tearDown() {
        StubURLProtocol.responses = []
        StubURLProtocol.lastRequest = nil
        super.tearDown()
    }

    // MARK: - Response validation

    func testStatusDecodesValidResponse() async throws {
        StubURLProtocol.enqueue(
            200, #"{"id":"j","status":"translating","chunks":{"total":4,"done":1}}"#
        )
        let status = try await makeClient().status(jobID: "j")
        XCTAssertEqual(status.status, "translating")
        XCTAssertEqual(status.chunks?.done, 1)
    }

    func testServerErrorBodySurfacesMessage() async {
        StubURLProtocol.enqueue(500, #"{"error":"boom"}"#)
        do {
            _ = try await makeClient().status(jobID: "j")
            XCTFail("expected .server")
        } catch let error as TranslationBackendClient.ClientError {
            XCTAssertEqual(error, .server("boom"))
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testMalformedJSONThrowsInvalidResponse() async {
        StubURLProtocol.enqueue(200, "not json at all")
        do {
            _ = try await makeClient().status(jobID: "j")
            XCTFail("expected .invalidResponse")
        } catch let error as TranslationBackendClient.ClientError {
            XCTAssertEqual(error, .invalidResponse)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testUploadSendsUserIDHeaderAndRawEpubBody() async throws {
        StubURLProtocol.enqueue(
            200,
            #"{"id":"job-9","sourceHash":"abc","quote":{"version":"source-chars-v1","sourceCharacters":1001,"requiredCredits":2,"charactersPerCredit":1000}}"#
        )
        let epub = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).epub")
        try Data("PK\u{03}\u{04}fake".utf8).write(to: epub)
        defer { try? FileManager.default.removeItem(at: epub) }

        let response = try await makeClient().upload(epubURL: epub)
        XCTAssertEqual(response.id, "job-9")
        XCTAssertEqual(response.sourceHash, "abc")
        XCTAssertEqual(response.quote?.sourceCharacters, 1_001)
        XCTAssertEqual(response.quote?.requiredCredits, 2)
        let request = try XCTUnwrap(StubURLProtocol.lastRequest)
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "x-nativread-user-id"), "user-1"
        )
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "Content-Type"),
            "application/epub+zip"
        )
    }

    func testBearerSessionReplacesAnonymousUserHeader() async throws {
        StubURLProtocol.enqueue(200, #"{"id":"job-9"}"#)
        let epub = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).epub")
        try Data("PK\u{03}\u{04}fake".utf8).write(to: epub)
        defer { try? FileManager.default.removeItem(at: epub) }

        var client = makeClient()
        client.bearerToken = "signed-session"
        _ = try await client.upload(epubURL: epub)

        let request = try XCTUnwrap(StubURLProtocol.lastRequest)
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "Authorization"),
            "Bearer signed-session"
        )
        XCTAssertNil(request.value(forHTTPHeaderField: "x-nativread-user-id"))
    }

    func testAppleIdentityTokenIsExchangedForBackendSession() async throws {
        StubURLProtocol.enqueue(
            200, #"{"token":"backend-session","expiresIn":2592000}"#
        )

        let response = try await makeClient()
            .exchangeAppleIdentityToken("apple-id-token")

        XCTAssertEqual(response.token, "backend-session")
        XCTAssertEqual(response.expiresIn, 2_592_000)
        let request = try XCTUnwrap(StubURLProtocol.lastRequest)
        XCTAssertEqual(request.url?.path, "/api/auth/apple")
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "Authorization"),
            "Bearer apple-id-token"
        )
    }

    func testDeleteAccountUsesAuthenticatedDeleteEndpoint() async throws {
        StubURLProtocol.enqueue(204, "")
        var client = makeClient()
        client.userID = nil
        client.bearerToken = "signed-session"

        try await client.deleteAccount(
            appleIdentityToken: "fresh-apple-token",
            appleAuthorizationCode: "one-time-code"
        )

        let request = try XCTUnwrap(StubURLProtocol.lastRequest)
        XCTAssertEqual(request.url?.path, "/api/account")
        XCTAssertEqual(request.httpMethod, "DELETE")
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "Authorization"),
            "Bearer signed-session"
        )
        XCTAssertNil(request.value(forHTTPHeaderField: "x-nativread-user-id"))
        let body = try XCTUnwrap(request.httpBodyStreamData)
        let json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: body) as? [String: String]
        )
        XCTAssertEqual(json["appleIdentityToken"], "fresh-apple-token")
        XCTAssertEqual(json["appleAuthorizationCode"], "one-time-code")
    }

    func testCreditsDecodeAndPlaceholderPurchaseSendsTransaction() async throws {
        StubURLProtocol.enqueue(
            200,
            #"{"account":{"balance":248,"purchasedCredits":250,"reservedCredits":0,"spentCredits":2},"products":[{"productId":"com.karsai.nativread.credits.250","credits":250}]}"#
        )
        let credits = try await makeClient().credits()
        XCTAssertEqual(credits.account.balance, 248)
        XCTAssertEqual(credits.products.first?.credits, 250)
        XCTAssertEqual(StubURLProtocol.lastRequest?.url?.path, "/api/credits")

        StubURLProtocol.enqueue(
            200,
            #"{"ok":true,"applied":true,"account":{"balance":250,"purchasedCredits":250,"reservedCredits":0,"spentCredits":0}}"#
        )
        let purchase = try await makeClient().grantPlaceholderCredits(
            transactionID: "test-tx", productID: "com.karsai.nativread.credits.250"
        )
        XCTAssertTrue(purchase.applied)
        XCTAssertEqual(purchase.account.balance, 250)
        let request = try XCTUnwrap(StubURLProtocol.lastRequest)
        XCTAssertEqual(request.url?.path, "/api/credits/purchase")
        let body = try XCTUnwrap(request.httpBodyStreamData)
        let json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: body) as? [String: String]
        )
        XCTAssertEqual(json["transactionId"], "test-tx")
        XCTAssertEqual(
            json["productId"], "com.karsai.nativread.credits.250"
        )
    }

    func testDownloadConsumesServerCopy() async throws {
        StubURLProtocol.enqueue(200, "translated epub")

        let data = try await makeClient().downloadResult(jobID: "job-9")

        XCTAssertEqual(String(decoding: data, as: UTF8.self), "translated epub")
        let request = try XCTUnwrap(StubURLProtocol.lastRequest)
        let components = try XCTUnwrap(
            URLComponents(url: request.url!, resolvingAgainstBaseURL: false)
        )
        let query = Dictionary(
            uniqueKeysWithValues: (components.queryItems ?? []).map {
                ($0.name, $0.value)
            }
        )
        XCTAssertEqual(query["id"]!, "job-9")
        XCTAssertEqual(query["download"]!, "1")
        XCTAssertEqual(query["consume"]!, "1")
    }

    // MARK: - waitUntilDone polling

    func testStartThrowsWhenBackendReturnsNotOK() async {
        // HTTP 200 but {"ok":false} must fail fast, not silently proceed to poll.
        StubURLProtocol.enqueue(200, #"{"ok":false}"#)
        do {
            try await makeClient().start(
                jobID: "j",
                sample: false,
                termsAcceptance: makeTermsAcceptance()
            )
            XCTFail("expected .server rejection")
        } catch let error as TranslationBackendClient.ClientError {
            guard case .server = error else {
                return XCTFail("unexpected ClientError: \(error)")
            }
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testStartSucceedsWhenBackendReturnsOK() async throws {
        StubURLProtocol.enqueue(200, #"{"ok":true}"#)
        try await makeClient().start(
            jobID: "j",
            sample: false,
            targetLanguage: .de,
            termsAcceptance: makeTermsAcceptance()
        )

        let request = try XCTUnwrap(StubURLProtocol.lastRequest)
        let body = try XCTUnwrap(request.httpBodyStreamData)
        let json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: body) as? [String: Any]
        )
        XCTAssertEqual(json["id"] as? String, "j")
        XCTAssertEqual(json["sample"] as? Bool, false)
        XCTAssertEqual(json["targetLanguage"] as? String, "de")
        XCTAssertEqual(json["rightsAttested"] as? Bool, true)
        XCTAssertEqual(json["termsAccepted"] as? Bool, true)
        XCTAssertEqual(
            json["termsVersion"] as? String,
            TranslationTerms.currentVersion
        )
        let acceptance = try XCTUnwrap(
            json["termsAcceptance"] as? [String: Any]
        )
        XCTAssertEqual(
            acceptance["id"] as? String,
            "018f6f4d-90a7-7d8f-8f9a-1d4cf6b9a021"
        )
        XCTAssertEqual(acceptance["locale"] as? String, "hu-HU")
        XCTAssertEqual(acceptance["method"] as? String, "ios-clickwrap")
        XCTAssertEqual(
            acceptance["statementVersion"] as? String,
            TranslationTerms.rightsAttestationVersion
        )
        XCTAssertNotNil(acceptance["acceptedAt"] as? String)
        XCTAssertEqual(json["aiProcessingConsent"] as? Bool, true)
        XCTAssertEqual(
            json["aiConsentVersion"] as? String,
            TranslationPrivacy.currentAIConsentVersion
        )
        XCTAssertEqual(
            json["aiProvider"] as? String,
            TranslationPrivacy.aiProviderName
        )
    }

    func testWaitUntilDoneReturnsOnDone() async throws {
        StubURLProtocol.enqueue(200, #"{"id":"j","status":"translating"}"#)
        StubURLProtocol.enqueue(200, #"{"id":"j","status":"done"}"#)
        let final = try await makeClient().waitUntilDone(
            jobID: "j", pollInterval: .milliseconds(1)
        )
        XCTAssertEqual(final.status, "done")
    }

    func testWaitUntilDoneThrowsOnErrorStatus() async {
        StubURLProtocol.enqueue(
            200, #"{"id":"j","status":"error","error":"backend exploded"}"#
        )
        do {
            _ = try await makeClient().waitUntilDone(
                jobID: "j", pollInterval: .milliseconds(1)
            )
            XCTFail("expected .failedStatus")
        } catch let error as TranslationBackendClient.ClientError {
            XCTAssertEqual(error, .failedStatus("backend exploded"))
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testWaitUntilDoneTimesOutOnUnknownStatus() async {
        // An unrecognized status must not poll forever; the timeout wins.
        StubURLProtocol.responder = { _ in
            (200, Data(#"{"id":"j","status":"mystery"}"#.utf8))
        }
        defer { StubURLProtocol.responder = nil }
        do {
            _ = try await makeClient().waitUntilDone(
                jobID: "j", pollInterval: .milliseconds(1),
                timeout: .milliseconds(30)
            )
            XCTFail("expected .timeout")
        } catch let error as TranslationBackendClient.ClientError {
            XCTAssertEqual(error, .timeout)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testWaitUntilDoneToleratesTransientFailuresThenSucceeds() async throws {
        // Two poll failures (network blips) followed by done: the job survives.
        var callCount = 0
        StubURLProtocol.responder = { _ in
            callCount += 1
            if callCount <= 2 { return (503, Data(#"{"error":"blip"}"#.utf8)) }
            return (200, Data(#"{"id":"j","status":"done"}"#.utf8))
        }
        defer { StubURLProtocol.responder = nil }
        let final = try await makeClient().waitUntilDone(
            jobID: "j", pollInterval: .milliseconds(1), maxConsecutiveFailures: 5
        )
        XCTAssertEqual(final.status, "done")
    }

    func testWaitUntilDonePropagatesAfterTooManyFailures() async {
        StubURLProtocol.responder = { _ in (503, Data(#"{"error":"down"}"#.utf8)) }
        defer { StubURLProtocol.responder = nil }
        do {
            _ = try await makeClient().waitUntilDone(
                jobID: "j", pollInterval: .milliseconds(1),
                maxConsecutiveFailures: 3
            )
            XCTFail("expected an error to propagate")
        } catch let error as TranslationBackendClient.ClientError {
            XCTAssertEqual(error, .server("down"))
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }
}

/// Minimal `URLProtocol` that replays queued (statusCode, body) pairs, or a
/// dynamic `responder` closure when the request count is open-ended (polling).
final class StubURLProtocol: URLProtocol {
    static var responses: [(Int, Data)] = []
    static var responder: ((URLRequest) -> (Int, Data))?
    static var lastRequest: URLRequest?

    static func enqueue(_ status: Int, _ body: String) {
        responses.append((status, Data(body.utf8)))
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for r: URLRequest) -> URLRequest { r }

    override func startLoading() {
        Self.lastRequest = request
        let (status, data): (Int, Data)
        if let responder = Self.responder {
            (status, data) = responder(request)
        } else if !Self.responses.isEmpty {
            (status, data) = Self.responses.removeFirst()
        } else {
            (status, data) = (500, Data("no stub".utf8))
        }
        let response = HTTPURLResponse(
            url: request.url!, statusCode: status,
            httpVersion: nil, headerFields: nil
        )!
        client?.urlProtocol(
            self, didReceive: response, cacheStoragePolicy: .notAllowed
        )
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private extension URLRequest {
    var httpBodyStreamData: Data? {
        if let httpBody { return httpBody }
        guard let stream = httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1024)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            data.append(buffer, count: count)
        }
        return data
    }
}
