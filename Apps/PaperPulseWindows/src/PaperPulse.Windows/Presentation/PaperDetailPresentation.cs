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
                PaperPulseStrings.Get("NoPaperSelected"),
                PaperPulseStrings.Get("ChoosePaperToRead"),
                string.Empty,
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
            candidate.Authors.Count == 0 ? PaperPulseStrings.Get("UnknownAuthor") : string.Join(", ", candidate.Authors),
            candidate.Summary,
            PaperPulseJson.SourceName(candidate.Source),
            string.IsNullOrWhiteSpace(candidate.Venue) ? PaperPulseStrings.Get("VenueUnavailable") : candidate.Venue,
            candidate.PublishedAt?.ToLocalTime().ToString("yyyy-MM-dd") ?? PaperPulseStrings.Get("DateUnavailable"),
            candidate.CitationCount is int citations ? PaperPulseStrings.Format("CitationCount", citations) : PaperPulseStrings.Get("CitationsUnavailable"),
            paper.IsFavorite,
            sourceUri);
    }
}
