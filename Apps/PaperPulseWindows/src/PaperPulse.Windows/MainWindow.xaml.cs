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
    }

    private async void Refresh_Click(object sender, RoutedEventArgs e) => await ViewModel.RefreshSelectedFeedAsync();

    private void Favorite_Click(object sender, RoutedEventArgs e) => ViewModel.ToggleFavorite();

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

        if (await confirmation.ShowAsync() == ContentDialogResult.Primary) ViewModel.DeleteSelectedFeed();
    }

    private void PaperList_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (sender is ListView { SelectedItem: StoredPaper paper }) ViewModel.SelectPaper(paper);
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
        ViewModel.SaveFeed(feed);
    }
}
