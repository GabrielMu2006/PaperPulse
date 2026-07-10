import Foundation

public protocol PaperSource {
    func search(feed: FeedConfig, window: DateInterval) async throws -> [PaperCandidate]
}

public protocol SearchAugmentor {
    func augment(query: SearchQuery, limit: Int) async throws -> [WebSearchResult]
}

public protocol PaperMetadataEnricher {
    func enrich(_ candidate: PaperCandidate) async throws -> PaperCandidate
}

public protocol PaperReranker {
    func rerank(_ ranked: [RankedPaper], feed: FeedConfig, limit: Int) async throws -> [RankedPaper]
}

public protocol PaperDownloader {
    func download(_ paper: PaperCandidate, to directory: URL) async throws -> LocalPaperFile
}

public protocol PDFTextExtractor {
    func extract(from file: LocalPaperFile) async throws -> ExtractedPaperText
}

public protocol LLMProvider {
    var capabilities: Set<ProviderCapability> { get }

    func shortSummary(for paper: PaperRecord, text: ExtractedPaperText) async throws -> PaperSummary
    func fullSummary(for paper: PaperRecord, text: ExtractedPaperText) async throws -> PaperSummary
    func healthCheck() async throws -> ProviderHealth
}

public extension LLMProvider {
    func healthCheck() async throws -> ProviderHealth {
        guard capabilities.contains(.shortSummary) else {
            throw LLMProviderError.unsupportedCapability(.shortSummary)
        }
        let checkPaper = PaperRecord(
            candidate: PaperCandidate(
                source: .web,
                sourceID: "paperpulse-health-check",
                title: "PaperPulse connection check",
                summary: "This is a minimal capability check."
            ),
            localFile: nil
        )
        let summary = try await shortSummary(
            for: checkPaper,
            text: ExtractedPaperText(plainText: "", pages: [])
        )
        return ProviderHealth(providerProfileID: nil, model: summary.model)
    }
}
