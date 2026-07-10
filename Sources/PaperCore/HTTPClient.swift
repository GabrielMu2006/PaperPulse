import Foundation

public struct HTTPResponse: Sendable {
    public var data: Data
    public var statusCode: Int
    public var mimeType: String?
    public var finalURL: URL

    public init(data: Data, statusCode: Int, mimeType: String?, finalURL: URL) {
        self.data = data
        self.statusCode = statusCode
        self.mimeType = mimeType
        self.finalURL = finalURL
    }
}

public protocol HTTPClient {
    func perform(_ request: URLRequest) async throws -> HTTPResponse
}

public struct URLSessionHTTPClient: HTTPClient {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func perform(_ request: URLRequest) async throws -> HTTPResponse {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        return HTTPResponse(
            data: data,
            statusCode: http.statusCode,
            mimeType: http.mimeType,
            finalURL: http.url ?? request.url!
        )
    }
}

extension HTTPResponse {
    func requireSuccess() throws {
        guard (200..<300).contains(statusCode) else {
            throw HTTPError.nonSuccessStatus(statusCode)
        }
    }
}

public enum HTTPError: Error, Equatable {
    case nonSuccessStatus(Int)
}
