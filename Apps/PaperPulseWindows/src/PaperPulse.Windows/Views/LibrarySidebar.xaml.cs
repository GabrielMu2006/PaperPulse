using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using PaperPulse.Contracts;
using PaperPulse.Storage;

namespace PaperPulse.Windows.Views;

public sealed partial class LibrarySidebar : UserControl
{
    public LibrarySidebar()
    {
        InitializeComponent();
    }

    public event EventHandler? AddFeedRequested;
    public event EventHandler<FeedRequestEventArgs>? EditFeedRequested;
    public event EventHandler<FeedRequestEventArgs>? DeleteFeedRequested;
    public event EventHandler<PaperSelectionEventArgs>? PaperSelected;

    private MainWindowViewModel? ViewModel => DataContext as MainWindowViewModel;

    private void AddFeed_Click(object sender, RoutedEventArgs e) => AddFeedRequested?.Invoke(this, EventArgs.Empty);

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
        if (sender is MenuFlyoutItem { Tag: FeedConfig feed }) EditFeedRequested?.Invoke(this, new FeedRequestEventArgs(feed));
    }

    private void DeleteFeed_Click(object sender, RoutedEventArgs e)
    {
        if (sender is MenuFlyoutItem { Tag: FeedConfig feed }) DeleteFeedRequested?.Invoke(this, new FeedRequestEventArgs(feed));
    }

    private void PaperList_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (sender is not ListView { SelectedItem: PaperLibraryItem item }) return;
        ViewModel?.SelectPaper(item.Paper);
        PaperSelected?.Invoke(this, new PaperSelectionEventArgs(item.Paper));
    }
}

public sealed class FeedRequestEventArgs(FeedConfig feed) : EventArgs
{
    public FeedConfig Feed { get; } = feed;
}

public sealed class PaperSelectionEventArgs(StoredPaper paper) : EventArgs
{
    public StoredPaper Paper { get; } = paper;
}
