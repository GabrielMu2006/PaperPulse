using System.Globalization;
using System.Text.Json;
using PaperPulse.Contracts;
using static PaperPulse.Engine.JsonMapping;

namespace PaperPulse.Engine;

public interface IPaperSource
{
    PaperSourceKind Kind { get; }
    Task<IReadOnlyList<PaperCandidate>> SearchAsync(FeedConfig feed, DateTimeOffset start, DateTimeOffset end, CancellationToken cancellationToken = default);
}

public sealed class ArxivSource(IHttpTransport transport, ArxivAtomParser? parser = null) : IPaperSource
{
    private readonly ArxivAtomParser parser = parser ?? new ArxivAtomParser();

    public PaperSourceKind Kind => PaperSourceKind.Arxiv;

    public async Task<IReadOnlyList<PaperCandidate>> SearchAsync(FeedConfig feed, DateTimeOffset start, DateTimeOffset end, CancellationToken cancellationToken = default)
    {
        Uri uri = QueryUri("https://export.arxiv.org/api/query", new Dictionary<string, string>
        {
            ["search_query"] = ArxivQuery(feed, start, end),
            ["start"] = "0",
            ["max_results"] = Math.Max(feed.AuthorityPolicy.DailyLimit * 4, 25).ToString(CultureInfo.InvariantCulture),
            ["sortBy"] = "submittedDate",
            ["sortOrder"] = "descending"
        });
        HttpResponse response = await transport.SendAsync(new HttpRequestMessage(HttpMethod.Get, uri), cancellationToken).ConfigureAwait(false);
        return parser.Parse(response.RequireSuccess().Data).Select(candidate =>
        {
            candidate.Provenance = [new PaperProvenance { Source = Kind, SourceId = candidate.SourceId, SourceUrl = candidate.AbsUrl }];
            if (candidate.OpenAccessPdfUrl is not null)
            {
                candidate.OpenAccessEvidence = new OpenAccessEvidence { Status = OpenAccessStatus.Verified, Source = Kind, Url = candidate.OpenAccessPdfUrl };
            }
            return candidate;
        }).ToList();
    }

    private static string ArxivQuery(FeedConfig feed, DateTimeOffset start, DateTimeOffset end)
    {
        string categoryQuery = feed.Categories.Count == 0 ? $"all:{feed.Name}" : string.Join(" OR ", feed.Categories.Select(category => $"cat:{category}"));
        string keywordQuery = string.Join(" OR ", feed.Keywords.Select(keyword => $"all:\"{keyword}\""));
        string dateQuery = $"submittedDate:[{ArxivDate(start)} TO {ArxivDate(end)}]";
        return string.IsNullOrEmpty(keywordQuery)
            ? $"({categoryQuery}) AND {dateQuery}"
            : $"({categoryQuery}) AND ({keywordQuery}) AND {dateQuery}";
    }

    private static string ArxivDate(DateTimeOffset value) => value.UtcDateTime.ToString("yyyyMMddHHmm", CultureInfo.InvariantCulture);
}

public sealed class OpenAlexSource(IHttpTransport transport) : IPaperSource
{
    public PaperSourceKind Kind => PaperSourceKind.OpenAlex;

    public async Task<IReadOnlyList<PaperCandidate>> SearchAsync(FeedConfig feed, DateTimeOffset start, DateTimeOffset end, CancellationToken cancellationToken = default)
    {
        Uri uri = QueryUri("https://api.openalex.org/works", new Dictionary<string, string>
        {
            ["search"] = string.Join(" ", new[] { feed.Name }.Concat(feed.Keywords)),
            ["per-page"] = Math.Max(feed.AuthorityPolicy.DailyLimit * 3, 10).ToString(CultureInfo.InvariantCulture),
            ["filter"] = $"from_publication_date:{DateOnly(start)},to_publication_date:{DateOnly(end)}",
            ["sort"] = "publication_date:desc"
        });
        HttpResponse response = await transport.SendAsync(new HttpRequestMessage(HttpMethod.Get, uri), cancellationToken).ConfigureAwait(false);
        using JsonDocument document = JsonDocument.Parse(response.RequireSuccess().Data);
        if (!document.RootElement.TryGetProperty("results", out JsonElement results) || results.ValueKind != JsonValueKind.Array)
        {
            return [];
        }

        return results.EnumerateArray().Select(Map).Where(candidate => candidate is not null).Cast<PaperCandidate>().ToList();
    }

