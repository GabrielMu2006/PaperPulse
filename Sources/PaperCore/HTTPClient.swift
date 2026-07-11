import Foundation

public struct HTTPResponse: Sendable {
    public var data: Data
    public var statusCode: Int
    public var mimeType: String?
    public var finalURL: URL
    public var headers: [String: String]

    public init(
        data: Data,
        statusCode: Int,
        mimeType: String?,
        finalURL: URL,
        headers: [String: String] = [:]
    ) {
        self.data = data
        self.statusCode = statusCode
        self.mimeType = mimeType
        self.finalURL = finalURL
        self.headers = headers.reduce(into: [:]) { normalized, header in
            normalized[header.key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()] = header.value
        }
    }
}

public protocol HTTPClient {
    func perform(_ request: URLRequest) async throws -> HTTPResponse
}

public typealias HTTPClientSleep = @Sendable (TimeInterval) async throws -> Void

public struct HTTPRetryPolicy: Hashable, Sendable {
    public var maximumRetryCount: Int
    public var baseDelay: TimeInterval
    public var maximumDelay: TimeInterval

    public init(
        maximumRetryCount: Int = 2,
        baseDelay: TimeInterval = 1,
        maximumDelay: TimeInterval = 60
    ) {
        self.maximumRetryCount = max(0, maximumRetryCount)
        self.baseDelay = max(0, baseDelay)
        self.maximumDelay = max(0, maximumDelay)
    }

    public func delay(forRetryAttempt retryAttempt: Int) -> TimeInterval {
        guard baseDelay > 0, maximumDelay > 0 else { return 0 }
        var delay = min(baseDelay, maximumDelay)
        var remainingDoublings = max(0, retryAttempt - 1)

        while remainingDoublings > 0, delay < maximumDelay {
            guard delay < maximumDelay / 2 else { return maximumDelay }
            delay *= 2
            remainingDoublings -= 1
        }
        return delay
    }
}

public struct URLSessionHTTPClient: HTTPClient {
    private let session: URLSession
    private let timeout: TimeInterval
    private let retryPolicy: HTTPRetryPolicy
    private let sleep: HTTPClientSleep

    public init(
        session: URLSession = .shared,
        timeout: TimeInterval = 30,
        retryPolicy: HTTPRetryPolicy = HTTPRetryPolicy(),
        sleep: @escaping HTTPClientSleep = { delay in
            let nanoseconds = UInt64(max(0, delay) * 1_000_000_000)
            try await Task.sleep(nanoseconds: nanoseconds)
        }
    ) {
        self.session = session
        self.timeout = max(0, timeout)
        self.retryPolicy = retryPolicy
        self.sleep = sleep
    }

    public func perform(_ request: URLRequest) async throws -> HTTPResponse {
        var request = request
        request.timeoutInterval = timeout
        var retryAttempt = 0

        while true {
            try throwIfCancelled()

            let data: Data
            let response: URLResponse
            do {
                (data, response) = try await session.data(for: request)
            } catch {
                throw transportFailure(for: error)
            }

            guard let http = response as? HTTPURLResponse else {
                throw HTTPError.transport(.badServerResponse)
            }
            guard let finalURL = http.url ?? request.url else {
                throw HTTPError.transport(.badURL)
            }

            let httpResponse = HTTPResponse(
                data: data,
                statusCode: http.statusCode,
                mimeType: http.mimeType,
                finalURL: finalURL,
                headers: normalizedHeaders(from: http)
            )
            guard shouldRetry(httpResponse.statusCode), retryAttempt < retryPolicy.maximumRetryCount else {
                return httpResponse
            }

            retryAttempt += 1
            do {
                try await sleep(retryPolicy.delay(forRetryAttempt: retryAttempt))
            } catch {
                throw transportFailure(for: error)
            }
        }
    }

    private func shouldRetry(_ statusCode: Int) -> Bool {
        statusCode == 429 || (500..<600).contains(statusCode)
    }

    private func normalizedHeaders(from response: HTTPURLResponse) -> [String: String] {
        response.allHeaderFields.reduce(into: [:]) { headers, header in
            headers[String(describing: header.key)] = String(describing: header.value)
        }
    }

    private func throwIfCancelled() throws {
        guard !Task.isCancelled else {
            throw HTTPError.cancelled
        }
    }

    private func transportFailure(for error: Error) -> HTTPError {
        if Task.isCancelled || error is CancellationError {
            return .cancelled
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .cancelled:
                return .cancelled
            case .timedOut:
                return .timeout
            default:
                return .transport(urlError.code)
            }
        }
        return .transport(.unknown)
    }
}

extension HTTPResponse {
    func requireSuccess() throws {
        guard (200..<300).contains(statusCode) else {
            throw HTTPError.nonSuccessStatus(statusCode)
        }
    }
}

public enum HTTPError: Error, Equatable, Sendable {
    case nonSuccessStatus(Int)
    case cancelled
    case timeout
    case transport(URLError.Code)
}

extension HTTPError {
    var technicalDescription: String {
        switch self {
        case .nonSuccessStatus(let status): "HTTP \(status)"
        case .cancelled: "request cancelled"
        case .timeout: "request timed out"
        case .transport(let code): "network transport \(code.rawValue)"
        }
    }

    public func userMessage(language: AppLanguage) -> String {
        switch self {
        case .nonSuccessStatus(let status) where status == 401 || status == 403:
            language.text(en: "The model service rejected the API key or model access.", zh: "模型服务拒绝了 API Key 或模型访问权限。")
        case .nonSuccessStatus(402):
            language.text(en: "The model service account has insufficient balance.", zh: "模型服务账户余额不足。")
        case .nonSuccessStatus(429):
            language.text(en: "The model service is rate-limiting requests. Please retry shortly.", zh: "模型服务请求过于频繁，请稍后重试。")
        case .nonSuccessStatus:
            language.text(en: "The model service could not complete this request. Please retry later.", zh: "模型服务暂时无法完成请求，请稍后重试。")
        case .cancelled:
            language.text(en: "The request was cancelled.", zh: "请求已取消。")
        case .timeout:
            language.text(en: "The model service took too long to respond. Please retry later.", zh: "模型服务响应超时，请稍后重试。")
        case .transport:
            language.text(en: "The connection to the model service was interrupted. Check the network or Base URL, then retry.", zh: "模型服务连接中断，请检查网络、Base URL 或稍后重试。")
        }
    }
}
