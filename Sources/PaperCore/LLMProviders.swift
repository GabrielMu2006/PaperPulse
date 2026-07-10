import Foundation

public enum LLMProviderError: Error, Equatable {
    case unsupportedCapability(ProviderCapability)
    case missingAPIKey
    case invalidResponse
    case malformedSummaryJSON(String)
}

public struct OpenAICompatibleChatProvider: LLMProvider {
    public var profile: LLMProfile
    private let summaryLanguage: SummaryLanguage
    private let httpClient: HTTPClient

    public var capabilities: Set<ProviderCapability> {
        profile.capabilities
    }

    public init(
        profile: LLMProfile,
        summaryLanguage: SummaryLanguage = .chinese,
        httpClient: HTTPClient = URLSessionHTTPClient()
    ) {
        self.profile = profile
        self.summaryLanguage = summaryLanguage
        self.httpClient = httpClient
    }

    public func shortSummary(for paper: PaperRecord, text: ExtractedPaperText) async throws -> PaperSummary {
        guard capabilities.contains(.shortSummary) else {
            throw LLMProviderError.unsupportedCapability(.shortSummary)
        }
        return try await summarize(paper: paper, text: text, mode: "short")
    }

    public func fullSummary(for paper: PaperRecord, text: ExtractedPaperText) async throws -> PaperSummary {
        guard capabilities.contains(.fullSummary) else {
            throw LLMProviderError.unsupportedCapability(.fullSummary)
        }
        return try await summarize(paper: paper, text: text, mode: "full")
    }

    public func healthCheck() async throws -> ProviderHealth {
        _ = try await shortSummary(for: providerHealthCheckPaper(), text: providerHealthCheckText)
        return ProviderHealth(providerProfileID: profile.id, model: profile.model)
    }

    private func summarize(paper: PaperRecord, text: ExtractedPaperText, mode: String) async throws -> PaperSummary {
        guard !profile.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LLMProviderError.missingAPIKey
        }
        let endpoint = profile.baseURL.appendingPathComponent("chat/completions")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(profile.apiKey)", forHTTPHeaderField: "Authorization")

        let prompt = Self.prompt(paper: paper, text: text, mode: mode, language: summaryLanguage)
        let body = ChatRequest(
            model: profile.model,
            messages: [
                ChatMessage(role: "system", content: "You summarize scientific papers in \(summaryLanguage.promptName). Return only JSON matching the requested schema."),
                ChatMessage(role: "user", content: prompt)
            ],
            temperature: 0.2
        )
        request.httpBody = try JSONEncoder().encode(body)

        let response = try await httpClient.perform(request)
        try response.requireSuccess()
        let chat = try JSONDecoder().decode(ChatResponse.self, from: response.data)
        guard let content = chat.choices.first?.message.content else {
            throw LLMProviderError.invalidResponse
        }

        return try SummaryContentDecoder.decode(content, paperID: paper.id)
    }

    private static func prompt(paper: PaperRecord, text: ExtractedPaperText, mode: String, language: SummaryLanguage) -> String {
        let clipped = String(text.plainText.prefix(mode == "short" ? 12_000 : 45_000))
        return """
        Paper title: \(paper.candidate.title)
        Authors: \(paper.candidate.authors.joined(separator: ", "))
        Known institutions: \(paper.candidate.institutions.joined(separator: "; "))
        Mode: \(mode)

        Write the summary in \(language.promptName). Return JSON:
        {
          "shortText": "\(language.shortTextInstruction)",
          "fullText": "\(language.fullTextInstruction)"
        }

        Do not invent institutions, experiments, citations, or limitations. Say evidence is unavailable when it is unavailable.

        Text:
        \(clipped)
        """
    }
}

public struct AnthropicMessagesProvider: LLMProvider {
    public var profile: LLMProfile
    private let summaryLanguage: SummaryLanguage
    private let httpClient: HTTPClient

    public var capabilities: Set<ProviderCapability> {
        profile.capabilities
    }

    public init(
        profile: LLMProfile,
        summaryLanguage: SummaryLanguage = .chinese,
        httpClient: HTTPClient = URLSessionHTTPClient()
    ) {
        self.profile = profile
        self.summaryLanguage = summaryLanguage
        self.httpClient = httpClient
    }

    public func shortSummary(for paper: PaperRecord, text: ExtractedPaperText) async throws -> PaperSummary {
        guard capabilities.contains(.shortSummary) else {
            throw LLMProviderError.unsupportedCapability(.shortSummary)
        }
        return try await summarize(paper: paper, text: text, mode: "short")
    }

    public func fullSummary(for paper: PaperRecord, text: ExtractedPaperText) async throws -> PaperSummary {
        guard capabilities.contains(.fullSummary) else {
            throw LLMProviderError.unsupportedCapability(.fullSummary)
        }
        return try await summarize(paper: paper, text: text, mode: "full")
    }

