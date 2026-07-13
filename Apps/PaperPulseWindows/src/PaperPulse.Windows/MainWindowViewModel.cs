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
    private readonly PaperDiscoveryService discovery;
    private readonly PaperFileStore fileStore;
    private readonly PaperPdfDownloader pdfDownloader;

    private FeedConfig? selectedFeed;
    private StoredPaper? selectedPaper;
    private string searchText = string.Empty;
    private string status = "Starting PaperPulse...";
    private bool isRefreshing;
    private bool isDownloadingPdf;
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

    public bool IsDownloadingPdf
    {
        get => isDownloadingPdf;
        set => SetProperty(ref isDownloadingPdf, value);
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
        discovery = new PaperDiscoveryService([new ArxivSource(transport), new OpenAlexSource(transport), new CrossrefSource(transport)]);
        pdfDownloader = new PaperPdfDownloader(transport);
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
        IsRefreshing = true; Status = $"Searching {SelectedFeed.Name}...";
        try
        {
            DiscoveryResult result = await discovery.DiscoverAsync(feed);
            Dictionary<string, StoredPaper> existing = Papers.ToDictionary(paper => paper.Candidate.StableId);
            List<StoredPaper> papersToSave = result.Candidates
                .Select(candidate => existing.TryGetValue(candidate.StableId, out StoredPaper? current)
                    ? current with { Candidate = candidate }
                    : new StoredPaper(candidate, null, null, DateTimeOffset.UtcNow, false))
                .ToList();
            await Task.Run(() =>
            {
                foreach (StoredPaper paper in papersToSave) repository.SavePaper(paper, feed.Id);
            });
            await ReloadAsync(feed.Id);
            Status = result.Failures.Count == 0 ? $"Found {result.Candidates.Count} papers." : $"Found {result.Candidates.Count}; {result.Failures.Count} sources unavailable.";
        }
        catch (Exception error) { Status = error.Message; }
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

    public async Task DownloadSelectedPdfAsync()
    {
        if (SelectedPaper is null || IsDownloadingPdf) return;
        StoredPaper paper = SelectedPaper;
        IsDownloadingPdf = true;
        Status = $"Downloading PDF for {paper.Candidate.Title}...";
        try
        {
            DownloadedPaperPdf downloaded = await pdfDownloader.DownloadAsync(paper.Candidate);
            await using MemoryStream input = new(downloaded.Content, writable: false);
            StoredFile stored = await fileStore.WritePdfAsync(paper.Candidate.StableId, input);
            StoredPaper updated = paper with { PdfRelativePath = stored.RelativePath, PdfSha256 = stored.Sha256 };
            await Task.Run(() => repository.SavePaper(updated));
            ReplacePaper(updated);
            Status = "PDF downloaded.";
        }
        catch (PaperPdfDownloadException error)
        {
            Status = error.Message;
        }
        catch (Exception error)
        {
            Status = $"Could not download PDF: {error.Message}";
        }
        finally
        {
            IsDownloadingPdf = false;
        }
    }

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

    private void ReplacePaper(StoredPaper updated)
    {
        int index = Papers.ToList().FindIndex(paper => paper.Candidate.StableId == updated.Candidate.StableId);
        if (index >= 0) Papers[index] = updated;
        SelectedPaper = updated;
        RefreshLibraryGroups(focusSelectedFeed: false);
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
