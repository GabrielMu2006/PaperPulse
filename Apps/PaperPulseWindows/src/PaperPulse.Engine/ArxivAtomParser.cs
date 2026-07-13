using System.Globalization;
using System.Xml.Linq;
using PaperPulse.Contracts;

namespace PaperPulse.Engine;

public sealed class ArxivAtomParser
{
    public IReadOnlyList<PaperCandidate> Parse(byte[] data)
    {
        XDocument document = XDocument.Parse(System.Text.Encoding.UTF8.GetString(data), LoadOptions.None);
        return document.Descendants().Where(element => element.Name.LocalName == "entry").Select(ParseEntry).ToList();
    }

    private static PaperCandidate ParseEntry(XElement entry)
    {
        string id = Text(entry, "id");
        string sourceId = id.Split('/', StringSplitOptions.RemoveEmptyEntries).LastOrDefault() ?? id;
        Uri? absUrl = Link(entry, "alternate") ?? AbsoluteUri($"https://arxiv.org/abs/{sourceId}");
        Uri? pdfUrl = entry.Elements().FirstOrDefault(element =>
            element.Name.LocalName == "link" &&
            (string.Equals((string?)element.Attribute("title"), "pdf", StringComparison.OrdinalIgnoreCase) ||
             string.Equals((string?)element.Attribute("type"), "application/pdf", StringComparison.OrdinalIgnoreCase)))
            ?.Attribute("href")?.Value is string href ? AbsoluteUri(href) : null;
        pdfUrl ??= AbsoluteUri($"https://arxiv.org/pdf/{sourceId}.pdf");

        return new PaperCandidate(
            PaperSourceKind.Arxiv,
            sourceId,
            Text(entry, "title"),
            Text(entry, "summary"),
            baseId: ArxivBaseId(sourceId),
            authors: entry.Elements().Where(element => element.Name.LocalName == "author")
                .Select(author => Text(author, "name")),
            categories: entry.Elements().Where(element => element.Name.LocalName == "category")
                .Select(category => (string?)category.Attribute("term") ?? string.Empty)
                .Where(category => !string.IsNullOrWhiteSpace(category)),
            publishedAt: Date(Text(entry, "published")),
            updatedAt: Date(Text(entry, "updated")),
            absUrl: absUrl,
            pdfUrl: pdfUrl,
            openAccessPdfUrl: pdfUrl);
    }

    public static string ArxivBaseId(string sourceId) => System.Text.RegularExpressions.Regex.Replace(sourceId, @"v\d+$", string.Empty);

    private static string Text(XElement parent, string name) => parent.Elements().FirstOrDefault(element => element.Name.LocalName == name)?.Value ?? string.Empty;

    private static Uri? Link(XElement entry, string rel) => entry.Elements().FirstOrDefault(element =>
        element.Name.LocalName == "link" && string.Equals((string?)element.Attribute("rel"), rel, StringComparison.OrdinalIgnoreCase))
        ?.Attribute("href")?.Value is string href ? AbsoluteUri(href) : null;

    private static Uri? AbsoluteUri(string value) => Uri.TryCreate(value, UriKind.Absolute, out Uri? uri) ? uri : null;

    private static DateTimeOffset? Date(string value) => DateTimeOffset.TryParse(value, CultureInfo.InvariantCulture, DateTimeStyles.AssumeUniversal, out DateTimeOffset date) ? date : null;
}
