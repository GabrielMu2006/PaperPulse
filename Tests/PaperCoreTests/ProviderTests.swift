import XCTest
@testable import PaperCore

final class ProviderTests: XCTestCase {
    func testLocalSummaryProviderUsesConfiguredEnglishLanguage() async throws {
        let provider = LocalRuleSummaryProvider(language: .english)
        let summary = try await provider.shortSummary(
            for: PaperRecord(candidate: .fixture(title: "Agent Planning"), localFile: nil),
            text: ExtractedPaperText(plainText: "Agent planning text.", pages: [])
        )

        XCTAssertEqual(summary.language, "en")
        XCTAssertTrue(summary.shortText.hasPrefix("Summary:"))
        XCTAssertTrue(summary.shortText.contains("Agent Planning"))
    }

    func testProviderPresetsExposeOfficialDefaultsAndEditableBaseURLs() {
        let gpt = LLMProfile.preset(.gpt)
        let claude = LLMProfile.preset(.claude)
        let gemini = LLMProfile.preset(.gemini)
        let deepSeek = LLMProfile.preset(.deepSeek)

        XCTAssertEqual(gpt.baseURL.absoluteString, "https://api.openai.com/v1")
        XCTAssertEqual(gpt.apiStyle, .openAIChatCompletions)
        XCTAssertEqual(claude.baseURL.absoluteString, "https://api.anthropic.com/v1")
        XCTAssertEqual(claude.apiStyle, .anthropicMessages)
        XCTAssertEqual(gemini.baseURL.absoluteString, "https://generativelanguage.googleapis.com/v1beta")
        XCTAssertEqual(gemini.apiStyle, .geminiGenerateContent)
        XCTAssertEqual(deepSeek.baseURL.absoluteString, "https://api.deepseek.com")
        XCTAssertEqual(deepSeek.apiStyle, .openAIChatCompletions)
        XCTAssertEqual(deepSeek.model, "deepseek-v4-flash")

        let relay = claude.withBaseURL(URL(string: "https://relay.example.com/v1")!, apiStyle: .openAIChatCompletions)
        XCTAssertEqual(relay.providerKind, .claude)
        XCTAssertEqual(relay.baseURL.absoluteString, "https://relay.example.com/v1")
        XCTAssertEqual(relay.apiStyle, .openAIChatCompletions)
    }

    func testOpenAICompatibleProviderAcceptsOnlyGeneratedSummaryContent() async throws {
        let response = """
        {
          "choices": [
            {
              "message": {
                "content": "{\\"shortText\\":\\"简介：这是一篇论文。\\",\\"fullText\\":null,\\"language\\":\\"zh-Hans\\",\\"model\\":\\"custom\\",\\"generatedAt\\":\\"2026-07-08T00:00:00Z\\",\\"sourceRange\\":\\"pages 1-2\\"}"
              }
            }
          ]
        }
        """
        let client = StubHTTPClient { request in
            XCTAssertEqual(request.url?.absoluteString, "https://api.example.com/v1/chat/completions")
            return HTTPResponse(data: Data(response.utf8), statusCode: 200, mimeType: "application/json", finalURL: request.url!)
        }
        let provider = OpenAICompatibleChatProvider(
            profile: LLMProfile(
                name: "Custom",
                baseURL: URL(string: "https://api.example.com/v1")!,
                model: "custom",
                apiKey: "test-key",
                capabilities: [.shortSummary, .fullSummary]
            ),
            httpClient: client
        )

        let summary = try await provider.shortSummary(
            for: PaperRecord(candidate: .fixture(title: "Paper"), localFile: nil),
            text: ExtractedPaperText(plainText: "paper text", pages: [])
        )

        XCTAssertEqual(summary.shortText, "简介：这是一篇论文。")
        XCTAssertEqual(summary.paperID, "arxiv:fixture")
        XCTAssertEqual(summary.model, "")
        XCTAssertEqual(summary.generatedAt, .distantPast)
        XCTAssertEqual(summary.sourceRange, "")
    }

