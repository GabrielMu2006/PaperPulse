using CommunityToolkit.Mvvm.ComponentModel;
using PaperPulse.Storage;

namespace PaperPulse.Windows;

public sealed class PaperLibraryGroup : ObservableObject
{
    private bool isExpanded;

    public PaperLibraryGroup(PaperLibraryGroupDefinition definition, bool isExpanded)
    {
        Key = definition.Key;
        Name = definition.Name;
        IsUnclassified = definition.IsUnclassified;
        Papers = definition.Papers;
        this.isExpanded = isExpanded;
    }

    public string Key { get; }
    public string Name { get; }
    public bool IsUnclassified { get; }
    public IReadOnlyList<StoredPaper> Papers { get; }
    public string Header => $"{Name} ({Papers.Count})";

    public bool IsExpanded
    {
        get => isExpanded;
        set => SetProperty(ref isExpanded, value);
    }
}
