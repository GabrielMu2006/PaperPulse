import Foundation

public final class PaperPipeline {
    private let sources: [any PaperSource]
    private let augmentors: [any SearchAugmentor]
    private let enrichers: [any PaperMetadataEnricher]
    private let ranker: PaperRanker
    private let reranker: (any PaperReranker)?
    private let processingService: PaperProcessingService
    private let summaryService: PaperSummaryService

    public init(
        sources: [any PaperSource],
        augmentors: [any SearchAugmentor],
        enrichers: [any PaperMetadataEnricher] = [],
        ranker: PaperRanker,
        reranker: (any PaperReranker)? = nil,
        downloader: any PaperDownloader,
        extractor: any PDFTextExtractor,
        llmProvider: any LLMProvider,
        summaryLanguage: SummaryLanguage = .chinese,
        shortSummaryProfile: LLMProfile? = nil,
        fullSummaryProfile: LLMProfile? = nil
    ) {
        self.sources = sources
        self.augmentors = augmentors
        self.enrichers = enrichers
        self.ranker = ranker
        self.reranker = reranker
        self.processingService = PaperProcessingService(
            downloader: downloader,
            extractor: extractor
        )
        self.summaryService = PaperSummaryService(
            shortProvider: llmProvider,
            fullProvider: llmProvider,
            shortProfile: shortSummaryProfile,
            fullProfile: fullSummaryProfile,
            language: summaryLanguage
        )
    }

    public func run(feed: FeedConfig, now: Date, outputDirectory: URL) async throws -> PipelineResult {
        let started = Date()
        let window = DateInterval(start: now.addingTimeInterval(-7 * 86_400), end: now)
        var candidates: [PaperCandidate] = []
        var failures: [PipelineFailure] = []

        for source in sources {
            do {
                candidates += try await source.search(feed: feed, window: window)
            } catch {
                failures.append(PipelineFailure(paperID: nil, message: "source failed: \(error.localizedDescription)"))
            }
        }

        if feed.enableWebAugmentation, candidates.count < feed.authorityPolicy.dailyLimit {
            let query = SearchQuery(text: ([feed.name] + feed.keywords).joined(separator: " "), domains: ["arxiv.org"], recencyDays: 7)
            for augmentor in augmentors {
                do {
                    let webResults = try await augmentor.augment(query: query, limit: feed.authorityPolicy.dailyLimit)
                    candidates += webResults.map { result in
                        PaperCandidate(
                            source: .web,
                            sourceID: result.url.absoluteString,
                            title: result.title,
                            summary: result.snippet,
                            publishedAt: result.publishedAt,
                            absURL: result.url
                        )
                    }
                } catch {
                    failures.append(PipelineFailure(paperID: nil, message: "web augmentation failed: \(error.localizedDescription)"))
                }
            }
        }

        if !enrichers.isEmpty {
            var enrichedCandidates: [PaperCandidate] = []
            for candidate in candidates {
                var current = candidate
                for enricher in enrichers {
                    do {
                        current = try await enricher.enrich(current)
                    } catch {
                        failures.append(PipelineFailure(paperID: current.stableID, message: "metadata enrichment failed: \(error.localizedDescription)"))
                    }
                }
                enrichedCandidates.append(current)
            }
            candidates = enrichedCandidates
        }

        let ruleRankingLimit = reranker == nil
            ? feed.authorityPolicy.dailyLimit
            : max(feed.authorityPolicy.dailyLimit * 4, feed.authorityPolicy.dailyLimit)
        var ranked = ranker.rank(candidates, feed: feed, now: now, limit: ruleRankingLimit)
        if let reranker {
            do {
                ranked = try await reranker.rerank(ranked, feed: feed, limit: feed.authorityPolicy.dailyLimit)
            } catch {
                failures.append(PipelineFailure(paperID: nil, message: "paper reranking failed: \(error.localizedDescription)"))
                ranked = Array(ranked.prefix(feed.authorityPolicy.dailyLimit))
            }
        }
        ranked = Array(ranked.prefix(feed.authorityPolicy.dailyLimit))
        var papers: [PaperRecord] = []
        var summaries: [PaperSummary] = []

        for rankedPaper in ranked {
            let candidate = rankedPaper.candidate
            do {
                let processed = try await processingService.process(candidate: candidate, outputDirectory: outputDirectory)
                let summary = try await summaryService.generateShortSummary(
                    for: processed.record,
                    text: processed.text
                )
                papers.append(processed.record)
                summaries.append(summary)
            } catch {
                failures.append(PipelineFailure(paperID: candidate.stableID, message: error.localizedDescription))
            }
        }

        let run = SearchRun(
            feedID: feed.id,
            startedAt: started,
            completedAt: Date(),
            selectedCount: papers.count
        )
        return PipelineResult(run: run, rankedCandidates: ranked, papers: papers, summaries: summaries, failures: failures)
    }

    public func generateFullSummary(paper: PaperRecord, text: ExtractedPaperText) async throws -> PaperSummary {
        try await summaryService.generateFullSummary(for: paper, text: text)
    }
}
