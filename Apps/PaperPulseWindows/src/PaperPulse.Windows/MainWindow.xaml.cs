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
        if (!await Launcher.LaunchUriAsync(sourceUri)) ViewModel.Status = PaperPulseStrings.Get("CouldNotOpenSourcePage");
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
            await ShowSettingsSavedAsync(dialog.UiLanguageChanged);
        }
        else if (dialog.ClearUnclassifiedRequested)
        {
            await ConfirmClearUnclassifiedAsync();
        }
    }

    private async Task ShowSettingsSavedAsync(bool requiresRestart)
    {
        ContentDialog acknowledgement = new()
        {
            XamlRoot = ((FrameworkElement)Content).XamlRoot,
            Style = (Style)Application.Current.Resources["PaperPulseDialogStyle"],
            PrimaryButtonText = PaperPulseStrings.Get("Okay"),
            PrimaryButtonStyle = (Style)Application.Current.Resources["PaperPulseProminentButtonStyle"],
            Content = new StackPanel
            {
                Width = 360,
                Padding = new Thickness(24),
                Spacing = 10,
                Children =
                {
                    new SymbolIcon { Symbol = Symbol.Accept, Foreground = (Microsoft.UI.Xaml.Media.Brush)Application.Current.Resources["PulseMagentaBrush"] },
                    new TextBlock { Text = PaperPulseStrings.Get("SettingsSavedTitle"), FontSize = 20, FontWeight = Microsoft.UI.Text.FontWeights.SemiBold },
                    new TextBlock { Text = PaperPulseStrings.Get(requiresRestart ? "SettingsSavedRestart" : "SettingsSaved"), TextWrapping = TextWrapping.Wrap }
                }
            }
        };
        await acknowledgement.ShowAsync();
    }

    private async Task ConfirmClearUnclassifiedAsync()
    {
        ContentDialog confirmation = new()
        {
            XamlRoot = ((FrameworkElement)Content).XamlRoot,
            Title = PaperPulseStrings.Get("ClearUnclassifiedTitle"),
            Content = PaperPulseStrings.Get("ClearUnclassifiedContent"),
            PrimaryButtonText = PaperPulseStrings.Get("Clear"),
            CloseButtonText = PaperPulseStrings.Get("Cancel"),
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
            Title = PaperPulseStrings.Get("DeleteSubscriptionTitle"),
            Content = PaperPulseStrings.Format("DeleteSubscriptionContent", e.Feed.Name),
            PrimaryButtonText = PaperPulseStrings.Get("Delete"),
            CloseButtonText = PaperPulseStrings.Get("Cancel"),
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
        WorkspaceSplitterGrip.Opacity = isResizingWorkspace ? 1 : 0.7;
        e.Handled = isResizingWorkspace;
    }

    private void WorkspaceSplitter_PointerEntered(object sender, PointerRoutedEventArgs e) => WorkspaceSplitterGrip.Opacity = 1;

    private void WorkspaceSplitter_PointerExited(object sender, PointerRoutedEventArgs e)
    {
        if (!isResizingWorkspace) WorkspaceSplitterGrip.Opacity = 0.7;
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
        WorkspaceSplitterGrip.Opacity = 0.7;
        double workspaceWidth = InfoColumn.ActualWidth + PdfColumn.ActualWidth;
        if (workspaceWidth > 0) await ViewModel.SaveWorkspaceSplitRatioAsync(InfoColumn.ActualWidth / workspaceWidth);
        e.Handled = true;
    }

    private void WorkspaceSplitter_PointerCaptureLost(object sender, PointerRoutedEventArgs e)
    {
        isResizingWorkspace = false;
        WorkspaceSplitterGrip.Opacity = 0.7;
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
