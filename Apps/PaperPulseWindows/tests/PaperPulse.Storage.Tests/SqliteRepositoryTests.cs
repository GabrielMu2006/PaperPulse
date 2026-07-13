using PaperPulse.Contracts;
using PaperPulse.Storage;
using Xunit;

namespace PaperPulse.Storage.Tests;

public sealed class SqliteRepositoryTests : IDisposable
{
    private readonly string directory = Path.Combine(Path.GetTempPath(), "PaperPulseStorageTests", Guid.NewGuid().ToString("N"));

    [Fact]
    public void RepositoryStoresOnePaperAcrossFeedsAndKeepsOrphansUntilCleared()
    {
        SqlitePaperPulseRepository repository = new(new PaperPulsePaths(directory));
        FeedConfig first = new() { Name = "Agents" };
        FeedConfig second = new() { Name = "Robotics" };
        PaperCandidate candidate = new(PaperSourceKind.Arxiv, "2607.00001v1", "Shared paper", "agent") { BaseId = "2607.00001" };
        StoredPaper paper = new(candidate, "PDFs/shared.pdf", "abc", DateTimeOffset.UnixEpoch, false);

        repository.SaveFeed(first);
        repository.SaveFeed(second);
        repository.SavePaper(paper, first.Id);
        repository.SavePaper(paper, second.Id);

        Assert.Single(repository.LoadPapers());
        Assert.Equal(new[] { candidate.StableId }, repository.PaperIdsForFeed(first.Id));
        repository.DeleteFeed(first.Id);
        Assert.Empty(repository.UnclassifiedPaperIds());
        repository.DeleteFeed(second.Id);
        Assert.Equal(new[] { candidate.StableId }, repository.UnclassifiedPaperIds());
        Assert.Equal(1, repository.ClearUnclassifiedPapers());
        Assert.Empty(repository.LoadPapers());
    }

    [Fact]
    public void RepositoryPersistsFavoriteAndNonSensitiveSettingAcrossInstances()
    {
        PaperPulsePaths paths = new(directory);
        SqlitePaperPulseRepository first = new(paths);
        PaperCandidate candidate = new(PaperSourceKind.Web, "https://example.com/paper", "Paper", "") ;
        first.SavePaper(new StoredPaper(candidate, null, null, DateTimeOffset.UnixEpoch, false));
        first.SetFavorite(candidate.StableId, true);
        first.SetSetting("splitRatio", "0.5");

        SqlitePaperPulseRepository second = new(paths);
        Assert.True(Assert.Single(second.LoadPapers()).IsFavorite);
        Assert.Equal("0.5", second.GetSetting("splitRatio"));
    }

    [Fact]
    public async Task FileStoreUsesRelativePdfPathAndCredentialStoreNeverTouchesDatabase()
    {
        PaperPulsePaths paths = new(directory);
        PaperFileStore files = new(paths);
        await using MemoryStream input = new("%PDF-1.7\nfixture"u8.ToArray());
        StoredFile stored = await files.WritePdfAsync("arxiv:2607.00001", input);
        InMemoryCredentialStore credentials = new();
        await credentials.SetAsync("profile-id", "secret-value");

        Assert.StartsWith("PDFs", stored.RelativePath, StringComparison.Ordinal);
        Assert.True(File.Exists(files.ResolveRelativePath(stored.RelativePath)));
        Assert.Equal("secret-value", await credentials.GetAsync("profile-id"));
        Assert.False(File.Exists(paths.DatabasePath));
    }

    [Fact]
    public async Task FullSummaryDeletionOnlyRemovesItsOwnMarkdownAndProfileJsonHasNoSecret()
    {
        PaperPulsePaths paths = new(directory); PaperFileStore files = new(paths); SqlitePaperPulseRepository repository = new(paths);
        string firstPath = await files.WriteInterpretationAsync("arxiv:first", "# First");
        string secondPath = await files.WriteInterpretationAsync("arxiv:second", "# Second");
        repository.SaveSummary(new StoredSummary(Guid.NewGuid(), "arxiv:first", "full", "{\"kind\":\"full\",\"model\":\"test\"}", firstPath));
        repository.SaveSummary(new StoredSummary(Guid.NewGuid(), "arxiv:second", "full", "{\"kind\":\"full\"}", secondPath));
        Guid profileId = Guid.NewGuid(); repository.SaveProfileConfiguration(new StoredProfileConfiguration(profileId, "{\"model\":\"gpt\"}"));

        string? deleted = repository.DeleteFullSummary("arxiv:first"); if (deleted is not null) files.DeleteRelativeFile(deleted);

        Assert.False(File.Exists(files.ResolveRelativePath(firstPath)));
        Assert.True(File.Exists(files.ResolveRelativePath(secondPath)));
        Assert.NotNull(repository.FullSummaryFor("arxiv:second"));
        Assert.Equal("{\"model\":\"gpt\"}", Assert.Single(repository.LoadProfileConfigurations()).ConfigurationJson);
    }

    public void Dispose()
    {
        if (Directory.Exists(directory)) Directory.Delete(directory, recursive: true);
    }
}
