using PaperPulse.Contracts;

namespace PaperPulse.Storage;

public sealed record PaperLibraryGroupDefinition(string Key, string Name, bool IsUnclassified, IReadOnlyList<StoredPaper> Papers);

public static class PaperLibraryGrouping
{
    public static IReadOnlyList<PaperLibraryGroupDefinition> Create(
        IEnumerable<FeedConfig> feeds,
        IEnumerable<StoredPaper> papers,
        Func<Guid, IReadOnlySet<string>> paperIdsForFeed,
        IReadOnlySet<string> unclassifiedPaperIds,
        string? searchText,
        bool favoritesOnly)
    {
        List<StoredPaper> visiblePapers = papers
            .Where(paper => Matches(paper, searchText, favoritesOnly))
            .ToList();

        List<PaperLibraryGroupDefinition> groups = feeds
            .Select(feed => new PaperLibraryGroupDefinition(
                feed.Id.ToString("D"),
                feed.Name,
                false,
                visiblePapers.Where(paper => paperIdsForFeed(feed.Id).Contains(paper.Candidate.StableId)).ToList()))
            .ToList();

        groups.Add(new PaperLibraryGroupDefinition(
            "unclassified",
            "Unclassified",
            true,
            visiblePapers.Where(paper => unclassifiedPaperIds.Contains(paper.Candidate.StableId)).ToList()));

        return groups;
    }

    public static bool IsExpanded(
        PaperLibraryGroupDefinition definition,
        Guid? selectedFeedId,
        bool focusSelectedFeed,
        IReadOnlyDictionary<string, bool> previousExpansion)
    {
        if (!focusSelectedFeed) return previousExpansion.GetValueOrDefault(definition.Key);

        return !definition.IsUnclassified && definition.Key == selectedFeedId?.ToString("D");
    }

    private static bool Matches(StoredPaper paper, string? searchText, bool favoritesOnly)
    {
        if (favoritesOnly && !paper.IsFavorite) return false;
        if (string.IsNullOrWhiteSpace(searchText)) return true;

        string searchable = string.Join(' ',
            paper.Candidate.Title,
            paper.Candidate.Summary,
            paper.Candidate.SourceId,
            string.Join(' ', paper.Candidate.Authors));
        return searchable.Contains(searchText.Trim(), StringComparison.OrdinalIgnoreCase);
    }
}
