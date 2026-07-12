using Xunit;

namespace PaperPulse.Windows.Tests;

public sealed class WindowsShellTests
{
    [Fact]
    public void AppTypeLivesInWindowsAssembly()
    {
        Assert.Equal("PaperPulse.Windows", typeof(App).Namespace);
    }
}
