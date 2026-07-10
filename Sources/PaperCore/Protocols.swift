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
}
