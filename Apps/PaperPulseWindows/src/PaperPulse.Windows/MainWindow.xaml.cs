using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Input;
using PaperPulse.Contracts;
using PaperPulse.Storage;
using PaperPulse.Windows.Presentation;
using PaperPulse.Windows.Views;

namespace PaperPulse.Windows;

public sealed partial class MainWindow : Window
{
    private bool isResizingWorkspace;
    private double workspaceAvailableWidth;
    private double workspaceStartInfoWidth;
    private double workspaceStartPointerX;

    public MainWindowViewModel ViewModel { get; } = new();

    public MainWindow()
    {
        InitializeComponent();
        ((FrameworkElement)Content).DataContext = ViewModel;
        DispatcherQueue.TryEnqueue(async () =>
        {
            await ViewModel.InitializeAsync();
            ApplyWorkspaceSplit(ViewModel.WorkspaceSplitRatio);
        });
    }

    private async void Favorite_Click(object sender, RoutedEventArgs e) => await ViewModel.ToggleFavoriteAsync();

    private async void OpenPdf_Click(object sender, RoutedEventArgs e) => await ShowSelectedPdfAsync();

    private async void LibrarySidebar_AddFeedRequested(object sender, EventArgs e) => await EditFeedAsync(null);

    private async void LibrarySidebar_EditFeedRequested(object sender, FeedRequestEventArgs e) => await EditFeedAsync(e.Feed);

    private async void LibrarySidebar_DeleteFeedRequested(object sender, FeedRequestEventArgs e)
    {
        ViewModel.SelectedFeed = e.Feed;

        ContentDialog confirmation = new()
        {
            XamlRoot = ((FrameworkElement)Content).XamlRoot,
            Title = "Delete subscription?",
            Content = $"Papers remain in the library, but {e.Feed.Name} will no longer group them.",
            PrimaryButtonText = "Delete",
            CloseButtonText = "Cancel",
            DefaultButton = ContentDialogButton.Close
        };

        if (await confirmation.ShowAsync() == ContentDialogResult.Primary) await ViewModel.DeleteSelectedFeedAsync();
    }

    private async void LibrarySidebar_PaperSelected(object sender, PaperSelectionEventArgs e)
    {
        await ShowSelectedPdfAsync();
    }

    private void WorkspaceSplitter_PointerPressed(object sender, PointerRoutedEventArgs e)
    {
        workspaceAvailableWidth = InfoColumn.ActualWidth + PdfColumn.ActualWidth;
        if (workspaceAvailableWidth <= 0) return;
        workspaceStartInfoWidth = InfoColumn.ActualWidth;
        workspaceStartPointerX = e.GetCurrentPoint(WorkspaceGrid).Position.X;
        isResizingWorkspace = WorkspaceSplitter.CapturePointer(e.Pointer);
        e.Handled = isResizingWorkspace;
    }

    private void WorkspaceSplitter_PointerMoved(object sender, PointerRoutedEventArgs e)
    {
        if (!isResizingWorkspace) return;
        double offset = e.GetCurrentPoint(WorkspaceGrid).Position.X - workspaceStartPointerX;
        ApplyWorkspaceSplit((workspaceStartInfoWidth + offset) / workspaceAvailableWidth);
        e.Handled = true;
    }

    private async void WorkspaceSplitter_PointerReleased(object sender, PointerRoutedEventArgs e)
    {
        if (!isResizingWorkspace) return;
        isResizingWorkspace = false;
        WorkspaceSplitter.ReleasePointerCaptures();
        double workspaceWidth = InfoColumn.ActualWidth + PdfColumn.ActualWidth;
        if (workspaceWidth > 0) await ViewModel.SaveWorkspaceSplitRatioAsync(InfoColumn.ActualWidth / workspaceWidth);
        e.Handled = true;
    }

    private void WorkspaceSplitter_PointerCaptureLost(object sender, PointerRoutedEventArgs e)
    {
        isResizingWorkspace = false;
    }

    private async Task EditFeedAsync(FeedConfig? existing)
    {
        TextBox nameBox = new() { Text = existing?.Name ?? string.Empty, PlaceholderText = "Subscription name" };
        TextBox keywordsBox = new()
        {
            Text = existing is null ? string.Empty : string.Join(", ", existing.Keywords),
            PlaceholderText = "Keywords, separated by commas"
        };

        ContentDialog editor = new()
        {
            XamlRoot = ((FrameworkElement)Content).XamlRoot,
            Title = existing is null ? "New subscription" : "Edit subscription",
            Content = new StackPanel { Spacing = 12, Children = { nameBox, keywordsBox } },
            PrimaryButtonText = "Save",
            CloseButtonText = "Cancel",
            DefaultButton = ContentDialogButton.Primary
        };

        if (await editor.ShowAsync() != ContentDialogResult.Primary) return;

        FeedConfig feed = (existing ?? new FeedConfig()) with
        {
            Name = nameBox.Text.Trim(),
            Keywords = keywordsBox.Text
                .Split(',', StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries)
                .ToList()
        };
        await ViewModel.SaveFeedAsync(feed);
    }

    private async Task ShowSelectedPdfAsync()
    {
        if (!ViewModel.HasSelectedPdf || ViewModel.SelectedPdfPath is not { } path)
        {
            HidePdfViewer();
            return;
        }

        try
        {
            await PdfViewer.EnsureCoreWebView2Async();
            PdfViewer.Source = new Uri(path);
            PdfViewer.Visibility = Visibility.Visible;
            PdfEmptyState.Visibility = Visibility.Collapsed;
        }
        catch (Exception)
        {
            PdfEmptyState.Text = "Could not open the local PDF. Push the subscription again to retry.";
            PdfEmptyState.Visibility = Visibility.Visible;
            PdfViewer.Visibility = Visibility.Collapsed;
        }
    }

    private void HidePdfViewer()
    {
        PdfViewer.Source = null;
        PdfViewer.Visibility = Visibility.Collapsed;
        PdfEmptyState.Text = "This paper has no local PDF. Push its subscription again to retry.";
        PdfEmptyState.Visibility = Visibility.Visible;
    }

    private void ApplyWorkspaceSplit(double ratio)
    {
        double clamped = WorkspaceSplitState.Clamp(ratio);
        InfoColumn.Width = new GridLength(clamped, GridUnitType.Star);
        PdfColumn.Width = new GridLength(1 - clamped, GridUnitType.Star);
    }
}
