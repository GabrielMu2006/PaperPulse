using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace PaperPulse.Windows.Views;

public sealed partial class SettingsDialog : ContentDialog
{
    private readonly string initialUiLanguage;

    public SettingsDialog(string uiLanguage, string summaryLanguage, string keywordLibrary)
    {
        initialUiLanguage = uiLanguage;
        InitializeComponent();
        Title = null;
        UiLanguageBox.SelectedIndex = uiLanguage == "zh-CN" ? 1 : 0;
        SummaryLanguageBox.SelectedIndex = summaryLanguage == "zh-CN" ? 1 : 0;
        KeywordLibraryBox.Text = keywordLibrary;
    }

    public string UiLanguage { get; private set; } = "en-US";
    public string SummaryLanguage { get; private set; } = "en-US";
    public string KeywordLibrary { get; private set; } = string.Empty;
    public bool ClearUnclassifiedRequested { get; private set; }
    public bool UiLanguageChanged => !string.Equals(initialUiLanguage, UiLanguage, StringComparison.Ordinal);

    private void Save_Click(ContentDialog sender, ContentDialogButtonClickEventArgs args)
    {
        UiLanguage = ((ComboBoxItem)UiLanguageBox.SelectedItem).Tag.ToString()!;
        SummaryLanguage = ((ComboBoxItem)SummaryLanguageBox.SelectedItem).Tag.ToString()!;
        KeywordLibrary = KeywordLibraryBox.Text.Trim();
    }

    private void ClearUnclassified_Click(object sender, RoutedEventArgs e)
    {
        ClearUnclassifiedRequested = true;
        Hide();
    }
}
