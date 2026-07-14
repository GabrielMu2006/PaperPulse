using System.Text.Json;
using PaperPulse.Contracts;
using PaperPulse.Engine;
using Xunit;

namespace PaperPulse.Engine.Tests;

public sealed class RetrievalAndRankingTests
{
    [Fact]
    public async Task SourcesBuildExpectedRequestsAndMapResponses()
    {
        const string arxivXml = """
            <feed xmlns="http://www.w3.org/2005/Atom">
              <entry>
                <id>http://arxiv.org/abs/2607.05174v2</id>
                <title>Verified arXiv paper</title>
                <summary>Open paper.</summary>
                <published>2026-07-08T09:00:00Z</published>
                <updated>2026-07-08T10:00:00Z</updated>
                <link href="https://arxiv.org/pdf/2607.05174v2.pdf" title="pdf" type="application/pdf" />
              </entry>
            </feed>
            """;
        const string openAlexJson = """
            {"results":[{"id":"https://openalex.org/W123","doi":"https://doi.org/10.1145/example","display_name":"Open Agent Benchmarks","publication_date":"2026-07-08","cited_by_count":42,"abstract_inverted_index":{"Agents":[0],"coordinate":[1],"tools.":[2]},"authorships":[{"author":{"display_name":"A. Researcher"},"institutions":[{"display_name":"Stanford University"}]}],"open_access":{"oa_url":"https://publisher.example/landing"},"best_oa_location":{"pdf_url":"https://repository.example/open-agent-benchmarks.pdf"},"primary_location":{"source":{"display_name":"ExampleConf"}}},{"id":"https://openalex.org/W124","display_name":"Landing Page Only","publication_date":"2026-07-08","open_access":{"oa_url":"https://publisher.example/landing-only"},"primary_location":{"source":{"display_name":"ExampleConf"}}},{"id":"https://openalex.org/W125","display_name":"Primary PDF Location","publication_date":"2026-07-08","primary_location":{"pdf_url":"https://repository.example/primary-location.pdf","source":{"display_name":"ExampleConf"}}}]}
            """;
        const string crossrefJson = """
            {"message":{"items":[{"DOI":"10.5555/crossref.example","title":["Crossref Agent Evaluation"],"abstract":"<jats:p>A <jats:italic>metadata-rich</jats:italic> agent evaluation paper.</jats:p>","author":[{"given":"Ada","family":"Lovelace"}],"issued":{"date-parts":[[2026,7,7]]},"URL":"https://doi.org/10.5555/crossref.example","container-title":["Journal of Agent Systems"],"link":[{"URL":"https://publisher.example/crossref-agent.pdf","content-type":"application/pdf"}]}]}}
            """;

        List<Uri> observedUris = [];
        StubTransport transport = new(request =>
        {
            observedUris.Add(request.RequestUri!);
            string payload = request.RequestUri!.Host switch
            {
                "export.arxiv.org" => arxivXml,
                "api.openalex.org" => openAlexJson,
                "api.crossref.org" => crossrefJson,
                _ => throw new InvalidOperationException("Unexpected source host.")
            };
            return Task.FromResult(Response(request.RequestUri, payload));
        });
        FeedConfig feed = new()
        {
            Name = "LLM Agents",
            Keywords = ["agent"],
            AuthorityPolicy = new AuthorityPolicy { DailyLimit = 3 }
        };
        DateTimeOffset start = new(2026, 7, 1, 0, 0, 0, TimeSpan.Zero);
        DateTimeOffset end = new(2026, 7, 9, 0, 0, 0, TimeSpan.Zero);

        IReadOnlyList<PaperCandidate> arxiv = await new ArxivSource(transport).SearchAsync(feed, start, end);
        IReadOnlyList<PaperCandidate> openAlex = await new OpenAlexSource(transport).SearchAsync(feed, start, end);
        IReadOnlyList<PaperCandidate> crossref = await new CrossrefSource(transport).SearchAsync(feed, start, end);

        Assert.Equal("2607.05174v2", arxiv[0].SourceId);
        Assert.Equal(OpenAccessStatus.Verified, arxiv[0].OpenAccessEvidence!.Status);
        Assert.Equal("10.1145/example", openAlex[0].Doi);
        Assert.Equal(new Uri("https://repository.example/open-agent-benchmarks.pdf"), openAlex[0].OpenAccessEvidence!.Url);
        Assert.Null(openAlex[1].OpenAccessEvidence);
        Assert.Equal(new Uri("https://repository.example/primary-location.pdf"), openAlex[2].OpenAccessEvidence!.Url);
        Assert.Equal("Agents coordinate tools.", openAlex[0].Summary);
        Assert.Equal(["A. Researcher"], openAlex[0].Authors);
        Assert.Equal("10.5555/crossref.example", crossref[0].SourceId);
        Assert.Equal(["Ada Lovelace"], crossref[0].Authors);
        Assert.Equal("A metadata-rich agent evaluation paper.", crossref[0].Summary);
        Assert.Null(crossref[0].OpenAccessEvidence);
        Assert.Contains("from_publication_date:2026-07-01,to_publication_date:2026-07-09", Uri.UnescapeDataString(observedUris[1].Query));
        Assert.Contains("from-pub-date:2026-07-01,until-pub-date:2026-07-09", Uri.UnescapeDataString(observedUris[2].Query));
    }

