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
        SetUiLanguage(uiLanguage);
        SetSummaryLanguage(summaryLanguage);
        KeywordLibraryBox.Text = keywordLibrary;
    }

    public string UiLanguage { get; private set; } = "en-US";
    public string SummaryLanguage { get; private set; } = "en-US";
    public string KeywordLibrary { get; private set; } = string.Empty;
    public bool ClearUnclassifiedRequested { get; private set; }
    public bool UiLanguageChanged => !string.Equals(initialUiLanguage, UiLanguage, StringComparison.Ordinal);

    private void Save_Click(ContentDialog sender, ContentDialogButtonClickEventArgs args)
    {
        KeywordLibrary = KeywordLibraryBox.Text.Trim();
    }

    private void UiLanguageOption_Click(object sender, RoutedEventArgs e)
    {
        if (sender is Button { Tag: string language } option)
        {
            SetUiLanguage(language, option.Content?.ToString());
            UiLanguageButton.Flyout?.Hide();
        }
    }

    private void SummaryLanguageOption_Click(object sender, RoutedEventArgs e)
    {
        if (sender is Button { Tag: string language } option)
        {
            SetSummaryLanguage(language, option.Content?.ToString());
            SummaryLanguageButton.Flyout?.Hide();
        }
    }

    private void SetUiLanguage(string language, string? displayName = null)
    {
        UiLanguage = language;
        UiLanguageText.Text = displayName ?? (language == "zh-CN" ? UiChineseOption.Content?.ToString() : UiEnglishOption.Content?.ToString());
    }

    private void SetSummaryLanguage(string language, string? displayName = null)
    {
        SummaryLanguage = language;
        SummaryLanguageText.Text = displayName ?? (language == "zh-CN" ? SummaryChineseOption.Content?.ToString() : SummaryEnglishOption.Content?.ToString());
    }

    private void ClearUnclassified_Click(object sender, RoutedEventArgs e)
    {
        ClearUnclassifiedRequested = true;
        Hide();
    }
}
