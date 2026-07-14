using System.Globalization;
using Microsoft.Windows.ApplicationModel.Resources;

namespace PaperPulse.Windows.Presentation;

internal static class PaperPulseStrings
{
    private static readonly ResourceLoader Loader = new();

    public static string Get(string key)
    {
        string value = Loader.GetString(key);
        return string.IsNullOrWhiteSpace(value) ? key : value;
    }

    public static string Format(string key, params object[] arguments) =>
        string.Format(CultureInfo.CurrentUICulture, Get(key), arguments);
}
