namespace PaperPulse.Contracts;

public static class WindowsPhase0Contract
{
    public const string ProductName = "PaperPulse";
    public const string TargetClient = "Windows";
    public const string LocalAppDataFolder = "%LOCALAPPDATA%\\PaperPulse";
    public const string FeedPushMode = "ManualPushOnly";
    public const bool ReadsMacSwiftDataStore = false;
    public const bool MigratesBusinessLogicInPhase0 = false;
}
