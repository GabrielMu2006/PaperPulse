using Xunit;
using PaperPulse.Contracts;
using PaperPulse.Storage;
using PaperPulse.Windows.Presentation;

namespace PaperPulse.Windows.Tests;

public sealed class WindowsShellTests
{
    [Fact]
    public void AppTypeLivesInWindowsAssembly()
    {
        Assert.Equal("PaperPulse.Windows", typeof(App).Namespace);
    }

    [Fact]
    public void WorkspaceSplitClampsToSupportedDetailRange()
    {
        Assert.Equal(0.5, WorkspaceSplitState.DefaultRatio);
        Assert.Equal(0.25, WorkspaceSplitState.Clamp(-1));
        Assert.Equal(0.5, WorkspaceSplitState.Clamp(0.5));
        Assert.Equal(0.75, WorkspaceSplitState.Clamp(2));
    }

    [Fact]
    public void WorkspaceSplitUsesInvariantPersistedValues()
    {
        Assert.Equal(WorkspaceSplitState.DefaultRatio, WorkspaceSplitState.Parse(null));
        Assert.Equal(WorkspaceSplitState.DefaultRatio, WorkspaceSplitState.Parse("not-a-number"));
        Assert.Equal(0.25, WorkspaceSplitState.Parse("0.1"));
        Assert.Equal(0.625, WorkspaceSplitState.Parse("0.625"));
        Assert.Equal("0.625", WorkspaceSplitState.Format(0.625));
    }

    [Fact]
    public void LibraryItemExposesFavoriteAndSelectionState()
    {
        StoredPaper paper = new(
            new PaperCandidate(PaperSourceKind.Arxiv, "2607.00001v1", "Selected paper", "A short abstract.", authors: ["Ada"]),
            null,
            null,
            DateTimeOffset.UnixEpoch,
            IsFavorite: true);

        PaperLibraryItem item = new(paper, isSelected: false);

        Assert.Equal(1, item.FavoriteOpacity);
        Assert.Equal(0, item.SelectionAccentOpacity);
        Assert.Equal("Ada", item.Authors);

        item.IsSelected = true;

        Assert.Equal(1, item.SelectionAccentOpacity);
    }
}
