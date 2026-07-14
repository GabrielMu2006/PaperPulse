using Microsoft.UI.Xaml;
using PaperPulse.Storage;
using Windows.Globalization;

namespace PaperPulse.Windows;

public partial class App : Application
{
    private Window? window;

    public App()
    {
        string language = new SqlitePaperPulseRepository(new PaperPulsePaths()).GetSetting("uiLanguage") ?? "en-US";
        ApplicationLanguages.PrimaryLanguageOverride = language;
        InitializeComponent();
    }

    protected override void OnLaunched(LaunchActivatedEventArgs args)
    {
        window = new MainWindow();
        window.Activate();
    }
}
