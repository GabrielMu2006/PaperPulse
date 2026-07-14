using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using PaperPulse.Windows.Presentation;

namespace PaperPulse.Windows.Views;

public sealed partial class PdfReaderPane : UserControl
{
    public static readonly DependencyProperty PresentationProperty = DependencyProperty.Register(
        nameof(Presentation),
        typeof(PaperPdfPresentation),
        typeof(PdfReaderPane),
        new PropertyMetadata(null, OnPresentationChanged));

    private string? loadedPath;

    public PdfReaderPane()
    {
        InitializeComponent();
    }

    public PaperPdfPresentation? Presentation
    {
        get => (PaperPdfPresentation?)GetValue(PresentationProperty);
        set => SetValue(PresentationProperty, value);
    }

    private static void OnPresentationChanged(DependencyObject dependencyObject, DependencyPropertyChangedEventArgs args)
    {
        _ = ((PdfReaderPane)dependencyObject).ApplyPresentationAsync(args.NewValue as PaperPdfPresentation);
    }

    private async Task ApplyPresentationAsync(PaperPdfPresentation? presentation)
    {
        if (presentation?.State != PaperPdfState.Ready || string.IsNullOrWhiteSpace(presentation.LocalPath))
        {
            ShowState(presentation ?? new PaperPdfPresentation(
                PaperPdfState.NoSelection,
                null,
                "No paper selected",
                "Choose a paper from the library to open its local PDF."));
            return;
        }

        string localPath = presentation.LocalPath;
        try
        {
            if (!string.Equals(loadedPath, localPath, StringComparison.OrdinalIgnoreCase))
            {
                await PdfViewer.EnsureCoreWebView2Async();
                if (Presentation?.LocalPath != localPath) return;
                PdfViewer.Source = new Uri(localPath, UriKind.Absolute);
                loadedPath = localPath;
            }

            StateSurface.Visibility = Visibility.Collapsed;
            PdfViewer.Visibility = Visibility.Visible;
        }
        catch
        {
            ShowState(presentation.AsUnavailable());
        }
    }

    private void ShowState(PaperPdfPresentation presentation)
    {
        loadedPath = null;
        PdfViewer.Source = null;
        PdfViewer.Visibility = Visibility.Collapsed;
        StateTitle.Text = presentation.Title;
        StateMessage.Text = presentation.Message;
        StateSurface.Visibility = Visibility.Visible;
    }
}
