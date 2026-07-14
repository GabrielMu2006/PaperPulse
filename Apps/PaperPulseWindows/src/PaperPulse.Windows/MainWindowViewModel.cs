using System.Collections.ObjectModel;
using System.Net;
using System.Text.RegularExpressions;
using CommunityToolkit.Mvvm.ComponentModel;
using PaperPulse.Contracts;
using PaperPulse.Engine;
using PaperPulse.Storage;

namespace PaperPulse.Windows;

public sealed partial class MainWindowViewModel : ObservableObject
{
    private static readonly IReadOnlySet<string> EmptyPaperIds = new HashSet<string>();
    private static readonly Regex Markup = new("<[^>]+>", RegexOptions.Compiled);
    private static readonly Regex Whitespace = new("\\s+", RegexOptions.Compiled);

    private readonly SqlitePaperPulseRepository repository;
    private readonly PaperFileStore fileStore;
    private readonly PaperPushService paperPush;

    private FeedConfig? selectedFeed;
    private StoredPaper? selectedPaper;
    private string searchText = string.Empty;
    private string status = "Starting PaperPulse...";
    private bool isRefreshing;
    private bool favoritesOnly;
    private bool isInitialized;
    private IReadOnlyDictionary<Guid, IReadOnlySet<string>> paperIdsByFeed = new Dictionary<Guid, IReadOnlySet<string>>();
    private IReadOnlySet<string> unclassifiedPaperIds = EmptyPaperIds;

    public FeedConfig? SelectedFeed
    {
        get => selectedFeed;
        set
        {
            if (SetProperty(ref selectedFeed, value)) RefreshLibraryGroups(focusSelectedFeed: true);
        }
    }

    public StoredPaper? SelectedPaper
    {
        get => selectedPaper;
        set
        {
            if (!SetProperty(ref selectedPaper, value)) return;
            OnPropertyChanged(nameof(SelectedPaperTitle));
            OnPropertyChanged(nameof(SelectedPaperSummary));
            OnPropertyChanged(nameof(HasSelectedPaper));
            OnPropertyChanged(nameof(SelectedPdfPath));
            OnPropertyChanged(nameof(HasSelectedPdf));
        }
    }

    public string SelectedPaperTitle => SelectedPaper?.Candidate.Title ?? "Select a paper";
    public string SelectedPaperSummary => SelectedPaper?.Candidate.Summary ?? "Select a paper to view its abstract.";
    public bool HasSelectedPaper => SelectedPaper is not null;

    public string? SelectedPdfPath
    {
        get
        {
            if (SelectedPaper?.PdfRelativePath is not { Length: > 0 } relativePath) return null;
            try { return fileStore.ResolveRelativePath(relativePath); }
            catch (InvalidOperationException) { return null; }
        }
    }

    public bool HasSelectedPdf => SelectedPdfPath is { } path && File.Exists(path);

    public string SearchText
    {
        get => searchText;
        set
        {
            if (SetProperty(ref searchText, value)) RefreshLibraryGroups(focusSelectedFeed: false);
        }
    }

    public string Status
    {
        get => status;
        set => SetProperty(ref status, value);
    }

    public bool IsRefreshing
    {
        get => isRefreshing;
        set => SetProperty(ref isRefreshing, value);
    }

    public bool FavoritesOnly
    {
        get => favoritesOnly;
        set
        {
            if (SetProperty(ref favoritesOnly, value)) RefreshLibraryGroups(focusSelectedFeed: false);
        }
    }

    public ObservableCollection<FeedConfig> Feeds { get; } = [];
    public ObservableCollection<StoredPaper> Papers { get; } = [];
    public ObservableCollection<PaperLibraryGroup> LibraryGroups { get; } = [];

    public MainWindowViewModel()
    {
        PaperPulsePaths paths = new();
        repository = new SqlitePaperPulseRepository(paths);
        fileStore = new PaperFileStore(paths);
        HttpClient client = new() { Timeout = TimeSpan.FromSeconds(30) };
        IHttpTransport transport = new RetryingHttpTransport(new HttpClientTransport(client));
        PaperDiscoveryService discovery = new([new ArxivSource(transport), new OpenAlexSource(transport), new CrossrefSource(transport)]);
        paperPush = new PaperPushService(discovery, new PaperRanker(), new PaperPdfDownloader(transport));
    }

    public async Task InitializeAsync()
    {
        if (isInitialized) return;
        isInitialized = true;
        await ReloadAsync();
    }

