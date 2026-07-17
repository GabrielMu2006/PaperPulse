using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using PaperPulse.Contracts;
using PaperPulse.Windows.Presentation;

namespace PaperPulse.Windows.Views;

public sealed partial class FeedEditorDialog : ContentDialog
{
    private readonly FeedConfig? existing;

    public FeedEditorDialog(FeedConfig? existing)
    {
        this.existing = existing;
        InitializeComponent();
        DialogTitleText.Text = existing is null ? PaperPulseStrings.Get("FeedEditorNewTitle") : PaperPulseStrings.Get("FeedEditorEditTitle");
        Populate(existing);
    }

    public FeedConfig? EditedFeed { get; private set; }

    private void Populate(FeedConfig? feed)
    {
        NameBox.Text = feed?.Name ?? string.Empty;
        CategoriesBox.Text = Join(feed?.Categories);
        KeywordsBox.Text = Join(feed?.Keywords);
        ExcludedKeywordsBox.Text = Join(feed?.ExcludedKeywords);
        InstitutionsBox.Text = Join(feed?.RequiredInstitutions);
        VenuesBox.Text = Join(feed?.RequiredVenues);
        ArxivCheckBox.IsChecked = Enabled(feed, PaperSourceKind.Arxiv);
        OpenAlexCheckBox.IsChecked = Enabled(feed, PaperSourceKind.OpenAlex);
        CrossrefCheckBox.IsChecked = Enabled(feed, PaperSourceKind.Crossref);
        DailyLimitBox.Text = Clamp(feed?.AuthorityPolicy.DailyLimit ?? 8, 1, 10).ToString();
        LookbackDaysBox.Text = Clamp(feed?.LookbackDays ?? 7, 1, 365).ToString();
    }

    private void Save_Click(ContentDialog sender, ContentDialogButtonClickEventArgs args)
    {
        List<PaperSourceKind> sources = [];
        if (ArxivCheckBox.IsChecked == true) sources.Add(PaperSourceKind.Arxiv);
        if (OpenAlexCheckBox.IsChecked == true) sources.Add(PaperSourceKind.OpenAlex);
        if (CrossrefCheckBox.IsChecked == true) sources.Add(PaperSourceKind.Crossref);
        List<string> categories = Split(CategoriesBox.Text);
        List<string> keywords = Split(KeywordsBox.Text);

        if (string.IsNullOrWhiteSpace(NameBox.Text) || (categories.Count == 0 && keywords.Count == 0) || sources.Count == 0)
        {
            ValidationText.Text = PaperPulseStrings.Get("FeedEditorValidation");
            ValidationText.Visibility = Visibility.Visible;
            args.Cancel = true;
            return;
        }

        AuthorityPolicy authority = (existing?.AuthorityPolicy ?? new AuthorityPolicy()) with
        {
            DailyLimit = Clamp(DailyLimitBox.Text, 1, 10)
        };
        EditedFeed = (existing ?? new FeedConfig()) with
        {
            Name = NameBox.Text.Trim(),
            Categories = categories,
            Keywords = keywords,
            ExcludedKeywords = Split(ExcludedKeywordsBox.Text),
            RequiredInstitutions = Split(InstitutionsBox.Text),
            RequiredVenues = Split(VenuesBox.Text),
            EnabledSources = sources,
            AuthorityPolicy = authority,
            LookbackDays = Clamp(LookbackDaysBox.Text, 1, 365)
        };
    }

    private void NumericBox_BeforeTextChanging(TextBox sender, TextBoxBeforeTextChangingEventArgs args)
    {
        args.Cancel = args.NewText.Any(character => !char.IsAsciiDigit(character));
    }

    private static bool Enabled(FeedConfig? feed, PaperSourceKind source) => feed?.EnabledSources.Contains(source) ?? true;

    private static string Join(IEnumerable<string>? values) => string.Join(", ", values ?? []);

    private static List<string> Split(string value) => value
        .Split(',', StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries)
        .ToList();

    private static int Clamp(double value, int minimum, int maximum) => double.IsNaN(value)
        ? minimum
        : Math.Clamp((int)Math.Round(value), minimum, maximum);

    private static int Clamp(string value, int minimum, int maximum) => int.TryParse(value, out int parsed)
        ? Math.Clamp(parsed, minimum, maximum)
        : minimum;
}