    private static PaperCandidate? Map(JsonElement work)
    {
        string? id = String(work, "id");
        string? title = String(work, "title") ?? String(work, "display_name");
        if (string.IsNullOrWhiteSpace(id) || string.IsNullOrWhiteSpace(title))
        {
            return null;
        }

        Uri? openAccessPdfUrl = Object(work, "open_access") is JsonElement access ? Uri(String(access, "oa_url")) : null;
        Uri? absUrl = Uri(id);
        PaperCandidate candidate = new(
            PaperSourceKind.OpenAlex,
            id,
            title,
            Abstract(work),
            doi: String(work, "doi")?.Replace("https://doi.org/", string.Empty, StringComparison.Ordinal),
            authors: AuthorshipNames(work, "author"),
            institutions: Institutions(work),
            publishedAt: DateOnlyValue(String(work, "publication_date")),
            absUrl: absUrl,
            pdfUrl: openAccessPdfUrl,
            venue: Object(Object(work, "primary_location"), "source") is JsonElement source ? String(source, "display_name") : null,
            citationCount: Integer(work, "cited_by_count"),
            openAccessPdfUrl: openAccessPdfUrl,
            provenance: [new PaperProvenance { Source = PaperSourceKind.OpenAlex, SourceId = id, SourceUrl = absUrl }],
            openAccessEvidence: openAccessPdfUrl is null ? null : new OpenAccessEvidence { Status = OpenAccessStatus.Verified, Source = PaperSourceKind.OpenAlex, Url = openAccessPdfUrl });
        return candidate;
    }

    private static string Abstract(JsonElement work)
    {
        if (Object(work, "abstract_inverted_index") is not JsonElement index || index.ValueKind != JsonValueKind.Object)
        {
            return string.Empty;
        }

        return index.EnumerateObject()
            .SelectMany(word => word.Value.ValueKind == JsonValueKind.Array
                ? word.Value.EnumerateArray().Where(position => position.TryGetInt32(out _)).Select(position => (Position: position.GetInt32(), Word: word.Name))
                : [])
            .OrderBy(pair => pair.Position)
            .Select(pair => pair.Word)
            .Aggregate(string.Empty, (text, word) => string.IsNullOrEmpty(text) ? word : $"{text} {word}");
    }

    private static IEnumerable<string> AuthorshipNames(JsonElement work, string property) => Object(work, "authorships") is JsonElement authorships && authorships.ValueKind == JsonValueKind.Array
        ? authorships.EnumerateArray().Select(authorship => Object(authorship, property) is JsonElement author ? String(author, "display_name") : null).OfType<string>()
        : [];

    private static IEnumerable<string> Institutions(JsonElement work) => Object(work, "authorships") is JsonElement authorships && authorships.ValueKind == JsonValueKind.Array
        ? authorships.EnumerateArray().SelectMany(authorship => Object(authorship, "institutions") is JsonElement institutions && institutions.ValueKind == JsonValueKind.Array
            ? institutions.EnumerateArray().Select(institution => String(institution, "display_name")).OfType<string>()
            : [])
        : [];
}

public sealed class CrossrefSource(IHttpTransport transport) : IPaperSource
{
    public PaperSourceKind Kind => PaperSourceKind.Crossref;

    public async Task<IReadOnlyList<PaperCandidate>> SearchAsync(FeedConfig feed, DateTimeOffset start, DateTimeOffset end, CancellationToken cancellationToken = default)
    {
        Uri uri = QueryUri("https://api.crossref.org/works", new Dictionary<string, string>
        {
            ["query"] = string.Join(" ", new[] { feed.Name }.Concat(feed.Keywords)),
            ["rows"] = Math.Max(feed.AuthorityPolicy.DailyLimit * 3, 10).ToString(CultureInfo.InvariantCulture),
            ["filter"] = $"from-pub-date:{DateOnly(start)},until-pub-date:{DateOnly(end)}",
            ["sort"] = "published",
            ["order"] = "desc"
        });
        HttpResponse response = await transport.SendAsync(new HttpRequestMessage(HttpMethod.Get, uri), cancellationToken).ConfigureAwait(false);
        using JsonDocument document = JsonDocument.Parse(response.RequireSuccess().Data);
        if (Object(document.RootElement, "message") is not JsonElement message || Object(message, "items") is not JsonElement items || items.ValueKind != JsonValueKind.Array)
        {
            return [];
        }

        return items.EnumerateArray().Select((item, index) => Map(item, index)).ToList();
    }