    [Fact]
    public void SharedRetrievalFixturePreservesMergeAndRankOrder()
    {
        using JsonDocument document = JsonDocument.Parse(File.ReadAllText(FixturePath));
        FeedConfig feed = document.RootElement.GetProperty("feed").Deserialize<FeedConfig>(PaperPulseJson.Options)!;
        List<PaperCandidate> candidates = document.RootElement.GetProperty("candidates").Deserialize<List<PaperCandidate>>(PaperPulseJson.Options)!;
        DateTimeOffset now = document.RootElement.GetProperty("now").Deserialize<DateTimeOffset>(PaperPulseJson.Options);
        JsonElement expected = document.RootElement.GetProperty("expected");

        IReadOnlyList<PaperCandidate> merged = new PaperCandidateMerger().Merge(candidates);
        IReadOnlyList<RankedPaper> ranked = new PaperRanker().Rank(merged, feed, now);

        Assert.Equal(expected.GetProperty("mergedSourceIDs").Deserialize<string[]>(), merged.Select(candidate => candidate.SourceId));
        Assert.Equal(expected.GetProperty("rankedSourceIDs").Deserialize<string[]>(), ranked.Select(paper => paper.Candidate.SourceId));
        Assert.Equal(["Ada", "Grace"], merged[0].Authors);
        Assert.Equal("ExampleConf", merged[0].Venue);
        Assert.Contains("preferred institution", ranked[0].Reasons);
    }

    [Fact]
    public async Task RetryingTransportRetriesRateLimitsAndReturnsFinalResponse()
    {
        Queue<int> statuses = new([429, 503, 200]);
        List<TimeSpan> delays = [];
        StubTransport inner = new(request => Task.FromResult(Response(request.RequestUri!, string.Empty, statuses.Dequeue())));
        RetryingHttpTransport transport = new(inner, new HttpRetryPolicy(maximumRetryCount: 2, baseDelay: TimeSpan.FromMilliseconds(250)), delay =>
        {
            delays.Add(delay);
            return Task.CompletedTask;
        });

        HttpResponse response = await transport.SendAsync(new HttpRequestMessage(HttpMethod.Get, "https://example.com/papers"));

        Assert.Equal(200, response.StatusCode);
        Assert.Equal([TimeSpan.FromMilliseconds(250), TimeSpan.FromMilliseconds(500)], delays);
    }

