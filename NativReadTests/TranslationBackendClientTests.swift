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

    func testUploadSendsUserIDHeaderAndMultipartBody() async throws {
        StubURLProtocol.enqueue(200, #"{"id":"job-9"}"#)
        let epub = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).epub")
        try Data("PK\u{03}\u{04}fake".utf8).write(to: epub)
        defer { try? FileManager.default.removeItem(at: epub) }

        let response = try await makeClient().upload(epubURL: epub)
        XCTAssertEqual(response.id, "job-9")
        let request = try XCTUnwrap(StubURLProtocol.lastRequest)
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "x-nativread-user-id"), "user-1"
        )
        let contentType = request.value(forHTTPHeaderField: "Content-Type") ?? ""
        XCTAssertTrue(contentType.hasPrefix("multipart/form-data; boundary="))
    }

    // MARK: - waitUntilDone polling

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
