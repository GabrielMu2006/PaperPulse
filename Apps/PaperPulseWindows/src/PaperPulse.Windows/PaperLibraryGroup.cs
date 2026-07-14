using CommunityToolkit.Mvvm.ComponentModel;
using PaperPulse.Storage;

namespace PaperPulse.Windows;

public sealed class PaperLibraryGroup : ObservableObject
{
    private bool isExpanded;

    public PaperLibraryGroup(PaperLibraryGroupDefinition definition, bool isExpanded, string? selectedPaperId)
    {
        Key = definition.Key;
        Name = definition.Name;
        IsUnclassified = definition.IsUnclassified;
        Papers = definition.Papers.Select(paper => new PaperLibraryItem(paper, paper.Candidate.StableId == selectedPaperId)).ToList();
        this.isExpanded = isExpanded;
    }

    public string Key { get; }
    public string Name { get; }
    public bool IsUnclassified { get; }
    public IReadOnlyList<PaperLibraryItem> Papers { get; }
    public string Header => $"{Name} ({Papers.Count})";
    public double EmptyStateOpacity => Papers.Count == 0 ? 1 : 0;

    public bool IsExpanded
    {
        get => isExpanded;
        set => SetProperty(ref isExpanded, value);
    }
}

public sealed partial class PaperLibraryItem : ObservableObject
{
    private bool isSelected;

    public PaperLibraryItem(StoredPaper paper, bool isSelected)
    {
        Paper = paper;
        this.isSelected = isSelected;
    }

    public StoredPaper Paper { get; }
    public string Title => Paper.Candidate.Title;
    public string Authors => Paper.Candidate.Authors.Count == 0 ? "Unknown author" : string.Join(", ", Paper.Candidate.Authors);
    public string Brief => Paper.Candidate.Summary;
    public string Date => Paper.Candidate.PublishedAt?.ToLocalTime().ToString("yyyy-MM-dd") ?? "Date unavailable";
    public double FavoriteOpacity => Paper.IsFavorite ? 1 : 0;
    public double SelectionAccentOpacity => IsSelected ? 1 : 0;

    public bool IsSelected
    {
        get => isSelected;
        set
        {
            if (!SetProperty(ref isSelected, value)) return;
            OnPropertyChanged(nameof(SelectionAccentOpacity));
        }
    }
}
