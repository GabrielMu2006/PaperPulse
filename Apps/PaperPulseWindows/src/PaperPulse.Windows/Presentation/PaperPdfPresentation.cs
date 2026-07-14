using PaperPulse.Storage;

namespace PaperPulse.Windows.Presentation;

public enum PaperPdfState
{
    NoSelection,
    Ready,
    MissingLegacyFile,
    Unavailable
}

public sealed record PaperPdfPresentation(PaperPdfState State, string? LocalPath, string Title, string Message)
{
    public static PaperPdfPresentation Create(StoredPaper? paper, string? localPath, bool hasLocalPdf)
    {
        if (paper is null)
        {
            return new PaperPdfPresentation(
                PaperPdfState.NoSelection,
                null,
                "No paper selected",
                "Choose a paper from the library to open its local PDF.");
        }

        if (hasLocalPdf && !string.IsNullOrWhiteSpace(localPath))
        {
            return new PaperPdfPresentation(PaperPdfState.Ready, localPath, string.Empty, string.Empty);
        }

        return new PaperPdfPresentation(
            PaperPdfState.MissingLegacyFile,
            null,
            "No local PDF available",
            "Push this paper's subscription again to retry verified open-access PDF retrieval.");
    }

    public PaperPdfPresentation AsUnavailable() => new(
        PaperPdfState.Unavailable,
        null,
        "Could not open the local PDF",
        "Push this paper's subscription again to retry verified open-access PDF retrieval.");
}
