using Microsoft.UI.Xaml;

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
}
