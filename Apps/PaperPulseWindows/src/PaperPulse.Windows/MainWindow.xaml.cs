using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using PaperPulse.Contracts;
using PaperPulse.Storage;

namespace PaperPulse.Windows;

public sealed partial class MainWindow : Window
{
    public MainWindowViewModel ViewModel { get; } = new();

    public MainWindow()
    {
        InitializeComponent();
        ((FrameworkElement)Content).DataContext = ViewModel;
        DispatcherQueue.TryEnqueue(async () => await ViewModel.InitializeAsync());
    }

    private async void Refresh_Click(object sender, RoutedEventArgs e) => await ViewModel.RefreshSelectedFeedAsync();

    private async void Favorite_Click(object sender, RoutedEventArgs e) => await ViewModel.ToggleFavoriteAsync();

    private async void DownloadPdf_Click(object sender, RoutedEventArgs e)
    {
        await ViewModel.DownloadSelectedPdfAsync();
        await ShowSelectedPdfAsync();
    }

    private async void OpenPdf_Click(object sender, RoutedEventArgs e) => await ShowSelectedPdfAsync();

    private void FavoritesFilter_Click(object sender, RoutedEventArgs e) => ViewModel.ToggleFavoritesFilter();

    private async void AddFeed_Click(object sender, RoutedEventArgs e) => await EditFeedAsync(null);

    private async void EditFeed_Click(object sender, RoutedEventArgs e) => await EditFeedAsync(ViewModel.SelectedFeed);

    private async void DeleteFeed_Click(object sender, RoutedEventArgs e)
    {
        if (ViewModel.SelectedFeed is null) return;

        ContentDialog confirmation = new()
        {
            XamlRoot = ((FrameworkElement)Content).XamlRoot,
            Title = "Delete subscription?",
            Content = $"Papers remain in the library, but {ViewModel.SelectedFeed.Name} will no longer group them.",
            PrimaryButtonText = "Delete",
            CloseButtonText = "Cancel",
            DefaultButton = ContentDialogButton.Close
        };

        if (await confirmation.ShowAsync() == ContentDialogResult.Primary) await ViewModel.DeleteSelectedFeedAsync();
    }

    private void PaperList_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (sender is not ListView { SelectedItem: StoredPaper paper }) return;
        ViewModel.SelectPaper(paper);
        HidePdfViewer();
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
        catch (Exception error)
        {
            PdfEmptyState.Text = $"Could not open PDF: {error.Message}";
            PdfEmptyState.Visibility = Visibility.Visible;
            PdfViewer.Visibility = Visibility.Collapsed;
        }
    }

    private void HidePdfViewer()
    {
        PdfViewer.Source = null;
        PdfViewer.Visibility = Visibility.Collapsed;
        PdfEmptyState.Text = "Download a verified open-access PDF to read it here.";
        PdfEmptyState.Visibility = Visibility.Visible;
    }
}
