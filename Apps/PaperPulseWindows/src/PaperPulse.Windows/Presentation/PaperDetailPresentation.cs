using PaperPulse.Contracts;
using PaperPulse.Storage;

namespace PaperPulse.Windows.Presentation;

public sealed record PaperDetailPresentation(
    bool HasPaper,
    string Title,
    string Authors,
    string Summary,
    string Source,
    string Venue,
    string Date,
    string CitationCount,
    bool IsFavorite,
    Uri? SourceUri)
{
    public bool HasSourceUri => SourceUri is not null;

    public static PaperDetailPresentation Create(StoredPaper? paper)
    {
        if (paper is null)
        {
            return new PaperDetailPresentation(
                false,
                "No paper selected",
                "Choose a paper from the library to start reading.",
                string.Empty,
                string.Empty,
                string.Empty,
                string.Empty,
                false,
                null);
        }

        PaperCandidate candidate = paper.Candidate;
        Uri? sourceUri = candidate.Provenance.Select(provenance => provenance.SourceUrl).FirstOrDefault(uri => uri is not null)
            ?? candidate.AbsUrl;
        return new PaperDetailPresentation(
            true,
            candidate.Title,
            candidate.Authors.Count == 0 ? "Unknown author" : string.Join(", ", candidate.Authors),
            candidate.Summary,
            PaperPulseJson.SourceName(candidate.Source),
            string.IsNullOrWhiteSpace(candidate.Venue) ? "Venue unavailable" : candidate.Venue,
            candidate.PublishedAt?.ToLocalTime().ToString("yyyy-MM-dd") ?? "Date unavailable",
            candidate.CitationCount is int citations ? $"{citations} citations" : "Citations unavailable",
            paper.IsFavorite,
            sourceUri);
    }
}