    public async Task RefreshSelectedFeedAsync()
    {
        if (SelectedFeed is null || IsRefreshing) return;
        FeedConfig feed = SelectedFeed;
        IsRefreshing = true;
        Status = $"Searching {feed.Name}...";
        try
        {
            Dictionary<string, StoredPaper> existing = Papers.ToDictionary(paper => paper.Candidate.StableId);
            IReadOnlySet<string> alreadyLinked = paperIdsByFeed.TryGetValue(feed.Id, out IReadOnlySet<string>? ids)
                ? ids
                : EmptyPaperIds;
            HashSet<string> reusableLocal = existing.Values
                .Where(HasStoredPdf)
                .Select(paper => paper.Candidate.StableId)
                .ToHashSet(StringComparer.Ordinal);
            Progress<PaperPushProgress> progress = new(item => Status = $"Processing {item.Current} of {item.Total}...");
            PaperPushResult result = await paperPush.RunAsync(feed, alreadyLinked, reusableLocal, progress);
            int saved = 0;
            int writeFailures = 0;

            foreach (PaperPushAttempt attempt in result.Attempts)
            {
                if (attempt is ReusedPaperPushItem reused && existing.TryGetValue(reused.Candidate.StableId, out StoredPaper? existingPaper))
                {
                    StoredPaper linked = existingPaper with { Candidate = reused.Candidate };
                    await Task.Run(() => repository.SavePaper(linked, feed.Id));
                    saved++;
                    continue;
                }

                if (attempt is not DownloadedPaperPushItem downloaded) continue;

                try
                {
                    await using MemoryStream input = new(downloaded.Pdf.Content, writable: false);
                    StoredFile stored = await fileStore.WritePdfAsync(downloaded.Candidate.StableId, input);
                    StoredPaper paper = existing.TryGetValue(downloaded.Candidate.StableId, out StoredPaper? current)
                        ? current with
                        {
                            Candidate = downloaded.Candidate,
                            PdfRelativePath = stored.RelativePath,
                            PdfSha256 = stored.Sha256
                        }
                        : new StoredPaper(downloaded.Candidate, stored.RelativePath, stored.Sha256, DateTimeOffset.UtcNow, false);
                    await Task.Run(() => repository.SavePaper(paper, feed.Id));
                    existing[paper.Candidate.StableId] = paper;
                    saved++;
                }
                catch
                {
                    writeFailures++;
                }
            }

            await ReloadAsync(feed.Id);
            int skipped = result.Failures.Count + writeFailures;
            Status = $"{saved} saved, {skipped} skipped.";
            string failureSummary = DescribePushFailures(result.Failures, writeFailures);
            if (failureSummary.Length > 0) Status += $" {failureSummary}";
            if (result.SourceFailures.Count > 0) Status += $" {result.SourceFailures.Count} sources unavailable.";
        }
        catch { Status = "Could not finish this subscription push."; }
        finally { IsRefreshing = false; }
    }

    public async Task ToggleFavoriteAsync()
    {
        if (SelectedPaper is null) return;
        StoredPaper paper = SelectedPaper;
        bool isFavorite = !paper.IsFavorite;
        try
        {
            await Task.Run(() => repository.SetFavorite(paper.Candidate.StableId, isFavorite));
            StoredPaper updated = paper with { IsFavorite = isFavorite };
            int index = Papers.ToList().FindIndex(candidate => candidate.Candidate.StableId == paper.Candidate.StableId);
            if (index >= 0) Papers[index] = updated;
            SelectedPaper = updated;
            RefreshLibraryGroups(focusSelectedFeed: false);
            Status = isFavorite ? "Added to favorites." : "Removed from favorites.";
        }
        catch (Exception error)
        {
            Status = $"Could not update favorite: {error.Message}";
        }
    }

    public void ToggleFavoritesFilter() => FavoritesOnly = !FavoritesOnly;

    public async Task SaveFeedAsync(FeedConfig feed)
    {
        if (string.IsNullOrWhiteSpace(feed.Name))
        {
            Status = "A subscription needs a name.";
            return;
        }

        await Task.Run(() => repository.SaveFeed(feed));
        await ReloadAsync(feed.Id);
        Status = $"Saved {feed.Name}.";
    }

    public async Task<bool> DeleteSelectedFeedAsync()
    {
        if (SelectedFeed is null) return false;
        string name = SelectedFeed.Name;
        Guid id = SelectedFeed.Id;
        SelectedFeed = null;
        await Task.Run(() => repository.DeleteFeed(id));
        await ReloadAsync();
        Status = $"Deleted {name}.";
        return true;
    }

    public void SelectPaper(StoredPaper? paper)
    {
        if (paper is not null) SelectedPaper = paper;
    }

    private async Task ReloadAsync(Guid? preferredFeedId = null)
    {
        Status = "Loading library...";
        try
        {
            LibrarySnapshot snapshot = await Task.Run(ReadLibrarySnapshot);
            ApplySnapshot(snapshot, preferredFeedId);
            Status = "Ready";
        }
        catch (Exception error)
        {
            Status = $"Could not load the library: {error.Message}";
        }
    }