    func testOpenAICompatibleProviderUsesCustomRelayBaseURLForClaudeOrGeminiModels() async throws {
        let response = """
        {
          "choices": [
            {
              "message": {
                "content": "{\\"shortText\\":\\"简介：代理模型返回。\\",\\"fullText\\":null,\\"language\\":\\"zh-Hans\\",\\"model\\":\\"relay\\",\\"generatedAt\\":\\"2026-07-08T00:00:00Z\\",\\"sourceRange\\":\\"pages 1\\"}"
              }
            }
          ]
        }
        """
        let client = StubHTTPClient { request in
            XCTAssertEqual(request.url?.absoluteString, "https://relay.example.com/v1/chat/completions")
            let body = try XCTUnwrap(request.httpBody)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            XCTAssertEqual(json["model"] as? String, "claude-sonnet-4.5")
            return HTTPResponse(data: Data(response.utf8), statusCode: 200, mimeType: "application/json", finalURL: request.url!)
        }
        let relayProfile = LLMProfile.preset(.claude)
            .withBaseURL(URL(string: "https://relay.example.com/v1")!, apiStyle: .openAIChatCompletions)
            .withModel("claude-sonnet-4.5")
            .withAPIKey("test-key")

        let provider = OpenAICompatibleChatProvider(profile: relayProfile, httpClient: client)

        let summary = try await provider.shortSummary(
            for: PaperRecord(candidate: .fixture(title: "Paper"), localFile: nil),
            text: ExtractedPaperText(plainText: "paper text", pages: [])
        )

        XCTAssertEqual(summary.shortText, "简介：代理模型返回。")
    }

    func testOpenAICompatibleProviderUsesConfiguredEnglishLanguageInPrompt() async throws {
        let response = """
        {
          "choices": [
            {
              "message": {
                "content": "{\\"shortText\\":\\"Summary: This is an English summary.\\",\\"fullText\\":null,\\"language\\":\\"en\\",\\"model\\":\\"custom\\",\\"generatedAt\\":\\"2026-07-08T00:00:00Z\\",\\"sourceRange\\":\\"pages 1\\"}"
              }
            }
          ]
        }
        """
        let client = StubHTTPClient { request in
            let body = try XCTUnwrap(request.httpBody)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            let messages = try XCTUnwrap(json["messages"] as? [[String: String]])
            let system = try XCTUnwrap(messages.first(where: { $0["role"] == "system" })?["content"])
            let user = try XCTUnwrap(messages.first(where: { $0["role"] == "user" })?["content"])
            XCTAssertTrue(system.contains("English"))
            XCTAssertTrue(user.contains("Write the summary in English"))
            XCTAssertTrue(user.contains("concise English summary"))
            return HTTPResponse(data: Data(response.utf8), statusCode: 200, mimeType: "application/json", finalURL: request.url!)
        }
        let provider = OpenAICompatibleChatProvider(
            profile: LLMProfile(
                name: "Custom",
                baseURL: URL(string: "https://api.example.com/v1")!,
                model: "custom",
                apiKey: "test-key",
                capabilities: [.shortSummary, .fullSummary]
            ),
            summaryLanguage: .english,
            httpClient: client
        )

        let summary = try await provider.shortSummary(
            for: PaperRecord(candidate: .fixture(title: "Paper"), localFile: nil),
            text: ExtractedPaperText(plainText: "paper text", pages: [])
        )

        XCTAssertEqual(summary.language, "")
    }

    func testOpenAICompatibleProviderDecodesStructuredFullInterpretation() async throws {
        let response = """
        {
          "choices": [{
            "message": {
              "content": "{\\"shortText\\":\\"\\",\\"fullText\\":\\"Overall conclusion.\\",\\"interpretation\\":{\\"sections\\":[{\\"kind\\":\\"researchQuestion\\",\\"content\\":\\"The paper studies reliable agents.\\"}]}}"
            }
          }]
        }
        """
        let provider = OpenAICompatibleChatProvider(
            profile: LLMProfile(
                name: "DeepSeek",
                providerKind: .deepSeek,
                baseURL: URL(string: "https://api.example.com/v1")!,
                model: "deepseek-test",
                apiKey: "test-key",
                capabilities: [.fullSummary]
            ),
            httpClient: StubHTTPClient { request in
                let body = try XCTUnwrap(request.httpBody)
                XCTAssertTrue(String(decoding: body, as: UTF8.self).contains("researchQuestion"))
                return HTTPResponse(data: Data(response.utf8), statusCode: 200, mimeType: "application/json", finalURL: try XCTUnwrap(request.url))
            }
        )

        let summary = try await provider.fullSummary(
            for: PaperRecord(candidate: .fixture(title: "Paper"), localFile: nil),
            text: ExtractedPaperText(plainText: "paper text", pages: [])
        )

        XCTAssertEqual(summary.fullText, "Overall conclusion.")
        XCTAssertEqual(summary.interpretation?.sections.first?.kind, .researchQuestion)
        XCTAssertEqual(summary.interpretation?.sections.first?.content, "The paper studies reliable agents.")
    }

