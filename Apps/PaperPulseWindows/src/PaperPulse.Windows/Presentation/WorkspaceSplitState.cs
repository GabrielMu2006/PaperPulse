using System.Globalization;

namespace PaperPulse.Windows.Presentation;

public static class WorkspaceSplitState
{
    public const double DefaultRatio = 0.5;
    public const double MinimumRatio = 0.25;
    public const double MaximumRatio = 0.75;

    public static double Clamp(double value)
    {
        if (double.IsNaN(value) || double.IsInfinity(value)) return DefaultRatio;
        return Math.Clamp(value, MinimumRatio, MaximumRatio);
    }

    public static double Parse(string? value)
    {
        return double.TryParse(value, NumberStyles.Float, CultureInfo.InvariantCulture, out double ratio)
            ? Clamp(ratio)
            : DefaultRatio;
    }

    public static string Format(double value)
    {
        return Clamp(value).ToString("0.###", CultureInfo.InvariantCulture);
    }
}
