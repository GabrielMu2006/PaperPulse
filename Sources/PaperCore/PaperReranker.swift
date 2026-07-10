import Foundation

public enum PaperRerankerError: Error, Equatable, Sendable {
    case unsupportedCapability
    case invalidResponse
    case malformedJSON(String)
    case unknownPaperID(String)
    case duplicatePaperID(String)
}

public struct OpenAICompatiblePaperReranker: PaperReranker {
    public var profile: LLMProfile
    private let httpClient: HTTPClient

    public init(profile: LLMProfile, httpClient: HTTPClient = URLSessionHTTPClient()) {
        self.profile = profile
        self.httpClient = httpClient
    }

    public func rerank(_ ranked: [RankedPaper], feed: FeedConfig, limit: Int) async throws -> [RankedPaper] {
        guard profile.capabilities.contains(.rerank) else {
            throw PaperRerankerError.unsupportedCapability
        }
        guard !ranked.isEmpty else { return [] }

        var request = URLRequest(url: profile.baseURL.appendingPathComponent("chat/completions"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(profile.apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(RerankChatRequest(
            model: profile.model,
            messages: [
                RerankChatMessage(role: "system", content: "Rank only the supplied research-paper IDs. Return JSON only."),
                RerankChatMessage(role: "user", content: prompt(ranked: ranked, feed: feed, limit: limit))
            ],
            temperature: 0
        ))

        let response = try await httpClient.perform(request)
        try response.requireSuccess()
        let chat = try JSONDecoder().decode(RerankChatResponse.self, from: response.data)
        guard let content = chat.choices.first?.message.content else {
            throw PaperRerankerError.invalidResponse
        }

        let payload = try decode(content)
        guard !payload.orderedIDs.isEmpty else {
            throw PaperRerankerError.invalidResponse
        }
        let known = Dictionary(uniqueKeysWithValues: ranked.map { ($0.candidate.stableID, $0) })
        var seen = Set<String>()
        var result: [RankedPaper] = []

        for id in payload.orderedIDs {
            guard let paper = known[id] else {
                throw PaperRerankerError.unknownPaperID(id)
            }
            guard seen.insert(id).inserted else {
                throw PaperRerankerError.duplicatePaperID(id)
            }
            var reranked = paper
            if let reason = payload.reasons?[id]?.cleanedWhitespace, !reason.isEmpty {
                reranked.reasons.append("LLM: \(reason)")
            }
            result.append(reranked)
        }

        for paper in ranked where seen.insert(paper.candidate.stableID).inserted {
            result.append(paper)
        }
        return result
    }

    private func prompt(ranked: [RankedPaper], feed: FeedConfig, limit: Int) -> String {
        let papers = ranked.map { paper in
            RerankCandidate(
                id: paper.candidate.stableID,
                title: paper.candidate.title,
                abstract: paper.candidate.summary,
                categories: paper.candidate.categories,
                venue: paper.candidate.venue,
                score: paper.score
            )
        }
        let encoded = (try? String(decoding: JSONEncoder().encode(papers), as: UTF8.self)) ?? "[]"
        return """
        Feed: \(feed.name)
        Keywords: \(feed.keywords.joined(separator: ", "))
        Select up to \(max(1, limit)) best papers. You may only use IDs from the supplied candidates.
        Return exactly this JSON object: {"orderedIDs":["paper-id"],"reasons":{"paper-id":"brief relevance reason"}}.

        Candidates:
        \(encoded)
        """
    }

    private func decode(_ content: String) throws -> RerankPayload {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let json = trimmed.extractJSONCodeFence() ?? trimmed
        guard let data = json.data(using: .utf8),
              let payload = try? JSONDecoder().decode(RerankPayload.self, from: data) else {
            throw PaperRerankerError.malformedJSON(content)
        }
        return payload
    }
}

private struct RerankChatRequest: Encodable {
    var model: String
    var messages: [RerankChatMessage]
    var temperature: Double
}

private struct RerankChatMessage: Encodable {
    var role: String
    var content: String
}

private struct RerankChatResponse: Decodable {
    var choices: [Choice]

    struct Choice: Decodable {
        var message: Message
    }

    struct Message: Decodable {
        var content: String
    }
}

private struct RerankCandidate: Encodable {
    var id: String
    var title: String
    var abstract: String
    var categories: [String]
    var venue: String?
    var score: Int
}

private struct RerankPayload: Decodable {
    var orderedIDs: [String]
    var reasons: [String: String]?
}