    private static PaperCandidate Map(JsonElement item, int index)
    {
        string? doi = String(item, "DOI");
        string? url = String(item, "URL");
        string title = Strings(item, "title").FirstOrDefault() is { Length: > 0 } foundTitle ? foundTitle : "Untitled";
        string sourceId = doi ?? url ?? title;
        Uri? pdfUrl = Object(item, "link") is JsonElement links && links.ValueKind == JsonValueKind.Array
            ? links.EnumerateArray().FirstOrDefault(link => string.Equals(String(link, "content-type"), "application/pdf", StringComparison.OrdinalIgnoreCase)) is JsonElement pdf ? Uri(String(pdf, "URL")) : null
            : null;
        return new PaperCandidate(
            PaperSourceKind.Crossref,
            sourceId,
            title,
            String(item, "abstract") ?? string.Empty,
            doi: doi,
            authors: Authors(item),
            publishedAt: IssuedDate(item),
            absUrl: Uri(url),
            pdfUrl: pdfUrl,
            venue: Strings(item, "container-title").FirstOrDefault(),
            provenance: [new PaperProvenance { Source = PaperSourceKind.Crossref, SourceId = sourceId, SourceUrl = Uri(url) }]);
    }

    private static IEnumerable<string> Authors(JsonElement item) => Object(item, "author") is JsonElement authors && authors.ValueKind == JsonValueKind.Array
        ? authors.EnumerateArray().Select(author => string.Join(" ", new[] { String(author, "given"), String(author, "family") }.Where(value => !string.IsNullOrWhiteSpace(value))!))
        : [];

    private static DateTimeOffset? IssuedDate(JsonElement item)
    {
        if (Object(Object(item, "issued"), "date-parts") is not JsonElement dates || dates.ValueKind != JsonValueKind.Array || dates.GetArrayLength() == 0 || dates[0].ValueKind != JsonValueKind.Array || dates[0].GetArrayLength() == 0)
        {
            return null;
        }
        JsonElement parts = dates[0];
        if (!parts[0].TryGetInt32(out int year)) return null;
        int month = parts.GetArrayLength() > 1 && parts[1].TryGetInt32(out int foundMonth) ? foundMonth : 1;
        int day = parts.GetArrayLength() > 2 && parts[2].TryGetInt32(out int foundDay) ? foundDay : 1;
        try { return new DateTimeOffset(year, month, day, 0, 0, 0, TimeSpan.Zero); }
        catch (ArgumentOutOfRangeException) { return null; }
    }
}

internal static class JsonMapping
{
    public static JsonElement? Object(JsonElement? parent, string property) => parent is JsonElement value && value.ValueKind == JsonValueKind.Object && value.TryGetProperty(property, out JsonElement child) ? child : null;
    public static string? String(JsonElement element, string property) => Object(element, property) is JsonElement child && child.ValueKind == JsonValueKind.String ? child.GetString() : null;
    public static int? Integer(JsonElement element, string property) => Object(element, property) is JsonElement child && child.TryGetInt32(out int value) ? value : null;
    public static IEnumerable<string> Strings(JsonElement element, string property) => Object(element, property) is JsonElement child && child.ValueKind == JsonValueKind.Array ? child.EnumerateArray().Where(item => item.ValueKind == JsonValueKind.String).Select(item => item.GetString()!).Where(value => !string.IsNullOrWhiteSpace(value)) : [];
    public static Uri? Uri(string? value) => System.Uri.TryCreate(value, UriKind.Absolute, out Uri? uri) ? uri : null;
    public static DateTimeOffset? DateOnlyValue(string? value) => DateTimeOffset.TryParseExact(value, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.AssumeUniversal, out DateTimeOffset date) ? date : null;
    public static string DateOnly(DateTimeOffset value) => value.UtcDateTime.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
    public static Uri QueryUri(string baseUri, IReadOnlyDictionary<string, string> items) => new($"{baseUri}?{string.Join("&", items.Select(pair => $"{System.Uri.EscapeDataString(pair.Key)}={System.Uri.EscapeDataString(pair.Value)}"))}");
}
