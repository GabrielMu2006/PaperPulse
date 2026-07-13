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

    [ObservableProperty] private FeedConfig? selectedFeed;
    [ObservableProperty] private StoredPaper? selectedPaper;
    [ObservableProperty] private string searchText = string.Empty;
    [ObservableProperty] private string status = "Ready";
    [ObservableProperty] private bool isRefreshing;

    public ObservableCollection<FeedConfig> Feeds { get; } = [];
    public ObservableCollection<StoredPaper> Papers { get; } = [];
    public ObservableCollection<StoredPaper> VisiblePapers { get; } = [];

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

    partial void OnSelectedFeedChanged(FeedConfig? value) => RefreshVisiblePapers();
    partial void OnSearchTextChanged(string value) => RefreshVisiblePapers();

    private void Load()
    {
        Feeds.Clear(); foreach (FeedConfig feed in repository.LoadFeeds()) Feeds.Add(feed);
        if (Feeds.Count == 0) { FeedConfig feed = new() { Name = "Agent Research", Keywords = ["agent"] }; repository.SaveFeed(feed); Feeds.Add(feed); }
        SelectedFeed ??= Feeds[0];
        Papers.Clear(); foreach (StoredPaper paper in repository.LoadPapers()) Papers.Add(paper);
        RefreshVisiblePapers();
    }

    private void RefreshVisiblePapers()
    {
        IEnumerable<StoredPaper> papers = Papers;
        if (SelectedFeed is not null) { IReadOnlySet<string> ids = repository.PaperIdsForFeed(SelectedFeed.Id); papers = papers.Where(paper => ids.Contains(paper.Candidate.StableId)); }
        if (!string.IsNullOrWhiteSpace(SearchText)) papers = papers.Where(paper => $"{paper.Candidate.Title} {paper.Candidate.Summary} {string.Join(' ', paper.Candidate.Authors)}".Contains(SearchText, StringComparison.OrdinalIgnoreCase));
        VisiblePapers.Clear(); foreach (StoredPaper paper in papers) VisiblePapers.Add(paper);
        if (SelectedPaper is not null && !VisiblePapers.Any(paper => paper.Candidate.StableId == SelectedPaper.Candidate.StableId)) SelectedPaper = null;
    }
}
