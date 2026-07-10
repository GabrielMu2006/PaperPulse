import XCTest
@testable import PaperCore

final class PipelineTests: XCTestCase {
    func testPipelineRunsDeterministicSearchDownloadExtractionAndShortSummary() async throws {
        let feed = FeedConfig(
            name: "Agents",
            categories: ["cs.AI"],
            keywords: ["agent"],
            authorityPolicy: AuthorityPolicy(dailyLimit: 1)
        )
        let paper = PaperCandidate.fixture(
            sourceID: "2607.05174v1",
            title: "AgentGym2",
            summary: "A benchmark for agents.",
            pdfURL: URL(string: "https://arxiv.org/pdf/2607.05174v1.pdf")!
        )
        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let pipeline = PaperPipeline(
            sources: [StubPaperSource(results: [paper])],
            augmentors: [],
            ranker: PaperRanker(),
            downloader: StubDownloader(),
            extractor: StubExtractor(text: "This paper proposes AgentGym2."),
            llmProvider: StubLLMProvider()
        )

        let result = try await pipeline.run(feed: feed, now: Date(), outputDirectory: output)

        XCTAssertEqual(result.papers.count, 1)
        XCTAssertEqual(result.papers[0].candidate.sourceID, "2607.05174v1")
        XCTAssertEqual(result.summaries[0].language, "zh-Hans")
        XCTAssertTrue(result.summaries[0].shortText.contains("简介"))
    }

    func testPipelineEnrichesCandidatePDFURLBeforeDownloading() async throws {
        let feed = FeedConfig(
            name: "Agents",
            categories: ["cs.AI"],
            keywords: ["agent"],
            authorityPolicy: AuthorityPolicy(dailyLimit: 1)
        )
        let enrichedPDFURL = URL(string: "https://oa.example/paper.pdf")!
        let paper = PaperCandidate.fixture(
            sourceID: "crossref-only",
            doi: "10.5555/agent",
            title: "DOI Only Agent Paper",
            summary: "A paper with no direct PDF in the search result.",
            pdfURL: nil
        )
        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let pipeline = PaperPipeline(
            sources: [StubPaperSource(results: [paper])],
            augmentors: [],
            enrichers: [
                StubMetadataEnricher { candidate in
                    var enriched = candidate
                    enriched.openAccessPDFURL = enrichedPDFURL
                    return enriched
                }
            ],
            ranker: PaperRanker(),
            downloader: AssertingDownloader(expectedPDFURL: enrichedPDFURL),
            extractor: StubExtractor(text: "This paper was enriched before download."),
            llmProvider: StubLLMProvider()
        )

        let result = try await pipeline.run(feed: feed, now: Date(), outputDirectory: output)

        XCTAssertEqual(result.papers.count, 1)
        XCTAssertEqual(result.papers[0].candidate.openAccessPDFURL, enrichedPDFURL)
        XCTAssertTrue(result.failures.isEmpty)
    }

    func testPipelineAppliesOptionalRerankerAfterRuleRankingBeforeDownload() async throws {
        let feed = FeedConfig(
            name: "Agents",
            categories: ["cs.AI"],
            keywords: ["agent"],
            authorityPolicy: AuthorityPolicy(dailyLimit: 1)
        )
        let firstByRules = PaperCandidate.fixture(
            sourceID: "rule-first",
            title: "Agent Planning Benchmark",
            summary: "agent benchmark",
            pdfURL: URL(string: "https://example.com/rule-first.pdf")!
        )
        let preferredByReranker = PaperCandidate.fixture(
            sourceID: "semantic-first",
            title: "Embodied Reasoning",
            summary: "agent",
            pdfURL: URL(string: "https://example.com/semantic-first.pdf")!
        )
        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let pipeline = PaperPipeline(
            sources: [StubPaperSource(results: [firstByRules, preferredByReranker])],
            augmentors: [],
            ranker: PaperRanker(),
            reranker: StubPaperReranker { ranked, _, limit in
                Array(ranked.reversed().prefix(limit))
            },
            downloader: AssertingSourceIDDownloader(expectedSourceID: "semantic-first"),
            extractor: StubExtractor(text: "Reranked paper text."),
            llmProvider: StubLLMProvider()
        )

        let result = try await pipeline.run(feed: feed, now: Date(), outputDirectory: output)

        XCTAssertEqual(result.papers.map(\.candidate.sourceID), ["semantic-first"])
    }

