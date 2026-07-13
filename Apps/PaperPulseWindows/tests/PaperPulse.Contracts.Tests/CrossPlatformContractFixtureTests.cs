using System.Text.Json;
using PaperPulse.Contracts;
using Xunit;

namespace PaperPulse.Contracts.Tests;

public sealed class CrossPlatformContractFixtureTests
{
    [Fact]
    public void SharedFixturePreservesSwiftFeedMigrationAndPaperIdentity()
    {
        using JsonDocument document = JsonDocument.Parse(File.ReadAllText(FixturePath));

        FeedConfig feed = document.RootElement.GetProperty("feed").Deserialize<FeedConfig>(PaperPulseJson.Options)!;
        PaperCandidate candidate = document.RootElement.GetProperty("candidate").Deserialize<PaperCandidate>(PaperPulseJson.Options)!;

        Assert.Equal(new[] { PaperSourceKind.Arxiv, PaperSourceKind.OpenAlex }, feed.EnabledSources);
        Assert.Equal(7, feed.LookbackDays);
        Assert.Equal("Agent Paper", candidate.Title);
        Assert.Equal("A reliable summary.", candidate.Summary);
        Assert.Equal("2607.00003v1", candidate.SourceId);
        Assert.Equal("2607.00003", candidate.BaseId);
        Assert.Equal(new[] { "Ada Lovelace", "Grace Hopper" }, candidate.Authors);
        Assert.Equal("doi:10.1000/example", candidate.StableId);
        Assert.Equal(new DateTimeOffset(2001, 1, 1, 0, 0, 0, TimeSpan.Zero), candidate.PublishedAt);
        Assert.Equal(new DateTimeOffset(2001, 1, 1, 0, 0, 1, 500, TimeSpan.Zero), candidate.Provenance[0].RetrievedAt);
        Assert.Equal(new Uri("https://openalex.org/W123"), candidate.Provenance[0].SourceUrl);
        Assert.Equal(OpenAccessStatus.Verified, candidate.OpenAccessEvidence!.Status);
        Assert.Equal(PaperSourceKind.Unpaywall, candidate.OpenAccessEvidence.Source);
        Assert.Equal(new Uri("https://repository.example/paper.pdf"), candidate.OpenAccessEvidence.Url);
        Assert.Equal(new DateTimeOffset(2001, 1, 1, 0, 0, 2, TimeSpan.Zero), candidate.OpenAccessEvidence.VerifiedAt);

        JsonElement encoded = JsonSerializer.SerializeToElement(candidate, PaperPulseJson.Options);
        Assert.Equal(JsonValueKind.Number, encoded.GetProperty("publishedAt").ValueKind);
        Assert.Equal(0, encoded.GetProperty("publishedAt").GetDouble());
        Assert.Equal("2607.00003v1", encoded.GetProperty("sourceID").GetString());
        Assert.Equal("2607.00003", encoded.GetProperty("baseID").GetString());
        Assert.Equal("openAlex", encoded.GetProperty("provenance")[0].GetProperty("source").GetString());
        Assert.Equal("W123", encoded.GetProperty("provenance")[0].GetProperty("sourceID").GetString());
        Assert.Equal("https://openalex.org/W123", encoded.GetProperty("provenance")[0].GetProperty("sourceURL").GetString());
        Assert.False(encoded.TryGetProperty("stableId", out _));
    }

    private static string FixturePath => Path.Combine(AppContext.BaseDirectory, "Fixtures", "phase1_core_contract.json");
}
