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
            return NoSelection();
        }

        if (hasLocalPdf && !string.IsNullOrWhiteSpace(localPath))
        {
            return new PaperPdfPresentation(PaperPdfState.Ready, localPath, string.Empty, string.Empty);
        }

        return new PaperPdfPresentation(
            PaperPdfState.MissingLegacyFile,
            null,
            PaperPulseStrings.Get("NoLocalPdf"),
            PaperPulseStrings.Get("RetryFeedPush"));
    }

    public PaperPdfPresentation AsUnavailable() => new(
        PaperPdfState.Unavailable,
        null,
        PaperPulseStrings.Get("CouldNotOpenLocalPdf"),
        PaperPulseStrings.Get("RetryFeedPush"));

    public static PaperPdfPresentation NoSelection() => new(
        PaperPdfState.NoSelection,
        null,
        PaperPulseStrings.Get("NoPaperSelected"),
        PaperPulseStrings.Get("ChoosePaperToOpenPdf"));
}
