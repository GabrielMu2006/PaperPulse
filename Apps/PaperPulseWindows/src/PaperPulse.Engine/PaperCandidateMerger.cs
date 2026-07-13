using System.Globalization;
using System.Text;
using System.Text.RegularExpressions;
using PaperPulse.Contracts;

namespace PaperPulse.Engine;

public sealed class PaperCandidateMerger
{
    public IReadOnlyList<PaperCandidate> Merge(IEnumerable<PaperCandidate> candidates)
    {
        List<List<PaperCandidate>> groups = [];
        foreach (PaperCandidate candidate in candidates)
        {
            List<int> matches = groups.Select((group, index) => (group, index))
                .Where(pair => pair.group.Any(existing => CandidatesMatch(existing, candidate)))
                .Select(pair => pair.index)
                .ToList();
            if (matches.Count == 0)
            {
                groups.Add([candidate]);
                continue;
            }

            int first = matches[0];
            groups[first].Add(candidate);
            foreach (int index in matches.Skip(1).OrderByDescending(index => index))
            {
                groups[first].AddRange(groups[index]);
                groups.RemoveAt(index);
            }
        }

        return groups.Select(MergeGroup).OrderBy(candidate => SourcePriority(candidate.Source))
            .ThenBy(candidate => candidate.SourceId, StringComparer.OrdinalIgnoreCase)
            .ThenBy(candidate => candidate.Title, StringComparer.OrdinalIgnoreCase)
            .ToList();
    }

    private static PaperCandidate MergeGroup(IEnumerable<PaperCandidate> group)
    {
        List<PaperCandidate> ordered = group.OrderBy(candidate => SourcePriority(candidate.Source))
            .ThenBy(candidate => candidate.SourceId, StringComparer.OrdinalIgnoreCase)
            .ThenBy(candidate => candidate.Title, StringComparer.OrdinalIgnoreCase)
            .ToList();
        PaperCandidate primary = ordered[0];
        List<int> citationCounts = ordered.Where(candidate => candidate.CitationCount.HasValue)
            .Select(candidate => candidate.CitationCount!.Value)
            .ToList();
        List<DateTimeOffset> publishedDates = ordered.Where(candidate => candidate.PublishedAt.HasValue)
            .Select(candidate => candidate.PublishedAt!.Value)
            .ToList();
        List<DateTimeOffset> updatedDates = ordered.Where(candidate => candidate.UpdatedAt.HasValue)
            .Select(candidate => candidate.UpdatedAt!.Value)
            .ToList();
        OpenAccessEvidence? evidence = ordered.Select(candidate => candidate.OpenAccessEvidence)
            .OfType<OpenAccessEvidence>()
            .OrderByDescending(item => item.Status == OpenAccessStatus.Verified)
            .ThenBy(item => SourcePriority(item.Source))
            .ThenBy(item => item.Url?.AbsoluteUri, StringComparer.Ordinal)
            .FirstOrDefault();

        return new PaperCandidate(
            primary.Source,
            primary.SourceId,
            FirstNonempty(ordered.Select(candidate => candidate.Title)) ?? primary.Title,
            FirstNonempty(ordered.Select(candidate => candidate.Summary)) ?? string.Empty,
            baseId: FirstNonempty(ordered.Select(candidate => candidate.BaseId)),
            doi: FirstNonempty(ordered.Select(candidate => candidate.Doi)),
            authors: OrderedUnion(ordered.Select(candidate => candidate.Authors)),
            institutions: OrderedUnion(ordered.Select(candidate => candidate.Institutions)),
            categories: OrderedUnion(ordered.Select(candidate => candidate.Categories)),
            publishedAt: publishedDates.Count == 0 ? null : publishedDates.Min(),
            updatedAt: updatedDates.Count == 0 ? null : updatedDates.Max(),
            absUrl: ordered.Select(candidate => candidate.AbsUrl).FirstOrDefault(url => url is not null),
            pdfUrl: ordered.Select(candidate => candidate.PdfUrl).FirstOrDefault(url => url is not null),
            venue: FirstNonempty(ordered.Select(candidate => candidate.Venue)),
            citationCount: citationCounts.Count == 0 ? null : citationCounts.Max(),
            openAccessPdfUrl: ordered.Select(candidate => candidate.OpenAccessPdfUrl).FirstOrDefault(url => url is not null) ?? evidence?.Url,
            provenance: OrderedUnion(ordered.Select(candidate => candidate.Provenance.Count == 0
                ? (IEnumerable<PaperProvenance>)new[] { new PaperProvenance { Source = candidate.Source, SourceId = candidate.SourceId, SourceUrl = candidate.AbsUrl } }
                : candidate.Provenance)),
            openAccessEvidence: evidence);
    }

