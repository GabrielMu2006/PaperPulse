import Foundation

public struct PaperDiscoveryService {
    private let sources: [PaperSourceKind: ConcurrentPaperSource]
    private let merger: PaperCandidateMerger

    public init(
        sources: [PaperSourceKind: any PaperSource],
        merger: PaperCandidateMerger = PaperCandidateMerger()
    ) {
        self.sources = sources.mapValues(ConcurrentPaperSource.init)
        self.merger = merger
    }

    public func discover(feed: FeedConfig, now: Date = Date()) async -> DiscoveryResult {
        let window = DateInterval(
            start: now.addingTimeInterval(-Double(feed.lookbackDays) * 86_400),
            end: now
        )
        let enabled = uniqueEnabledSources(feed.enabledSources).filter { sources[$0] != nil }
        let outcomes = await search(enabled, feed: feed, window: window)
        var candidates: [PaperCandidate] = []
        var failures: [PipelineFailure] = []

        for kind in enabled {
            guard let outcome = outcomes[kind] else { continue }
            candidates += outcome.candidates
            if let failureMessage = outcome.failureMessage {
                failures.append(PipelineFailure(paperID: nil, message: "\(kind.rawValue) source failed: \(failureMessage)"))
            }
        }

        return DiscoveryResult(candidates: merger.merge(candidates), failures: failures)
    }

    private func uniqueEnabledSources(_ kinds: [PaperSourceKind]) -> [PaperSourceKind] {
        var seen = Set<PaperSourceKind>()
        return kinds.filter { kind in
            kind != .unpaywall && seen.insert(kind).inserted
        }
    }

    private func search(
        _ kinds: [PaperSourceKind],
        feed: FeedConfig,
        window: DateInterval
    ) async -> [PaperSourceKind: SourceOutcome] {
        await withTaskGroup(of: SourceOutcome.self, returning: [PaperSourceKind: SourceOutcome].self) { group in
            for kind in kinds {
                guard let source = sources[kind] else { continue }
                group.addTask {
                    do {
                        return SourceOutcome(kind: kind, candidates: try await source.search(feed: feed, window: window))
                    } catch {
                        return SourceOutcome(kind: kind, candidates: [], failureMessage: error.localizedDescription)
                    }
                }
            }

            var outcomes: [PaperSourceKind: SourceOutcome] = [:]
            for await outcome in group {
                outcomes[outcome.kind] = outcome
            }
            return outcomes
        }
    }
}

private struct ConcurrentPaperSource: @unchecked Sendable {
    private let source: any PaperSource

    init(_ source: any PaperSource) {
        self.source = source
    }

    func search(feed: FeedConfig, window: DateInterval) async throws -> [PaperCandidate] {
        try await source.search(feed: feed, window: window)
    }
}

private struct SourceOutcome: Sendable {
    var kind: PaperSourceKind
    var candidates: [PaperCandidate]
    var failureMessage: String?

    init(kind: PaperSourceKind, candidates: [PaperCandidate], failureMessage: String? = nil) {
        self.kind = kind
        self.candidates = candidates
        self.failureMessage = failureMessage
    }
}