    [Fact]
    public async Task PdfDownloaderAcceptsOnlyVerifiedHttpsPdfResponses()
    {
        PaperCandidate paper = new(
            PaperSourceKind.Arxiv,
            "2607.00001",
            "Verified PDF",
            "",
            openAccessPdfUrl: new Uri("https://example.org/paper.pdf"),
            openAccessEvidence: new OpenAccessEvidence
            {
                Status = OpenAccessStatus.Verified,
                Source = PaperSourceKind.Arxiv,
                Url = new Uri("https://example.org/paper.pdf")
            });
        StubTransport transport = new(request => Task.FromResult(new HttpResponse(
            "%PDF-1.7 test"u8.ToArray(),
            200,
            "application/pdf",
            request.RequestUri!)));
        PaperPdfDownloader downloader = new(transport, minimumBytes: 4);

        DownloadedPaperPdf downloaded = await downloader.DownloadAsync(paper);

        Assert.Equal("application/pdf", downloaded.MimeType);
        Assert.Equal("%PDF", System.Text.Encoding.UTF8.GetString(downloaded.Content[..4]));
        Assert.Equal(64, downloaded.Sha256.Length);

        PaperCandidate unverified = paper with
        {
            OpenAccessEvidence = new OpenAccessEvidence { Status = OpenAccessStatus.Unverified, Source = PaperSourceKind.Crossref }
        };
        PaperPdfDownloadException error = await Assert.ThrowsAsync<PaperPdfDownloadException>(() => downloader.DownloadAsync(unverified));
        Assert.Equal(PaperPdfDownloadFailure.UnverifiedOpenAccess, error.Failure);
    }

    [Fact]
    public async Task DiscoveryUsesEnabledSourcesAndKeepsPartialResults()
    {
        RecordingSource arxiv = new(PaperSourceKind.Arxiv, [new PaperCandidate(PaperSourceKind.Arxiv, "2607.00001v1", "arXiv result", "")]);
        RecordingSource openAlex = new(PaperSourceKind.OpenAlex, error: new InvalidOperationException("unavailable"));
        RecordingSource ignored = new(PaperSourceKind.Crossref, [new PaperCandidate(PaperSourceKind.Crossref, "ignored", "ignored", "")]);
        PaperDiscoveryService service = new([arxiv, openAlex, ignored]);
        DateTimeOffset now = DateTimeOffset.FromUnixTimeSeconds(1_783_000_000);
        FeedConfig feed = new() { Name = "Agents", EnabledSources = new List<PaperSourceKind> { PaperSourceKind.OpenAlex, PaperSourceKind.Arxiv }, LookbackDays = 3 };

        DiscoveryResult result = await service.DiscoverAsync(feed, now);

        Assert.Equal(["2607.00001v1"], result.Candidates.Select(candidate => candidate.SourceId));
        Assert.Equal(PaperSourceKind.OpenAlex, Assert.Single(result.Failures).Source);
        Assert.Equal(new[] { (now.AddDays(-3), now) }, arxiv.Windows);
        Assert.Equal(new[] { (now.AddDays(-3), now) }, openAlex.Windows);
        Assert.Empty(ignored.Windows);
    }

    [Theory]
    [InlineData(-4, 1)]
    [InlineData(1, 1)]
    [InlineData(8, 8)]
    [InlineData(10, 10)]
    [InlineData(99, 10)]
    public void FeedPushClampsTheProcessingLimitToTen(int configuredLimit, int expectedLimit)
    {
        FeedConfig feed = new() { AuthorityPolicy = new AuthorityPolicy { DailyLimit = configuredLimit } };

        Assert.Equal(expectedLimit, PaperPushService.EffectiveLimit(feed));
    }

    [Fact]
    public async Task FeedPushAttemptsAtMostTenPapersAndContinuesAfterPerPaperFailures()
    {
        List<PaperCandidate> candidates = Enumerable.Range(1, 10)
            .Select(index => Candidate($"paper-{index:D2}", index == 3 ? OpenAccessStatus.Unverified : OpenAccessStatus.Verified))
            .ToList();
        RecordingSource source = new(PaperSourceKind.Arxiv, candidates);
        StubTransport transport = new(request => Task.FromResult(PdfResponse(
            request.RequestUri!,
            request.RequestUri!.AbsolutePath.Contains("paper-05", StringComparison.Ordinal) ? 403 : 200)));
        PaperPushService service = new(
            new PaperDiscoveryService([source]),
            new PaperRanker(),
            new PaperPdfDownloader(transport, minimumBytes: 4),
            () => new DateTimeOffset(2026, 7, 10, 0, 0, 0, TimeSpan.Zero));
        FeedConfig feed = new() { AuthorityPolicy = new AuthorityPolicy { DailyLimit = 99 } };

        PaperPushResult result = await service.RunAsync(feed, new HashSet<string>(), new HashSet<string>());

        Assert.Equal(10, result.Attempts.Count);
        Assert.Equal(2, result.Attempts.OfType<PaperPushFailure>().Count());
        Assert.Equal(8, result.Attempts.OfType<DownloadedPaperPushItem>().Count());
        Assert.Contains(result.Attempts.OfType<DownloadedPaperPushItem>(), item => item.Candidate.SourceId == "paper-10");
    }