    private LibrarySnapshot ReadLibrarySnapshot()
    {
        List<FeedConfig> feeds = repository.LoadFeeds().ToList();
        if (feeds.Count == 0)
        {
            FeedConfig feed = new() { Name = "Agent Research", Keywords = ["agent"] };
            repository.SaveFeed(feed);
            feeds.Add(feed);
        }

        List<StoredPaper> papers = repository.LoadPapers().Select(NormalizeForDisplay).ToList();
        IReadOnlyDictionary<Guid, IReadOnlySet<string>> memberships = feeds.ToDictionary(
            feed => feed.Id,
            feed => repository.PaperIdsForFeed(feed.Id));
        return new LibrarySnapshot(feeds, papers, memberships, repository.UnclassifiedPaperIds());
    }

    private void ApplySnapshot(LibrarySnapshot snapshot, Guid? preferredFeedId)
    {
        Guid? selectedFeedId = preferredFeedId ?? SelectedFeed?.Id;
        Feeds.Clear(); foreach (FeedConfig feed in snapshot.Feeds) Feeds.Add(feed);
        Papers.Clear(); foreach (StoredPaper paper in snapshot.Papers) Papers.Add(paper);
        paperIdsByFeed = snapshot.PaperIdsByFeed;
        unclassifiedPaperIds = snapshot.UnclassifiedPaperIds;
        SelectedFeed = Feeds.FirstOrDefault(feed => feed.Id == selectedFeedId) ?? Feeds[0];
        RefreshLibraryGroups(focusSelectedFeed: true);
    }

    private void RefreshLibraryGroups(bool focusSelectedFeed)
    {
        Dictionary<string, bool> expanded = LibraryGroups.ToDictionary(group => group.Key, group => group.IsExpanded);
        IReadOnlyList<PaperLibraryGroupDefinition> definitions = PaperLibraryGrouping.Create(
            Feeds,
            Papers,
            feedId => paperIdsByFeed.TryGetValue(feedId, out IReadOnlySet<string>? ids) ? ids : EmptyPaperIds,
            unclassifiedPaperIds,
            SearchText,
            FavoritesOnly);

        LibraryGroups.Clear();
        foreach (PaperLibraryGroupDefinition definition in definitions)
        {
            bool isExpanded = PaperLibraryGrouping.IsExpanded(
                definition,
                SelectedFeed?.Id,
                focusSelectedFeed,
                expanded);
            LibraryGroups.Add(new PaperLibraryGroup(definition, isExpanded));
        }

        if (SelectedPaper is not null && !LibraryGroups.SelectMany(group => group.Papers).Any(paper => paper.Candidate.StableId == SelectedPaper.Candidate.StableId)) SelectedPaper = null;
    }

    private bool HasStoredPdf(StoredPaper paper)
    {
        if (paper.PdfRelativePath is not { Length: > 0 } relativePath) return false;
        try { return File.Exists(fileStore.ResolveRelativePath(relativePath)); }
        catch (InvalidOperationException) { return false; }
    }

    private static string DescribePushFailures(IReadOnlyList<PaperPushFailure> failures, int writeFailures)
    {
        List<string> messages = [];
        if (failures.Any(failure => failure.Failure == PaperPdfDownloadFailure.HttpStatus)) messages.Add("Some sources refused direct PDF access.");
        if (failures.Any(failure => failure.Failure is PaperPdfDownloadFailure.UnverifiedOpenAccess or PaperPdfDownloadFailure.MissingPdfUrl)) messages.Add("Some papers have no verified open-access PDF.");
        if (failures.Any(failure => failure.Failure is PaperPdfDownloadFailure.InvalidMimeType or PaperPdfDownloadFailure.InvalidPdfSignature or PaperPdfDownloadFailure.FileTooSmall or PaperPdfDownloadFailure.FileTooLarge)) messages.Add("Some sources did not return a valid PDF.");
        if (writeFailures > 0) messages.Add("Some local PDF files could not be saved.");
        return string.Join(" ", messages);
    }

    private static StoredPaper NormalizeForDisplay(StoredPaper paper) => paper with
    {
        Candidate = paper.Candidate with { Summary = DisplaySummary(paper.Candidate.Summary) }
    };

    private static string DisplaySummary(string? value)
    {
        if (string.IsNullOrWhiteSpace(value)) return "No abstract provided by this source.";
        string decoded = WebUtility.HtmlDecode(value);
        string plainText = Whitespace.Replace(Markup.Replace(decoded, " "), " ").Trim();
        return plainText.Length == 0 ? "No abstract provided by this source." : plainText;
    }

    private sealed record LibrarySnapshot(
        IReadOnlyList<FeedConfig> Feeds,
        IReadOnlyList<StoredPaper> Papers,
        IReadOnlyDictionary<Guid, IReadOnlySet<string>> PaperIdsByFeed,
        IReadOnlySet<string> UnclassifiedPaperIds);
}
