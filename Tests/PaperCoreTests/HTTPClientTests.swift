import Foundation
import XCTest
@testable import PaperCore

final class HTTPClientTests: XCTestCase {
    override func tearDown() {
        HTTPClientURLProtocol.handler = nil
        super.tearDown()
    }

    func testResponseNormalizesHeadersAndAppliesConfiguredTimeout() async throws {
        let observedTimeout = LockedValue<TimeInterval?>(nil)
        HTTPClientURLProtocol.handler = { request in
            observedTimeout.set(request.timeoutInterval)
            return .success((
                Data("ok".utf8),
                HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["X-Rate-Limit": "10", "Content-Type": "application/json"]
                )!
            ))
        }
        let client = URLSessionHTTPClient(
            session: makeSession(),
            timeout: 12,
            retryPolicy: HTTPRetryPolicy(maximumRetryCount: 0)
        )

        let response = try await client.perform(URLRequest(url: URL(string: "https://example.com/papers")!))

        XCTAssertEqual(observedTimeout.value, 12)
        XCTAssertEqual(response.headers["x-rate-limit"], "10")
        XCTAssertEqual(response.headers["content-type"], "application/json")
    }

    func testRetriesRateLimitAndServerErrorsUsingInjectedSleeper() async throws {
        let statuses = LockedValue([429, 503, 200])
        let delays = LockedValue([TimeInterval]())
        HTTPClientURLProtocol.handler = { request in
            let status = statuses.removeFirst()
            return .success((
                Data("attempt \(status)".utf8),
                HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            ))
        }
        let client = URLSessionHTTPClient(
            session: makeSession(),
            retryPolicy: HTTPRetryPolicy(maximumRetryCount: 2, baseDelay: 0.25),
            sleep: { delay in delays.append(delay) }
        )

        let response = try await client.perform(URLRequest(url: URL(string: "https://example.com/papers")!))

        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(delays.value, [0.25, 0.5])
    }

    func testRetryExhaustionReturnsFinalHTTPResponse() async throws {
        let statuses = LockedValue([503, 503])
        HTTPClientURLProtocol.handler = { request in
            let status = statuses.removeFirst()
            return .success((
                Data(),
                HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            ))
        }
        let client = URLSessionHTTPClient(
            session: makeSession(),
            retryPolicy: HTTPRetryPolicy(maximumRetryCount: 1),
            sleep: { _ in }
        )

        let response = try await client.perform(URLRequest(url: URL(string: "https://example.com/papers")!))

        XCTAssertEqual(response.statusCode, 503)
    }

    func testTransportFailuresAreTypedForTimeoutAndCancellation() async {
        HTTPClientURLProtocol.handler = { _ in .failure(URLError(.timedOut)) }
        let timeoutClient = URLSessionHTTPClient(session: makeSession())

        await XCTAssertThrowsErrorAsync(
            try await timeoutClient.perform(URLRequest(url: URL(string: "https://example.com/timeout")!))
        ) { error in
            XCTAssertEqual(error as? HTTPError, .timeout)
        }

        HTTPClientURLProtocol.handler = { request in
            .success((
                Data(),
                HTTPURLResponse(url: request.url!, statusCode: 429, httpVersion: nil, headerFields: nil)!
            ))
        }
        let cancelledClient = URLSessionHTTPClient(
            session: makeSession(),
            retryPolicy: HTTPRetryPolicy(maximumRetryCount: 1),
            sleep: { _ in throw CancellationError() }
        )

        await XCTAssertThrowsErrorAsync(
            try await cancelledClient.perform(URLRequest(url: URL(string: "https://example.com/cancelled")!))
        ) { error in
            XCTAssertEqual(error as? HTTPError, .cancelled)
        }
    }

    func testCancelledTaskFailsBeforeStartingURLSessionTransport() async {
        let receivedRequest = LockedValue(false)
        HTTPClientURLProtocol.handler = { _ in
            receivedRequest.set(true)
            return .failure(URLError(.badServerResponse))
        }
        let client = URLSessionHTTPClient(session: makeSession())
        let task = Task {
            await Task.yield()
            return try await client.perform(URLRequest(url: URL(string: "https://example.com/cancelled-before-start")!))
        }

        task.cancel()

        await XCTAssertThrowsErrorAsync(try await task.value) { error in
            XCTAssertEqual(error as? HTTPError, .cancelled)
        }
        XCTAssertFalse(receivedRequest.value)
    }

    func testRetryDelayRemainsFiniteForLargeRetryAttempts() {
        let policy = HTTPRetryPolicy(maximumRetryCount: .max, baseDelay: 1)

        let delay = policy.delay(forRetryAttempt: .max)

        XCTAssertTrue(delay.isFinite)
        XCTAssertGreaterThanOrEqual(delay, 0)
        XCTAssertLessThanOrEqual(delay, policy.maximumDelay)
    }

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [HTTPClientURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

private final class LockedValue<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: Value

    init(_ value: Value) {
        storage = value
    }

    var value: Value {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func set(_ value: Value) {
        lock.lock()
        storage = value
        lock.unlock()
    }
}

private extension LockedValue where Value == [Int] {
    func removeFirst() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return storage.removeFirst()
    }
}

private extension LockedValue where Value == [TimeInterval] {
    func append(_ value: TimeInterval) {
        lock.lock()
        storage.append(value)
        lock.unlock()
    }
}

private final class HTTPClientURLProtocol: URLProtocol, @unchecked Sendable {
    typealias Handler = @Sendable (URLRequest) -> Result<(Data, HTTPURLResponse), Error>

    nonisolated(unsafe) static var handler: Handler?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        switch handler(request) {
        case let .success((data, response)):
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        case let .failure(error):
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