    func testPipelineFallsBackToRuleRankingWhenRerankerReturnsInvalidPaperIDs() async throws {
        let feed = FeedConfig(
            name: "Agents",
            keywords: ["agent"],
            authorityPolicy: AuthorityPolicy(dailyLimit: 1)
        )
        let firstByRules = PaperCandidate.fixture(
            sourceID: "rule-first",
            title: "Agent Planning Benchmark",
            summary: "agent benchmark"
        )
        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let pipeline = PaperPipeline(
            sources: [StubPaperSource(results: [firstByRules])],
            augmentors: [],
            ranker: PaperRanker(),
            reranker: StubPaperReranker { _, _, _ in
                throw PaperRerankerError.unknownPaperID("not-in-candidates")
            },
            downloader: AssertingSourceIDDownloader(expectedSourceID: "rule-first"),
            extractor: StubExtractor(text: "Fallback paper text."),
            llmProvider: StubLLMProvider()
        )

        let result = try await pipeline.run(feed: feed, now: Date(), outputDirectory: output)

        XCTAssertEqual(result.papers.map(\.candidate.sourceID), ["rule-first"])
        XCTAssertEqual(result.failures.count, 1)
        XCTAssertTrue(result.failures[0].message.contains("paper reranking failed"))
    }

    func testPipelineWritesConfiguredProviderMetadataToGeneratedSummary() async throws {
        let profileID = UUID(uuidString: "ABABABAB-ABAB-ABAB-ABAB-ABABABABABAB")!
        let profile = LLMProfile(
            id: profileID,
            name: "Short summary",
            baseURL: URL(string: "https://api.example.com")!,
            model: "configured-model",
            apiKey: "test-key",
            capabilities: [.shortSummary]
        )
        let paper = PaperCandidate.fixture(sourceID: "metadata-paper")
        let pipeline = PaperPipeline(
            sources: [StubPaperSource(results: [paper])],
            augmentors: [],
            ranker: PaperRanker(),
            downloader: StubDownloader(),
            extractor: StubExtractor(text: "Text"),
            llmProvider: StubLLMProvider(),
            shortSummaryProfile: profile
        )

        let result = try await pipeline.run(
            feed: FeedConfig(name: "Agents", authorityPolicy: AuthorityPolicy(dailyLimit: 1)),
            now: Date(),
            outputDirectory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        )

        XCTAssertEqual(result.summaries.first?.providerProfileID, profileID)
        XCTAssertEqual(result.summaries.first?.model, "configured-model")
    }
}

private struct StubMetadataEnricher: PaperMetadataEnricher {
    var enrichHandler: (PaperCandidate) async throws -> PaperCandidate

    init(_ enrichHandler: @escaping (PaperCandidate) async throws -> PaperCandidate) {
        self.enrichHandler = enrichHandler
    }

    func enrich(_ candidate: PaperCandidate) async throws -> PaperCandidate {
        try await enrichHandler(candidate)
    }
}

private struct AssertingDownloader: PaperDownloader {
    var expectedPDFURL: URL

    func download(_ paper: PaperCandidate, to directory: URL) async throws -> LocalPaperFile {
        XCTAssertEqual(paper.openAccessPDFURL, expectedPDFURL)
        return LocalPaperFile(
            paperID: paper.stableID,
            fileURL: directory.appendingPathComponent("enriched.pdf"),
            byteCount: 1024,
            mimeType: "application/pdf",
            downloadedAt: Date()
        )
    }
}

private struct StubPaperReranker: PaperReranker {
    var handler: ([RankedPaper], FeedConfig, Int) async throws -> [RankedPaper]

    func rerank(_ ranked: [RankedPaper], feed: FeedConfig, limit: Int) async throws -> [RankedPaper] {
        try await handler(ranked, feed, limit)
    }
}

private struct AssertingSourceIDDownloader: PaperDownloader {
    var expectedSourceID: String

    func download(_ paper: PaperCandidate, to directory: URL) async throws -> LocalPaperFile {
        XCTAssertEqual(paper.sourceID, expectedSourceID)
        return LocalPaperFile(
            paperID: paper.stableID,
            fileURL: directory.appendingPathComponent("\(paper.sourceID).pdf"),
            byteCount: 1024,
            mimeType: "application/pdf",
            downloadedAt: Date()
        )
    }
}