    public func healthCheck() async throws -> ProviderHealth {
        _ = try await shortSummary(for: providerHealthCheckPaper(), text: providerHealthCheckText)
        return ProviderHealth(providerProfileID: profile.id, model: profile.model)
    }

    private func summarize(paper: PaperRecord, text: ExtractedPaperText, mode: String) async throws -> PaperSummary {
        guard !profile.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LLMProviderError.missingAPIKey
        }
        var request = URLRequest(url: profile.baseURL.appendingPathComponent("messages"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(profile.apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body = AnthropicRequest(
            model: profile.model,
            maxTokens: mode == "short" ? 1_000 : 4_000,
            system: "You summarize scientific papers in \(summaryLanguage.promptName). Return only JSON matching the requested schema.",
            messages: [
                AnthropicMessage(role: "user", content: OpenAICompatibleChatProvider.promptForProvider(paper: paper, text: text, mode: mode, language: summaryLanguage))
            ]
        )
        request.httpBody = try JSONEncoder().encode(body)

        let response = try await httpClient.perform(request)
        try response.requireSuccess()
        let decoded = try JSONDecoder().decode(AnthropicResponse.self, from: response.data)
        guard let content = decoded.content.first(where: { $0.type == "text" })?.text else {
            throw LLMProviderError.invalidResponse
        }
        return try SummaryContentDecoder.decode(content, paperID: paper.id)
    }
}

public struct GeminiGenerateContentProvider: LLMProvider {
    public var profile: LLMProfile
    private let summaryLanguage: SummaryLanguage
    private let httpClient: HTTPClient

    public var capabilities: Set<ProviderCapability> {
        profile.capabilities
    }

    public init(
        profile: LLMProfile,
        summaryLanguage: SummaryLanguage = .chinese,
        httpClient: HTTPClient = URLSessionHTTPClient()
    ) {
        self.profile = profile
        self.summaryLanguage = summaryLanguage
        self.httpClient = httpClient
    }

    public func shortSummary(for paper: PaperRecord, text: ExtractedPaperText) async throws -> PaperSummary {
        guard capabilities.contains(.shortSummary) else {
            throw LLMProviderError.unsupportedCapability(.shortSummary)
        }
        return try await summarize(paper: paper, text: text, mode: "short")
    }

    public func fullSummary(for paper: PaperRecord, text: ExtractedPaperText) async throws -> PaperSummary {
        guard capabilities.contains(.fullSummary) else {
            throw LLMProviderError.unsupportedCapability(.fullSummary)
        }
        return try await summarize(paper: paper, text: text, mode: "full")
    }

    public func healthCheck() async throws -> ProviderHealth {
        _ = try await shortSummary(for: providerHealthCheckPaper(), text: providerHealthCheckText)
        return ProviderHealth(providerProfileID: profile.id, model: profile.model)
    }

    private func summarize(paper: PaperRecord, text: ExtractedPaperText, mode: String) async throws -> PaperSummary {
        guard !profile.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LLMProviderError.missingAPIKey
        }
        var components = URLComponents(
            url: profile.baseURL
                .appendingPathComponent("models")
                .appendingPathComponent("\(profile.model):generateContent"),
            resolvingAgainstBaseURL: false
        )!
        if !profile.apiKey.isEmpty {
            components.queryItems = [URLQueryItem(name: "key", value: profile.apiKey)]
        }

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let prompt = """
        You summarize scientific papers in \(summaryLanguage.promptName). Return only JSON matching the requested schema.

        \(OpenAICompatibleChatProvider.promptForProvider(paper: paper, text: text, mode: mode, language: summaryLanguage))
        """
        let body = GeminiRequest(contents: [
            GeminiContent(parts: [GeminiPart(text: prompt)])
        ])
        request.httpBody = try JSONEncoder().encode(body)

        let response = try await httpClient.perform(request)
        try response.requireSuccess()
        let decoded = try JSONDecoder().decode(GeminiResponse.self, from: response.data)
        guard let content = decoded.candidates.first?.content.parts.first?.text else {
            throw LLMProviderError.invalidResponse
        }
        return try SummaryContentDecoder.decode(content, paperID: paper.id)
    }
}

private struct ChatRequest: Encodable {
    var model: String
    var messages: [ChatMessage]
    var temperature: Double
}

private func providerHealthCheckPaper() -> PaperRecord {
    PaperRecord(
        candidate: PaperCandidate(
            source: .web,
            sourceID: "paperpulse-health-check",
            title: "PaperPulse connection check",
            summary: "This is a minimal capability check."
        ),
        localFile: nil
    )
}

private let providerHealthCheckText = ExtractedPaperText(plainText: "", pages: [])

private struct ChatMessage: Codable {
    var role: String
    var content: String
}

private struct ChatResponse: Decodable {
    var choices: [Choice]

