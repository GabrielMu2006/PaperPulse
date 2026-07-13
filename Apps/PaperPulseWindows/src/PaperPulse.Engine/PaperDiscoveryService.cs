using PaperPulse.Contracts;

namespace PaperPulse.Engine;

public sealed record class SourceFailure(PaperSourceKind Source, Exception Error);

public sealed record class DiscoveryResult(IReadOnlyList<PaperCandidate> Candidates, IReadOnlyList<SourceFailure> Failures);

public sealed class PaperDiscoveryService
{
    private readonly IReadOnlyDictionary<PaperSourceKind, IPaperSource> sources;
    private readonly PaperCandidateMerger merger;

    public PaperDiscoveryService(IEnumerable<IPaperSource> sources, PaperCandidateMerger? merger = null)
    {
        this.sources = sources.ToDictionary(source => source.Kind);
        this.merger = merger ?? new PaperCandidateMerger();
    }

    public async Task<DiscoveryResult> DiscoverAsync(FeedConfig feed, DateTimeOffset? now = null, CancellationToken cancellationToken = default)
    {
        DateTimeOffset end = now ?? DateTimeOffset.UtcNow;
        DateTimeOffset start = end.AddDays(-feed.LookbackDays);
        List<PaperSourceKind> enabled = [];
        HashSet<PaperSourceKind> seen = [];
        foreach (PaperSourceKind kind in feed.EnabledSources)
        {
            if (kind != PaperSourceKind.Unpaywall && seen.Add(kind) && sources.ContainsKey(kind)) enabled.Add(kind);
        }

        SourceOutcome[] outcomes = await Task.WhenAll(enabled.Select(kind => SearchAsync(sources[kind], feed, start, end, cancellationToken))).ConfigureAwait(false);
        List<PaperCandidate> candidates = [];
        List<SourceFailure> failures = [];
        foreach (PaperSourceKind kind in enabled)
        {
            SourceOutcome outcome = outcomes.Single(item => item.Source == kind);
            candidates.AddRange(outcome.Candidates);
            if (outcome.Error is not null) failures.Add(new SourceFailure(kind, outcome.Error));
        }
        return new DiscoveryResult(merger.Merge(candidates), failures);
    }

    private static async Task<SourceOutcome> SearchAsync(IPaperSource source, FeedConfig feed, DateTimeOffset start, DateTimeOffset end, CancellationToken cancellationToken)
    {
        try
        {
            return new SourceOutcome(source.Kind, await source.SearchAsync(feed, start, end, cancellationToken).ConfigureAwait(false), null);
        }
        catch (Exception error)
        {
            return new SourceOutcome(source.Kind, [], error);
        }
    }

    private sealed record class SourceOutcome(PaperSourceKind Source, IReadOnlyList<PaperCandidate> Candidates, Exception? Error);
}
