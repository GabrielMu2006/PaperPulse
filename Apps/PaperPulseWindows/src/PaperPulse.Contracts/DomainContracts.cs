using System.Text.RegularExpressions;
using System.Text.Json.Serialization;

namespace PaperPulse.Contracts;

public enum PaperSourceKind
{
    Arxiv,
    SemanticScholar,
    OpenAlex,
    Crossref,
    Unpaywall,
    Web
}

public sealed record class AuthorityPolicy
{
    public List<string> PreferredInstitutions { get; set; } = [];
    public List<string> BlockedInstitutions { get; set; } = [];
    public List<string> PreferredVenues { get; set; } = [];
    public int? MinimumCitationCount { get; set; }
    public int DailyLimit { get; set; } = 8;
}

public sealed record class FeedSchedule
{
    public int Hour { get; set; }
    public int Minute { get; set; }
    public HashSet<int> Weekdays { get; set; } = [];
}

public sealed record class FeedConfig : IJsonOnDeserialized
{
    public static readonly PaperSourceKind[] DefaultEnabledSources =
    [
        PaperSourceKind.Arxiv,
        PaperSourceKind.OpenAlex,
        PaperSourceKind.Crossref
    ];

    public Guid Id { get; set; } = Guid.NewGuid();
    public string Name { get; set; } = string.Empty;
    public List<string> Categories { get; set; } = [];
    public List<string> Keywords { get; set; } = [];
    public List<string> ExcludedKeywords { get; set; } = [];
    public List<string> RequiredInstitutions { get; set; } = [];
    public List<string> RequiredVenues { get; set; } = [];
    public AuthorityPolicy AuthorityPolicy { get; set; } = new();
    public bool EnableWebAugmentation { get; set; }
    public List<PaperSourceKind> EnabledSources { get; set; } = [.. DefaultEnabledSources];
    public int LookbackDays { get; set; } = 7;
    public FeedSchedule? Schedule { get; set; }
    [JsonPropertyName("searchProviderProfileID")]
    public Guid? SearchProviderProfileId { get; set; }
    [JsonPropertyName("rerankProviderProfileID")]
    public Guid? RerankProviderProfileId { get; set; }
    [JsonPropertyName("shortSummaryProviderProfileID")]
    public Guid? ShortSummaryProviderProfileId { get; set; }
    [JsonPropertyName("fullSummaryProviderProfileID")]
    public Guid? FullSummaryProviderProfileId { get; set; }
    [JsonPropertyName("extractionProviderProfileID")]
    public Guid? ExtractionProviderProfileId { get; set; }

    public void OnDeserialized()
    {
        EnabledSources = MigrateEnabledSources(EnabledSources);
    }

    private static List<PaperSourceKind> MigrateEnabledSources(IEnumerable<PaperSourceKind>? sources)
    {
        List<PaperSourceKind> migrated = (sources ?? [])
            .Where(source => source != PaperSourceKind.SemanticScholar)
            .ToList();

        return migrated.Count == 0 ? [.. DefaultEnabledSources] : migrated;
    }
}

public sealed record class PaperProvenance
{
    public PaperSourceKind Source { get; set; }
    [JsonPropertyName("sourceID")]
    public string SourceId { get; set; } = string.Empty;
    [JsonPropertyName("sourceURL")]
    public Uri? SourceUrl { get; set; }
    public DateTimeOffset? RetrievedAt { get; set; }
}

public enum OpenAccessStatus
{
    Verified,
    Unverified,
    Unavailable
}

public sealed record class OpenAccessEvidence
{
    public OpenAccessStatus Status { get; set; }
    public PaperSourceKind Source { get; set; }
    public Uri? Url { get; set; }
    public string? License { get; set; }
    public DateTimeOffset? VerifiedAt { get; set; }
}

public sealed record class PaperCandidate : IJsonOnDeserialized
{
    public PaperSourceKind Source { get; set; }
    [JsonPropertyName("sourceID")]
    public string SourceId { get; set; } = string.Empty;
    [JsonPropertyName("baseID")]
    public string? BaseId { get; set; }
    public string? Doi { get; set; }
    public string Title { get; set; } = string.Empty;
    public string Summary { get; set; } = string.Empty;
    public List<string> Authors { get; set; } = [];
    public List<string> Institutions { get; set; } = [];
    public List<string> Categories { get; set; } = [];
    public DateTimeOffset? PublishedAt { get; set; }
    public DateTimeOffset? UpdatedAt { get; set; }
    [JsonPropertyName("absURL")]
    public Uri? AbsUrl { get; set; }
    [JsonPropertyName("pdfURL")]
    public Uri? PdfUrl { get; set; }
    public string? Venue { get; set; }
    public int? CitationCount { get; set; }
    [JsonPropertyName("openAccessPDFURL")]
    public Uri? OpenAccessPdfUrl { get; set; }
    public List<PaperProvenance> Provenance { get; set; } = [];
    public OpenAccessEvidence? OpenAccessEvidence { get; set; }

    [JsonIgnore]
    public string Id => StableId;

    [JsonIgnore]
    public string StableId => !string.IsNullOrWhiteSpace(Doi)
        ? $"doi:{Doi.ToLowerInvariant()}"
        : !string.IsNullOrWhiteSpace(BaseId)
            ? $"{PaperPulseJson.SourceName(Source)}:{BaseId.ToLowerInvariant()}"
            : $"{PaperPulseJson.SourceName(Source)}:{SourceId.ToLowerInvariant()}";

    public PaperCandidate()
    {
    }

    public PaperCandidate(
        PaperSourceKind source,
        string sourceId,
        string title,
        string summary,
        string? baseId = null,
        string? doi = null,
        IEnumerable<string>? authors = null,
        IEnumerable<string>? institutions = null,
        IEnumerable<string>? categories = null,
        DateTimeOffset? publishedAt = null,
        DateTimeOffset? updatedAt = null,
        Uri? absUrl = null,
        Uri? pdfUrl = null,
        string? venue = null,
        int? citationCount = null,
        Uri? openAccessPdfUrl = null,
        IEnumerable<PaperProvenance>? provenance = null,
        OpenAccessEvidence? openAccessEvidence = null)
    {
        Source = source;
        SourceId = sourceId;
        BaseId = baseId;
        Doi = doi;
        Title = title;
        Summary = summary;
        Authors = authors?.ToList() ?? [];
        Institutions = institutions?.ToList() ?? [];
        Categories = categories?.ToList() ?? [];
        PublishedAt = publishedAt;
        UpdatedAt = updatedAt;
        AbsUrl = absUrl;
        PdfUrl = pdfUrl;
        Venue = venue;
        CitationCount = citationCount;
        OpenAccessPdfUrl = openAccessPdfUrl;
        Provenance = provenance?.ToList() ?? [];
        OpenAccessEvidence = openAccessEvidence;
        Normalize();
    }

    public void OnDeserialized()
    {
        Normalize();
    }

    private void Normalize()
    {
        Title = NormalizeWhitespace(Title);
        Summary = NormalizeWhitespace(Summary);
        Authors = NormalizeStrings(Authors);
        Institutions = NormalizeStrings(Institutions);
        Venue = string.IsNullOrWhiteSpace(Venue) ? Venue : NormalizeWhitespace(Venue);
    }

    private static List<string> NormalizeStrings(IEnumerable<string>? values) => (values ?? [])
        .Select(NormalizeWhitespace)
        .Where(value => value.Length > 0)
        .ToList();

    private static string NormalizeWhitespace(string? value) => string.IsNullOrWhiteSpace(value)
        ? string.Empty
        : Regex.Replace(value.Trim(), "\\s+", " ");
}
