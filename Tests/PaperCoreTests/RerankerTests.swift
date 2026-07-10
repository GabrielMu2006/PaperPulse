import XCTest
@testable import PaperCore

final class RerankerTests: XCTestCase {
    func testOpenAICompatibleRerankerUsesOnlyReturnedKnownIDs() async throws {
        let first = RankedPaper(candidate: .fixture(sourceID: "first", title: "First"), score: 10, reasons: [])
        let second = RankedPaper(candidate: .fixture(sourceID: "second", title: "Second"), score: 9, reasons: [])
        let response = """
        {"choices":[{"message":{"content":"{\\"orderedIDs\\":[\\"arxiv:second\\",\\"arxiv:first\\"],\\"reasons\\":{\\"arxiv:second\\":\\"Better fit\\"}}"}}]}
        """
        let client = StubHTTPClient { request in
            XCTAssertEqual(request.url?.absoluteString, "https://api.example.com/v1/chat/completions")
            return HTTPResponse(data: Data(response.utf8), statusCode: 200, mimeType: "application/json", finalURL: try XCTUnwrap(request.url))
        }
        let reranker = OpenAICompatiblePaperReranker(
            profile: LLMProfile(
                name: "Reranker",
                baseURL: URL(string: "https://api.example.com/v1")!,
                model: "test-model",
                apiKey: "test-key",
                capabilities: [.rerank]
            ),
            httpClient: client
        )

        let reranked = try await reranker.rerank([first, second], feed: FeedConfig(name: "Agents"), limit: 2)

        XCTAssertEqual(reranked.map(\.candidate.stableID), ["arxiv:second", "arxiv:first"])
        XCTAssertTrue(reranked[0].reasons.contains("LLM: Better fit"))
    }

    func testOpenAICompatibleRerankerRejectsUnknownPaperID() async {
        let response = """
        {"choices":[{"message":{"content":"{\\"orderedIDs\\":[\\"unknown-paper\\"]}"}}]}
        """
        let client = StubHTTPClient { request in
            HTTPResponse(data: Data(response.utf8), statusCode: 200, mimeType: "application/json", finalURL: try XCTUnwrap(request.url))
        }
        let reranker = OpenAICompatiblePaperReranker(
            profile: LLMProfile(
                name: "Reranker",
                baseURL: URL(string: "https://api.example.com/v1")!,
                model: "test-model",
                apiKey: "test-key",
                capabilities: [.rerank]
            ),
            httpClient: client
        )

        do {
            _ = try await reranker.rerank(
                [RankedPaper(candidate: .fixture(sourceID: "first"), score: 1, reasons: [])],
                feed: FeedConfig(name: "Agents"),
                limit: 1
            )
            XCTFail("Expected unknown paper ID to be rejected")
        } catch let error as PaperRerankerError {
            XCTAssertEqual(error, .unknownPaperID("unknown-paper"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testOpenAICompatibleRerankerRejectsMissingAPIKeyBeforeNetworkRequest() async {
        let reranker = OpenAICompatiblePaperReranker(
            profile: LLMProfile(
                name: "Reranker",
                baseURL: URL(string: "https://api.example.com/v1")!,
                model: "test-model",
                apiKey: "",
                capabilities: [.rerank]
            ),
            httpClient: StubHTTPClient { _ in
                XCTFail("A missing API key must not trigger a network request")
                return HTTPResponse(data: Data(), statusCode: 200, mimeType: nil, finalURL: URL(string: "https://api.example.com")!)
            }
        )

        await XCTAssertThrowsErrorAsync(
            try await reranker.rerank(
                [RankedPaper(candidate: .fixture(sourceID: "first"), score: 1, reasons: [])],
                feed: FeedConfig(name: "Agents"),
                limit: 1
            )
        ) { error in
            XCTAssertEqual(error as? PaperRerankerError, .missingAPIKey)
        }
    }
}
