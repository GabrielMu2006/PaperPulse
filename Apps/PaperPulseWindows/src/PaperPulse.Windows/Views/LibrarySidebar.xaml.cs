using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using PaperPulse.Contracts;

namespace PaperPulse.Windows.Views;

public sealed partial class LibrarySidebar : UserControl
{
    public LibrarySidebar()
    {
        InitializeComponent();
    }

    public event EventHandler? AddFeedRequested;
    public event EventHandler? SettingsRequested;
    public event EventHandler<FeedRequestEventArgs>? EditFeedRequested;
    public event EventHandler<FeedRequestEventArgs>? DeleteFeedRequested;

    private MainWindowViewModel? ViewModel => DataContext as MainWindowViewModel;

    private void AddFeed_Click(object sender, RoutedEventArgs e) => AddFeedRequested?.Invoke(this, EventArgs.Empty);
    private void Settings_Click(object sender, RoutedEventArgs e) => SettingsRequested?.Invoke(this, EventArgs.Empty);

    private void AllPapers_Click(object sender, RoutedEventArgs e) => ViewModel?.ShowAllPapers();

    private async void FeedPush_Click(object sender, RoutedEventArgs e)
    {
        if (sender is not Button { DataContext: FeedConfig feed } button || ViewModel is null) return;

        object? originalContent = button.Content;
        button.IsEnabled = false;
        button.Content = new ProgressRing { Width = 18, Height = 18, IsActive = true };
        try
        {
            await ViewModel.RefreshFeedAsync(feed);
        }
        finally
        {
            button.Content = originalContent;
            button.IsEnabled = true;
        }
    }

    private void EditFeed_Click(object sender, RoutedEventArgs e)
    {
        if (sender is Button { Tag: FeedConfig feed }) EditFeedRequested?.Invoke(this, new FeedRequestEventArgs(feed));
    }

    private void DeleteFeed_Click(object sender, RoutedEventArgs e)
    {
        if (sender is Button { Tag: FeedConfig feed }) DeleteFeedRequested?.Invoke(this, new FeedRequestEventArgs(feed));
    }

    private void FeedRow_PointerEntered(object sender, PointerRoutedEventArgs e) => SetFeedActionsVisible(sender, true);

    private void FeedRow_PointerExited(object sender, PointerRoutedEventArgs e) => SetFeedActionsVisible(sender, false);

    private static void SetFeedActionsVisible(object sender, bool visible)
    {
        if (sender is not FrameworkElement row || row.FindName("FeedActions") is not FrameworkElement actions) return;
        actions.Opacity = visible ? 1 : 0;
        actions.IsHitTestVisible = visible;
    }

    private void PaperList_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (sender is not ListView { SelectedItem: PaperLibraryItem item }) return;
        ViewModel?.SelectPaper(item.Paper);
    }
}

public sealed class FeedRequestEventArgs(FeedConfig feed) : EventArgs
{
    public FeedConfig Feed { get; } = feed;
}
