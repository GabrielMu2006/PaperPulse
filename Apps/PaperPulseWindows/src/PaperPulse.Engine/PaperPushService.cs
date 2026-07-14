using PaperPulse.Contracts;

namespace PaperPulse.Engine;

public abstract record PaperPushAttempt(PaperCandidate Candidate);

public sealed record DownloadedPaperPushItem(PaperCandidate Candidate, DownloadedPaperPdf Pdf) : PaperPushAttempt(Candidate);

public sealed record ReusedPaperPushItem(PaperCandidate Candidate) : PaperPushAttempt(Candidate);

public sealed record PaperPushFailure(PaperCandidate Candidate, PaperPdfDownloadFailure? Failure, string Message) : PaperPushAttempt(Candidate);

public sealed record PaperPushProgress(int Current, int Total, PaperCandidate Candidate);

public sealed record PaperPushResult(IReadOnlyList<PaperPushAttempt> Attempts, IReadOnlyList<SourceFailure> SourceFailures)
{
    public IReadOnlyList<DownloadedPaperPushItem> Downloaded => Attempts.OfType<DownloadedPaperPushItem>().ToList();
    public IReadOnlyList<ReusedPaperPushItem> Reused => Attempts.OfType<ReusedPaperPushItem>().ToList();
    public IReadOnlyList<PaperPushFailure> Failures => Attempts.OfType<PaperPushFailure>().ToList();
}

public sealed class PaperPushService(
    PaperDiscoveryService discovery,
    PaperRanker ranker,
    PaperPdfDownloader downloader,
    Func<DateTimeOffset>? now = null)
{
    public const int MaximumPapersPerPush = 10;

    private readonly Func<DateTimeOffset> now = now ?? (() => DateTimeOffset.UtcNow);

    public static int EffectiveLimit(FeedConfig feed) => Math.Clamp(feed.AuthorityPolicy.DailyLimit, 1, MaximumPapersPerPush);

    public async Task<PaperPushResult> RunAsync(
        FeedConfig feed,
        IReadOnlySet<string> alreadyLinkedPaperIds,
        IReadOnlySet<string> reusableLocalPaperIds,
        IProgress<PaperPushProgress>? progress = null,
        CancellationToken cancellationToken = default)
    {
        DateTimeOffset currentTime = now();
        DiscoveryResult discoveryResult = await discovery.DiscoverAsync(feed, currentTime, cancellationToken).ConfigureAwait(false);
        IReadOnlyList<RankedPaper> ranked = ranker.Rank(
            discoveryResult.Candidates.Where(candidate =>
                !alreadyLinkedPaperIds.Contains(candidate.StableId) || !reusableLocalPaperIds.Contains(candidate.StableId)),
            feed,
            currentTime,
            EffectiveLimit(feed));
        List<PaperPushAttempt> attempts = [];

        foreach (RankedPaper rankedPaper in ranked)
        {
            cancellationToken.ThrowIfCancellationRequested();
            PaperCandidate candidate = rankedPaper.Candidate;
            progress?.Report(new PaperPushProgress(attempts.Count + 1, ranked.Count, candidate));
            if (reusableLocalPaperIds.Contains(candidate.StableId))
            {
                attempts.Add(new ReusedPaperPushItem(candidate));
                continue;
            }

            try
            {
                DownloadedPaperPdf pdf = await downloader.DownloadAsync(candidate, cancellationToken).ConfigureAwait(false);
                attempts.Add(new DownloadedPaperPushItem(candidate, pdf));
            }
            catch (PaperPdfDownloadException error)
            {
                attempts.Add(new PaperPushFailure(candidate, error.Failure, error.Message));
            }
            catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
            {
                throw;
            }
            catch (Exception error)
            {
                attempts.Add(new PaperPushFailure(candidate, null, error.Message));
            }
        }

        return new PaperPushResult(attempts, discoveryResult.Failures);
    }
}