    func testProviderRegistryResolvesConfiguredProfileOnlyWhenItSupportsAssignedRole() {
        let shortProfile = LLMProfile(
            name: "Short",
            baseURL: URL(string: "https://short.example")!,
            model: "short-model",
            apiKey: "",
            capabilities: [.shortSummary]
        )
        let fullProfile = LLMProfile(
            name: "Full",
            baseURL: URL(string: "https://full.example")!,
            model: "full-model",
            apiKey: "",
            capabilities: [.fullSummary]
        )
        let feed = FeedConfig(
            name: "Agents",
            shortSummaryProviderProfileID: shortProfile.id,
            fullSummaryProviderProfileID: fullProfile.id
        )
        let registry = ProviderRegistry(profiles: [shortProfile, fullProfile])

        XCTAssertEqual(registry.profile(for: .shortSummary, feed: feed)?.id, shortProfile.id)
        XCTAssertEqual(registry.profile(for: .fullSummary, feed: feed)?.id, fullProfile.id)
        XCTAssertNil(registry.profile(for: .rerank, feed: feed))
    }

    func testHealthCheckUsesShortSummaryCapabilityWithoutRealNetwork() async throws {
        let response = """
        {"choices":[{"message":{"content":"{\\"shortText\\":\\"Connected\\",\\"fullText\\":null}"}}]}
        """
        let client = StubHTTPClient { request in
            XCTAssertEqual(request.url?.absoluteString, "https://api.example.com/v1/chat/completions")
            return HTTPResponse(data: Data(response.utf8), statusCode: 200, mimeType: "application/json", finalURL: try XCTUnwrap(request.url))
        }
        let profile = LLMProfile(
            name: "Health",
            baseURL: URL(string: "https://api.example.com/v1")!,
            model: "health-model",
            apiKey: "test-key",
            capabilities: [.shortSummary]
        )

        let health = try await OpenAICompatibleChatProvider(profile: profile, httpClient: client).healthCheck()

        XCTAssertEqual(health.model, "health-model")
        XCTAssertEqual(health.providerProfileID, profile.id)
    }

    func testProviderFactoryCreatesOfficialAndRelayProvidersFromProfileStyle() {
        let relay = LLMProfile.preset(.gemini)
            .withBaseURL(URL(string: "https://relay.example.com/v1")!, apiStyle: .openAIChatCompletions)
        let anthropic = LLMProfile.preset(.claude)
        let gemini = LLMProfile.preset(.gemini)

        XCTAssertTrue(LLMProviderFactory.makeProvider(profile: relay) is OpenAICompatibleChatProvider)
        XCTAssertTrue(LLMProviderFactory.makeProvider(profile: anthropic) is AnthropicMessagesProvider)
        XCTAssertTrue(LLMProviderFactory.makeProvider(profile: gemini) is GeminiGenerateContentProvider)
    }

    func testProfileConfigurationPersistsRelaySettingsWithoutAPIKey() throws {
        let profile = LLMProfile.preset(.claude, apiKey: "secret-key")
            .withBaseURL(URL(string: "https://relay.example.com/v1")!, apiStyle: .openAIChatCompletions)
            .withModel("claude-4-relay")

        let configuration = profile.persistedConfiguration
        let data = try JSONEncoder().encode(configuration)
        let storedJSON = String(decoding: data, as: UTF8.self)
        let decoded = try JSONDecoder().decode(LLMProfileConfiguration.self, from: data)
        let restored = decoded.profile(apiKey: "key-from-keychain")

        XCTAssertFalse(storedJSON.contains("secret-key"))
        XCTAssertEqual(restored.providerKind, .claude)
        XCTAssertEqual(restored.apiStyle, .openAIChatCompletions)
        XCTAssertEqual(restored.baseURL.absoluteString, "https://relay.example.com/v1")
        XCTAssertEqual(restored.model, "claude-4-relay")
        XCTAssertEqual(restored.apiKey, "key-from-keychain")
        XCTAssertEqual(restored.capabilities, profile.capabilities)
    }
}
