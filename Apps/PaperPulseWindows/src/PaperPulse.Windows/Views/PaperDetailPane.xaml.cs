using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using PaperPulse.Windows.Presentation;

namespace PaperPulse.Windows.Views;

public sealed partial class PaperDetailPane : UserControl
{
    public static readonly DependencyProperty PresentationProperty = DependencyProperty.Register(
        nameof(Presentation),
        typeof(PaperDetailPresentation),
        typeof(PaperDetailPane),
        new PropertyMetadata(null, OnPresentationChanged));

    public PaperDetailPane()
    {
        InitializeComponent();
    }

    public event EventHandler? FavoriteRequested;
    public event EventHandler? SourceRequested;

    public PaperDetailPresentation? Presentation
    {
        get => (PaperDetailPresentation?)GetValue(PresentationProperty);
        set => SetValue(PresentationProperty, value);
    }

    private static void OnPresentationChanged(DependencyObject dependencyObject, DependencyPropertyChangedEventArgs args)
    {
        ((PaperDetailPane)dependencyObject).ApplyPresentation(args.NewValue as PaperDetailPresentation);
    }

    private void ApplyPresentation(PaperDetailPresentation? presentation)
    {
        bool hasPaper = presentation?.HasPaper == true;
        EmptyState.Visibility = hasPaper ? Visibility.Collapsed : Visibility.Visible;
        PaperContent.Visibility = hasPaper ? Visibility.Visible : Visibility.Collapsed;
        FavoriteButton.IsEnabled = hasPaper;
        SourceButton.Visibility = presentation?.HasSourceUri == true ? Visibility.Visible : Visibility.Collapsed;
        PaperContent.DataContext = presentation;
    }

    private void Favorite_Click(object sender, RoutedEventArgs e) => FavoriteRequested?.Invoke(this, EventArgs.Empty);

    private void Source_Click(object sender, RoutedEventArgs e) => SourceRequested?.Invoke(this, EventArgs.Empty);
}
