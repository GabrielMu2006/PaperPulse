using PaperPulse.Contracts;
using PaperPulse.Storage;
using Xunit;

namespace PaperPulse.Storage.Tests;

public sealed class PaperLibraryGroupingTests
{
    [Fact]
    public void GroupsSharedPapersPerFeedAndKeepsUnclassifiedSeparate()
    {
        FeedConfig agents = new() { Id = Guid.Parse("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"), Name = "Agents" };
        FeedConfig vision = new() { Id = Guid.Parse("bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"), Name = "Vision" };
        StoredPaper shared = Paper("shared", "Shared paper", false);
        StoredPaper onlyAgents = Paper("agents", "Agent paper", false);
        StoredPaper unclassified = Paper("other", "Loose paper", false);

        IReadOnlyDictionary<Guid, IReadOnlySet<string>> memberships = new Dictionary<Guid, IReadOnlySet<string>>
        {
            [agents.Id] = new HashSet<string> { shared.Candidate.StableId, onlyAgents.Candidate.StableId },
            [vision.Id] = new HashSet<string> { shared.Candidate.StableId }
        };
        int membershipLookups = 0;

        IReadOnlyList<PaperLibraryGroupDefinition> groups = PaperLibraryGrouping.Create(
            [agents, vision],
            [shared, onlyAgents, unclassified],
            feedId =>
            {
                membershipLookups++;
                return memberships[feedId];
            },
            new HashSet<string> { unclassified.Candidate.StableId },
            searchText: null,
            favoritesOnly: false);

        Assert.Collection(groups,
            group => Assert.Equal([shared.Candidate.StableId, onlyAgents.Candidate.StableId], group.Papers.Select(paper => paper.Candidate.StableId)),
            group => Assert.Equal([shared.Candidate.StableId], group.Papers.Select(paper => paper.Candidate.StableId)),
            group =>
            {
                Assert.True(group.IsUnclassified);
                Assert.Equal([unclassified.Candidate.StableId], group.Papers.Select(paper => paper.Candidate.StableId));
            });
        Assert.Equal(2, membershipLookups);
    }

    [Fact]
    public void AppliesSearchAndFavoriteFilterWithinEveryGroup()
    {
        FeedConfig feed = new() { Id = Guid.NewGuid(), Name = "Agents" };
        StoredPaper favorite = Paper("favorite", "Agents can plan", true);
        StoredPaper regular = Paper("regular", "Vision systems", false);

        IReadOnlyList<PaperLibraryGroupDefinition> groups = PaperLibraryGrouping.Create(
            [feed],
            [favorite, regular],
            _ => new HashSet<string> { favorite.Candidate.StableId, regular.Candidate.StableId },
            new HashSet<string>(),
            searchText: "plan",
            favoritesOnly: true);

        Assert.Equal([favorite.Candidate.StableId], groups[0].Papers.Select(paper => paper.Candidate.StableId));
        Assert.Empty(groups[1].Papers);
    }

    [Fact]
    public void SelectingSubscriptionExpandsOnlyItsGroup()
    {
        FeedConfig first = new() { Id = Guid.Parse("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"), Name = "First" };
        FeedConfig selected = new() { Id = Guid.Parse("bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"), Name = "Selected" };
        IReadOnlyList<PaperLibraryGroupDefinition> groups = PaperLibraryGrouping.Create(
            [first, selected],
            [],
            _ => new HashSet<string>(),
            new HashSet<string>(),
            searchText: null,
            favoritesOnly: false);

        Dictionary<string, bool> previous = groups.ToDictionary(group => group.Key, _ => true);

        Assert.False(PaperLibraryGrouping.IsExpanded(groups[0], selected.Id, true, previous));
        Assert.True(PaperLibraryGrouping.IsExpanded(groups[1], selected.Id, true, previous));
        Assert.False(PaperLibraryGrouping.IsExpanded(groups[2], selected.Id, true, previous));
    }

    private static StoredPaper Paper(string sourceId, string title, bool isFavorite) => new(
        new PaperCandidate(PaperSourceKind.Arxiv, sourceId, title, "A concise abstract.", authors: ["Ada"]),
        null,
        null,
        DateTimeOffset.UnixEpoch,
        isFavorite);
}
