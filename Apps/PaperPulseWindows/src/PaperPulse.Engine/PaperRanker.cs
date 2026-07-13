using System.Globalization;
using PaperPulse.Contracts;

namespace PaperPulse.Engine;

public enum AuthorityDecision { Accepted, Rejected }

public sealed record class AuthorityEvaluation(AuthorityDecision Decision, int Score, IReadOnlyList<string> Reasons);

public sealed record class RankedPaper(PaperCandidate Candidate, int Score, IReadOnlyList<string> Reasons);

public sealed class PaperRanker
{
    public IReadOnlyList<RankedPaper> Rank(IEnumerable<PaperCandidate> candidates, FeedConfig feed, DateTimeOffset now, int? limit = null)
    {
        Dictionary<string, RankedPaper> bestByKey = new(StringComparer.Ordinal);
        foreach (PaperCandidate candidate in candidates)
        {
            if (!MatchesRequiredModules(candidate, feed)) continue;
            AuthorityEvaluation authority = EvaluateAuthority(candidate, feed.AuthorityPolicy);
            if (authority.Decision == AuthorityDecision.Rejected) continue;
            RankedPaper ranked = Score(candidate, feed, now, authority);
            string key = DedupeKey(candidate);
            if (!bestByKey.TryGetValue(key, out RankedPaper? current) || ranked.Score > current.Score)
            {
                bestByKey[key] = ranked;
            }
        }

        int selectionLimit = Math.Max(0, limit ?? feed.AuthorityPolicy.DailyLimit);
        return bestByKey.Values
            .OrderByDescending(paper => paper.Score)
            .ThenByDescending(paper => paper.Candidate.PublishedAt)
            .ThenBy(paper => paper.Candidate.StableId, StringComparer.Ordinal)
            .Take(selectionLimit)
            .ToList();
    }

    public AuthorityEvaluation EvaluateAuthority(PaperCandidate candidate, AuthorityPolicy policy)
    {
        foreach (string blocked in policy.BlockedInstitutions.Where(value => !string.IsNullOrWhiteSpace(value)))
        {
            if (candidate.Institutions.Any(institution => ContainsIgnoreCase(institution, blocked)))
            {
                return new AuthorityEvaluation(AuthorityDecision.Rejected, 0, ["blocked institution"]);
            }
        }
        foreach (string preferred in policy.PreferredInstitutions.Where(value => !string.IsNullOrWhiteSpace(value)))
        {
            if (candidate.Institutions.Any(institution => ContainsIgnoreCase(institution, preferred)))
            {
                return new AuthorityEvaluation(AuthorityDecision.Accepted, 30, ["preferred institution"]);
            }
        }
        return new AuthorityEvaluation(AuthorityDecision.Accepted, 0, []);
    }

    private static bool MatchesRequiredModules(PaperCandidate candidate, FeedConfig feed)
    {
        string haystack = $"{candidate.Title} {candidate.Summary}";
        bool keywordMatches = feed.Keywords.Count == 0 || feed.Keywords.Any(keyword => ContainsIgnoreCase(haystack, keyword));
        bool categoryMatches = feed.Categories.Count == 0 || feed.Categories.Intersect(candidate.Categories).Any();
        bool institutionMatches = feed.RequiredInstitutions.Count == 0 || feed.RequiredInstitutions.Any(required => candidate.Institutions.Any(value => ContainsIgnoreCase(value, required)));
        bool venueMatches = feed.RequiredVenues.Count == 0 || feed.RequiredVenues.Any(required => ContainsIgnoreCase(candidate.Venue, required));
        return keywordMatches && categoryMatches && institutionMatches && venueMatches;
    }

    private static RankedPaper Score(PaperCandidate candidate, FeedConfig feed, DateTimeOffset now, AuthorityEvaluation authority)
    {
        int score = authority.Score;
        List<string> reasons = authority.Reasons.ToList();
        foreach (string keyword in feed.Keywords.Select(value => value.Trim()).Where(value => value.Length > 0))
        {
            if (ContainsIgnoreCase(candidate.Title, keyword)) { score += 18; reasons.Add($"title keyword: {keyword.ToLowerInvariant()}"); }
            if (ContainsIgnoreCase(candidate.Summary, keyword)) { score += 8; reasons.Add($"summary keyword: {keyword.ToLowerInvariant()}"); }
        }
        foreach (string keyword in feed.ExcludedKeywords.Select(value => value.Trim()).Where(value => value.Length > 0))
        {
            if (ContainsIgnoreCase(candidate.Title, keyword) || ContainsIgnoreCase(candidate.Summary, keyword)) { score -= 35; reasons.Add($"excluded keyword: {keyword.ToLowerInvariant()}"); }
        }
        if (feed.Categories.Intersect(candidate.Categories).Any()) { score += 8; reasons.Add("category match"); }
        if (feed.AuthorityPolicy.PreferredVenues.Any(preferred => ContainsIgnoreCase(candidate.Venue, preferred))) { score += 16; reasons.Add("preferred venue"); }
        if (candidate.CitationCount is int citations)
        {
            score += Math.Min(20, citations / 2);
            if (feed.AuthorityPolicy.MinimumCitationCount is int minimum && citations >= minimum) { score += 5; reasons.Add("citation threshold"); }
        }
        if (candidate.PublishedAt is DateTimeOffset publishedAt)
        {
            int days = (int)Math.Max(0, (now - publishedAt).TotalDays);
            score += Math.Max(0, 12 - days);
            reasons.Add("recent");
        }
        if (candidate.OpenAccessPdfUrl is not null || candidate.OpenAccessEvidence?.Status == OpenAccessStatus.Verified) { score += 4; reasons.Add("open pdf"); }
        return new RankedPaper(candidate, score, reasons);
    }

    private static string DedupeKey(PaperCandidate candidate) => PaperCandidateMerger.NormalizeDoi(candidate.Doi) is string doi
        ? $"doi:{doi}"
        : !string.IsNullOrWhiteSpace(candidate.BaseId)
            ? $"id:{candidate.BaseId.ToLowerInvariant()}"
            : $"title:{PaperCandidateMerger.NormalizedTitleHash(candidate.Title) ?? candidate.Title.ToLowerInvariant()}";

    private static bool ContainsIgnoreCase(string? value, string? expected) => !string.IsNullOrWhiteSpace(value) && !string.IsNullOrWhiteSpace(expected) && value.Contains(expected, StringComparison.OrdinalIgnoreCase);
}