    struct Choice: Decodable {
        var message: ResponseMessage
    }

    struct ResponseMessage: Decodable {
        var content: String
    }
}

private struct AnthropicRequest: Encodable {
    var model: String
    var maxTokens: Int
    var system: String
    var messages: [AnthropicMessage]

    enum CodingKeys: String, CodingKey {
        case model, system, messages
        case maxTokens = "max_tokens"
    }
}

private struct AnthropicMessage: Codable {
    var role: String
    var content: String
}

private struct AnthropicResponse: Decodable {
    var content: [Content]

    struct Content: Decodable {
        var type: String
        var text: String
    }
}

private struct GeminiRequest: Encodable {
    var contents: [GeminiContent]
}

private struct GeminiContent: Codable {
    var parts: [GeminiPart]
}

private struct GeminiPart: Codable {
    var text: String
}

private struct GeminiResponse: Decodable {
    var candidates: [Candidate]

    struct Candidate: Decodable {
        var content: GeminiContent
    }
}

private enum SummaryContentDecoder {
    static func decode(_ content: String, paperID: String) throws -> PaperSummary {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let json = trimmed.extractJSONCodeFence() ?? trimmed
        guard let data = json.data(using: .utf8),
              let payload = try? decoder.decode(ProviderSummaryPayload.self, from: data) else {
            throw LLMProviderError.malformedSummaryJSON(content)
        }
        return PaperSummary(
            paperID: paperID,
            shortText: payload.shortText,
            fullText: payload.fullText,
            language: "",
            model: "",
            generatedAt: .distantPast,
            sourceRange: ""
        )
    }
}

private struct ProviderSummaryPayload: Decodable {
    var shortText: String
    var fullText: String?
}

extension String {
    func extractJSONCodeFence() -> String? {
        guard contains("```") else { return nil }
        let parts = components(separatedBy: "```")
        guard parts.count >= 3 else { return nil }
        var body = parts[1]
        if body.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("json") {
            body = body.replacingOccurrences(of: #"^\s*json\s*"#, with: "", options: .regularExpression)
        }
        return body.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public struct ProviderRegistry {
    public private(set) var profiles: [LLMProfile]

    public init(profiles: [LLMProfile] = []) {
        self.profiles = profiles
    }

    public mutating func upsert(_ profile: LLMProfile) {
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index] = profile
        } else {
            profiles.append(profile)
        }
    }

    public func profile(named name: String) -> LLMProfile? {
        profiles.first { $0.name == name }
    }

    public func profile(id: UUID) -> LLMProfile? {
        profiles.first { $0.id == id }
    }

    public func profile(for role: ProviderRole, feed: FeedConfig) -> LLMProfile? {
        let profileID: UUID?
        switch role {
        case .search: profileID = feed.searchProviderProfileID
        case .rerank: profileID = feed.rerankProviderProfileID
        case .shortSummary: profileID = feed.shortSummaryProviderProfileID
        case .fullSummary: profileID = feed.fullSummaryProviderProfileID
        case .extraction: profileID = feed.extractionProviderProfileID
        }
        guard let profileID, let profile = profile(id: profileID), profile.supports(role) else {
            return nil
        }
        return profile
    }
}

public enum LLMProviderFactory {
    public static func makeProvider(
        profile: LLMProfile,
        summaryLanguage: SummaryLanguage = .chinese,
        httpClient: HTTPClient = URLSessionHTTPClient()
    ) -> any LLMProvider {
        switch profile.apiStyle {
        case .openAIChatCompletions:
            OpenAICompatibleChatProvider(profile: profile, summaryLanguage: summaryLanguage, httpClient: httpClient)
        case .anthropicMessages:
            AnthropicMessagesProvider(profile: profile, summaryLanguage: summaryLanguage, httpClient: httpClient)
        case .geminiGenerateContent:
            GeminiGenerateContentProvider(profile: profile, summaryLanguage: summaryLanguage, httpClient: httpClient)
        }
    }

    public static func makeReranker(
        profile: LLMProfile,
        httpClient: HTTPClient = URLSessionHTTPClient()
    ) -> (any PaperReranker)? {
        guard profile.apiStyle == .openAIChatCompletions, profile.supports(.rerank) else {
            return nil
        }
        return OpenAICompatiblePaperReranker(profile: profile, httpClient: httpClient)
    }
}

extension OpenAICompatibleChatProvider {
    static func promptForProvider(
        paper: PaperRecord,
        text: ExtractedPaperText,
        mode: String,
        language: SummaryLanguage
    ) -> String {
        prompt(paper: paper, text: text, mode: mode, language: language)
    }
}
