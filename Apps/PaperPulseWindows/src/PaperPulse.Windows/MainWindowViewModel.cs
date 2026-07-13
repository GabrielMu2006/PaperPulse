using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using PaperPulse.Contracts;
using PaperPulse.Engine;
using PaperPulse.Storage;

namespace PaperPulse.Windows;

public sealed partial class MainWindowViewModel : ObservableObject
{
    private readonly SqlitePaperPulseRepository repository;
    private readonly PaperDiscoveryService discovery;

    private FeedConfig? selectedFeed;
    private StoredPaper? selectedPaper;
    private string searchText = string.Empty;
    private string status = "Ready";
    private bool isRefreshing;
    private bool favoritesOnly;

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
        set => SetProperty(ref selectedPaper, value);
    }

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
        HttpClient client = new() { Timeout = TimeSpan.FromSeconds(30) };
        IHttpTransport transport = new RetryingHttpTransport(new HttpClientTransport(client));
        discovery = new PaperDiscoveryService([new ArxivSource(transport), new OpenAlexSource(transport), new CrossrefSource(transport)]);
        Load();
    }

    public async Task RefreshSelectedFeedAsync()
    {
        if (SelectedFeed is null || IsRefreshing) return;
        IsRefreshing = true; Status = $"Searching {SelectedFeed.Name}...";
        try
        {
            DiscoveryResult result = await discovery.DiscoverAsync(SelectedFeed);
            Dictionary<string, StoredPaper> existing = Papers.ToDictionary(paper => paper.Candidate.StableId);
            foreach (PaperCandidate candidate in result.Candidates)
            {
                StoredPaper stored = existing.TryGetValue(candidate.StableId, out StoredPaper? current)
                    ? current with { Candidate = candidate }
                    : new StoredPaper(candidate, null, null, DateTimeOffset.UtcNow, false);
                repository.SavePaper(stored, SelectedFeed.Id);
            }
            Load();
            Status = result.Failures.Count == 0 ? $"Found {result.Candidates.Count} papers." : $"Found {result.Candidates.Count}; {result.Failures.Count} sources unavailable.";
        }
        catch (Exception error) { Status = error.Message; }
        finally { IsRefreshing = false; }
    }

    public void ToggleFavorite()
    {
        if (SelectedPaper is null) return;
        repository.SetFavorite(SelectedPaper.Candidate.StableId, !SelectedPaper.IsFavorite);
        Load();
    }

    public void ToggleFavoritesFilter() => FavoritesOnly = !FavoritesOnly;

    public void SaveFeed(FeedConfig feed)
    {
        if (string.IsNullOrWhiteSpace(feed.Name))
        {
            Status = "A subscription needs a name.";
            return;
        }

        repository.SaveFeed(feed);
        Load();
        SelectedFeed = Feeds.FirstOrDefault(candidate => candidate.Id == feed.Id);
        Status = $"Saved {feed.Name}.";
    }

    public bool DeleteSelectedFeed()
    {
        if (SelectedFeed is null) return false;
        string name = SelectedFeed.Name;
        repository.DeleteFeed(SelectedFeed.Id);
        SelectedFeed = null;
        Load();
        Status = $"Deleted {name}.";
        return true;
    }

    public void SelectPaper(StoredPaper? paper)
    {
        if (paper is not null) SelectedPaper = paper;
    }

    private void Load()
    {
        Feeds.Clear(); foreach (FeedConfig feed in repository.LoadFeeds()) Feeds.Add(feed);
        if (Feeds.Count == 0) { FeedConfig feed = new() { Name = "Agent Research", Keywords = ["agent"] }; repository.SaveFeed(feed); Feeds.Add(feed); }
        Guid? selectedFeedId = SelectedFeed?.Id;
        SelectedFeed = Feeds.FirstOrDefault(feed => feed.Id == selectedFeedId) ?? Feeds[0];
        Papers.Clear(); foreach (StoredPaper paper in repository.LoadPapers()) Papers.Add(paper);
        RefreshLibraryGroups(focusSelectedFeed: true);
    }

    private void RefreshLibraryGroups(bool focusSelectedFeed)
    {
        Dictionary<string, bool> expanded = LibraryGroups.ToDictionary(group => group.Key, group => group.IsExpanded);
        IReadOnlyList<PaperLibraryGroupDefinition> definitions = PaperLibraryGrouping.Create(
            Feeds,
            Papers,
            repository.PaperIdsForFeed,
            repository.UnclassifiedPaperIds(),
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
}
