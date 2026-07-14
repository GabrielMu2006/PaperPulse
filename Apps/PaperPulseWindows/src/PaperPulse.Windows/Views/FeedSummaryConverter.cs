using Microsoft.UI.Xaml.Data;
using PaperPulse.Contracts;

namespace PaperPulse.Windows.Views;

public sealed class FeedSummaryConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, string language)
    {
        if (value is not FeedConfig feed) return string.Empty;
        IEnumerable<string> labels = feed.Categories.Count > 0 ? feed.Categories : feed.Keywords;
        string summary = string.Join(", ", labels.Take(2));
        return summary.Length == 0 ? "All configured sources" : summary;
    }

    public object ConvertBack(object value, Type targetType, object parameter, string language) => throw new NotSupportedException();
}