    private static bool CandidatesMatch(PaperCandidate left, PaperCandidate right)
    {
        string? leftDoi = NormalizeDoi(left.Doi);
        string? rightDoi = NormalizeDoi(right.Doi);
        if (leftDoi is not null && rightDoi is not null) return leftDoi == rightDoi;

        string? leftArxiv = NormalizedArxivId(left);
        string? rightArxiv = NormalizedArxivId(right);
        if (leftArxiv is not null && rightArxiv is not null) return leftArxiv == rightArxiv;

        string? leftTitle = NormalizedTitleHash(left.Title);
        string? rightTitle = NormalizedTitleHash(right.Title);
        return leftTitle is not null && leftTitle == rightTitle;
    }

    public static string? NormalizeDoi(string? doi)
    {
        if (string.IsNullOrWhiteSpace(doi)) return null;
        string normalized = doi.Trim().ToLowerInvariant();
        foreach (string prefix in new[] { "https://doi.org/", "http://doi.org/", "doi:" })
        {
            if (normalized.StartsWith(prefix, StringComparison.Ordinal)) normalized = normalized[prefix.Length..];
        }
        normalized = normalized.TrimEnd('.');
        return normalized.Length == 0 ? null : normalized;
    }

    public static string? NormalizedArxivId(PaperCandidate candidate)
    {
        string? value = !string.IsNullOrWhiteSpace(candidate.BaseId)
            ? candidate.BaseId
            : candidate.Source == PaperSourceKind.Arxiv ? candidate.SourceId : null;
        return string.IsNullOrWhiteSpace(value) ? null : ArxivAtomParser.ArxivBaseId(value).ToLowerInvariant();
    }

    public static string? NormalizedTitleHash(string title)
    {
        string normalized = new string(title.Normalize(NormalizationForm.FormD)
            .Where(character => char.IsLetterOrDigit(character))
            .Select(char.ToLowerInvariant)
            .ToArray());
        if (normalized.Length == 0) return null;

        ulong hash = 1_469_598_103_934_665_603;
        foreach (byte value in Encoding.UTF8.GetBytes(normalized))
        {
            hash ^= value;
            hash *= 1_099_511_628_211;
        }
        return hash.ToString("x16", CultureInfo.InvariantCulture);
    }

    public static int SourcePriority(PaperSourceKind source) => source switch
    {
        PaperSourceKind.Arxiv => 0,
        PaperSourceKind.SemanticScholar => 1,
        PaperSourceKind.OpenAlex => 2,
        PaperSourceKind.Crossref => 3,
        PaperSourceKind.Unpaywall => 4,
        PaperSourceKind.Web => 5,
        _ => int.MaxValue
    };

    private static string? FirstNonempty(IEnumerable<string?> values) => values.Select(value => value?.Trim())
        .FirstOrDefault(value => !string.IsNullOrWhiteSpace(value));

    private static List<T> OrderedUnion<T>(IEnumerable<IEnumerable<T>> collections) where T : notnull
    {
        HashSet<T> seen = [];
        return collections.SelectMany(collection => collection).Where(seen.Add).ToList();
    }
}
