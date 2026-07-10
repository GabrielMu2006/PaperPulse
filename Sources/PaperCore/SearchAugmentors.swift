import Foundation

public enum SearchAugmentorError: Error, Equatable {
    case missingCapability
    case invalidResponse
}

public struct GLMWebSearchAugmentor: SearchAugmentor {
    private let apiKey: String
    private let httpClient: HTTPClient

    public init(apiKey: String, httpClient: HTTPClient = URLSessionHTTPClient()) {
        self.apiKey = apiKey
        self.httpClient = httpClient
    }

    public func augment(query: SearchQuery, limit: Int) async throws -> [WebSearchResult] {
        var request = URLRequest(url: URL(string: "https://open.bigmodel.cn/api/paas/v4/web_search")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode([
            "search_query": query.text,
            "count": String(limit),
            "search_engine": "search_pro"
        ])
        let response = try await httpClient.perform(request)
        try response.requireSuccess()
        return try CommonSearchDecoder.decode(response.data)
    }
}

public struct QwenWebSearchAugmentor: SearchAugmentor {
    private let provider: OpenAICompatibleChatProvider

    public init(provider: OpenAICompatibleChatProvider) {
        self.provider = provider
    }

    public func augment(query: SearchQuery, limit: Int) async throws -> [WebSearchResult] {
        guard provider.capabilities.contains(.webSearch) else {
            throw SearchAugmentorError.missingCapability
        }
        return []
    }
}

public struct KimiWebSearchAugmentor: SearchAugmentor {
    private let provider: OpenAICompatibleChatProvider

    public init(provider: OpenAICompatibleChatProvider) {
        self.provider = provider
    }

    public func augment(query: SearchQuery, limit: Int) async throws -> [WebSearchResult] {
        guard provider.capabilities.contains(.webSearch) else {
            throw SearchAugmentorError.missingCapability
        }
        return []
    }
}

public struct PerplexitySearchAugmentor: SearchAugmentor {
    private let apiKey: String
    private let httpClient: HTTPClient

    public init(apiKey: String, httpClient: HTTPClient = URLSessionHTTPClient()) {
        self.apiKey = apiKey
        self.httpClient = httpClient
    }

    public func augment(query: SearchQuery, limit: Int) async throws -> [WebSearchResult] {
        var request = URLRequest(url: URL(string: "https://api.perplexity.ai/search")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode([
            "query": query.text,
            "max_results": String(limit)
        ])
        let response = try await httpClient.perform(request)
        try response.requireSuccess()
        return try CommonSearchDecoder.decode(response.data)
    }
}

private enum CommonSearchDecoder {
    static func decode(_ data: Data) throws -> [WebSearchResult] {
        if let decoded = try? JSONDecoder().decode(SearchResultsEnvelope.self, from: data) {
            return decoded.searchResult.compactMap(\.webSearchResult)
        }
        if let decoded = try? JSONDecoder().decode(ResultsEnvelope.self, from: data) {
            return decoded.results.compactMap(\.webSearchResult)
        }
        throw SearchAugmentorError.invalidResponse
    }
}

private struct SearchResultsEnvelope: Decodable {
    var searchResult: [SearchItem]

    enum CodingKeys: String, CodingKey {
        case searchResult = "search_result"
    }
}

private struct ResultsEnvelope: Decodable {
    var results: [SearchItem]
}

private struct SearchItem: Decodable {
    var title: String?
    var link: String?
    var url: String?
    var content: String?
    var snippet: String?
    var media: String?
    var publishDate: String?

    enum CodingKeys: String, CodingKey {
        case title, link, url, content, snippet, media
        case publishDate = "publish_date"
    }

    var webSearchResult: WebSearchResult? {
        guard let title, let urlString = link ?? url, let url = URL(string: urlString) else {
            return nil
        }
        return WebSearchResult(
            title: title,
            url: url,
            snippet: content ?? snippet ?? "",
            publishedAt: publishDate.flatMap(PaperPulseDateParser.dateOnly),
            sourceName: media
        )
    }
}