    [Fact]
    public async Task FeedPushReusesAStoredPdfAcrossFeedsAndRetriesAnIncompleteLink()
    {
        PaperCandidate reused = Candidate("paper-01", OpenAccessStatus.Verified);
        PaperCandidate incomplete = Candidate("paper-02", OpenAccessStatus.Verified);
        RecordingSource source = new(PaperSourceKind.Arxiv, [reused, incomplete]);
        int downloads = 0;
        StubTransport transport = new(request =>
        {
            downloads++;
            return Task.FromResult(PdfResponse(request.RequestUri!));
        });
        PaperPushService service = new(
            new PaperDiscoveryService([source]),
            new PaperRanker(),
            new PaperPdfDownloader(transport, minimumBytes: 4),
            () => new DateTimeOffset(2026, 7, 10, 0, 0, 0, TimeSpan.Zero));
        FeedConfig feed = new() { AuthorityPolicy = new AuthorityPolicy { DailyLimit = 10 } };

        PaperPushResult result = await service.RunAsync(
            feed,
            new HashSet<string> { incomplete.StableId },
            new HashSet<string> { reused.StableId });

        Assert.Single(result.Attempts.OfType<ReusedPaperPushItem>());
        Assert.Single(result.Attempts.OfType<DownloadedPaperPushItem>());
        Assert.Equal(1, downloads);
        Assert.Contains(result.Attempts.OfType<DownloadedPaperPushItem>(), item => item.Candidate.StableId == incomplete.StableId);
    }

    private static HttpResponse Response(Uri uri, string payload, int statusCode = 200) =>
        new(System.Text.Encoding.UTF8.GetBytes(payload), statusCode, "application/json", uri);

    private static HttpResponse PdfResponse(Uri uri, int statusCode = 200) =>
        new("%PDF-1.7 test"u8.ToArray(), statusCode, "application/pdf", uri);

    private static PaperCandidate Candidate(string sourceId, OpenAccessStatus status) => new(
        PaperSourceKind.Arxiv,
        sourceId,
        sourceId,
        string.Empty,
        publishedAt: new DateTimeOffset(2026, 7, 9, 0, 0, 0, TimeSpan.Zero),
        openAccessPdfUrl: new Uri($"https://repository.example/{sourceId}.pdf"),
        openAccessEvidence: new OpenAccessEvidence
        {
            Status = status,
            Source = PaperSourceKind.Arxiv,
            Url = new Uri($"https://repository.example/{sourceId}.pdf")
        });

    private static string FixturePath => Path.Combine(AppContext.BaseDirectory, "Fixtures", "phase1_retrieval_contract.json");

    private sealed class StubTransport(Func<HttpRequestMessage, Task<HttpResponse>> handler) : IHttpTransport
    {
        public Task<HttpResponse> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken = default) => handler(request);
    }

    private sealed class RecordingSource : IPaperSource
    {
        private readonly IReadOnlyList<PaperCandidate> results;
        private readonly Exception? error;

        public RecordingSource(PaperSourceKind kind, IReadOnlyList<PaperCandidate>? results = null, Exception? error = null)
        {
            Kind = kind;
            this.results = results ?? [];
            this.error = error;
        }

        public PaperSourceKind Kind { get; }
        public List<(DateTimeOffset Start, DateTimeOffset End)> Windows { get; } = [];

        public Task<IReadOnlyList<PaperCandidate>> SearchAsync(FeedConfig feed, DateTimeOffset start, DateTimeOffset end, CancellationToken cancellationToken = default)
        {
            Windows.Add((start, end));
            return error is null ? Task.FromResult(results) : Task.FromException<IReadOnlyList<PaperCandidate>>(error);
        }
    }
}
