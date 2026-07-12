using PaperPulse.Contracts;
using Xunit;

namespace PaperPulse.Contracts.Tests;

public sealed class WindowsPhase0ContractTests
{
    [Fact]
    public void ContractCapturesPhase0ProductBoundary()
    {
        Assert.Equal("PaperPulse", WindowsPhase0Contract.ProductName);
        Assert.Equal("Windows", WindowsPhase0Contract.TargetClient);
        Assert.Equal("%LOCALAPPDATA%\\PaperPulse", WindowsPhase0Contract.LocalAppDataFolder);
        Assert.Equal("ManualPushOnly", WindowsPhase0Contract.FeedPushMode);
        Assert.False(WindowsPhase0Contract.ReadsMacSwiftDataStore);
        Assert.False(WindowsPhase0Contract.MigratesBusinessLogicInPhase0);
    }
}
