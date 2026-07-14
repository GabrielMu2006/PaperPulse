using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Input;
using PaperPulse.Contracts;

namespace PaperPulse.Windows.Views;

public sealed partial class LibrarySidebar : UserControl
{
    private readonly Dictionary<Guid, FrameworkElement> feedActionsById = new();

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

    private void FeedActions_Loaded(object sender, RoutedEventArgs e)
    {
        if (sender is not FrameworkElement { DataContext: FeedConfig feed } actions) return;
        feedActionsById[feed.Id] = actions;
        UpdateSelectedFeedActions();
    }

    private void FeedActions_Unloaded(object sender, RoutedEventArgs e)
    {
        if (sender is not FrameworkElement { DataContext: FeedConfig feed } actions) return;
        if (feedActionsById.TryGetValue(feed.Id, out FrameworkElement? registered) && ReferenceEquals(registered, actions))
        {
            feedActionsById.Remove(feed.Id);
        }
    }

    private void FeedsList_SelectionChanged(object sender, SelectionChangedEventArgs e) => UpdateSelectedFeedActions();

    private void UpdateSelectedFeedActions()
    {
        Guid? selectedId = FeedsList.SelectedItem is FeedConfig feed ? feed.Id : null;
        foreach ((Guid feedId, FrameworkElement actions) in feedActionsById)
        {
            bool visible = feedId == selectedId;
            actions.Opacity = visible ? 1 : 0;
            actions.IsHitTestVisible = visible;
        }
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
