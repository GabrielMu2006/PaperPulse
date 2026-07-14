using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Input;
using PaperPulse.Contracts;
using PaperPulse.Windows.Presentation;
using PaperPulse.Windows.Views;
using Windows.System;

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

    private async void PaperDetailPane_FavoriteRequested(object sender, EventArgs e) => await ViewModel.ToggleFavoriteAsync();

    private async void PaperDetailPane_SourceRequested(object sender, EventArgs e)
    {
        if (ViewModel.SelectedSourceUri is not { } sourceUri) return;
        if (!await Launcher.LaunchUriAsync(sourceUri)) ViewModel.Status = "Could not open the source page.";
    }

    private async void LibrarySidebar_AddFeedRequested(object sender, EventArgs e) => await EditFeedAsync(null);

    private async void LibrarySidebar_SettingsRequested(object sender, EventArgs e)
    {
        SettingsDialog dialog = new(ViewModel.UiLanguage, ViewModel.SummaryLanguage, ViewModel.KeywordLibraryText)
        {
            XamlRoot = ((FrameworkElement)Content).XamlRoot
        };
        if (await dialog.ShowAsync() == ContentDialogResult.Primary)
        {
            await ViewModel.SaveSettingsAsync(dialog.UiLanguage, dialog.SummaryLanguage, dialog.KeywordLibrary);
        }
        else if (dialog.ClearUnclassifiedRequested)
        {
            await ConfirmClearUnclassifiedAsync();
        }
    }

    private async Task ConfirmClearUnclassifiedAsync()
    {
        ContentDialog confirmation = new()
        {
            XamlRoot = ((FrameworkElement)Content).XamlRoot,
            Title = "Clear unclassified papers?",
            Content = "This deletes unclassified papers, their local PDFs, and their saved interpretations.",
            PrimaryButtonText = "Clear",
            CloseButtonText = "Cancel",
            DefaultButton = ContentDialogButton.Close
        };
        if (await confirmation.ShowAsync() == ContentDialogResult.Primary)
        {
            await ViewModel.ClearUnclassifiedPapersAsync();
        }
    }

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
        FeedEditorDialog editor = new(existing)
        {
            XamlRoot = ((FrameworkElement)Content).XamlRoot
        };

        if (await editor.ShowAsync() == ContentDialogResult.Primary && editor.EditedFeed is { } feed) await ViewModel.SaveFeedAsync(feed);
    }

    private void ApplyWorkspaceSplit(double ratio)
    {
        double clamped = WorkspaceSplitState.Clamp(ratio);
        InfoColumn.Width = new GridLength(clamped, GridUnitType.Star);
        PdfColumn.Width = new GridLength(1 - clamped, GridUnitType.Star);
    }
}
