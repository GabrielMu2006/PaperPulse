# PaperPulse Windows Control System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the Windows app a reusable PaperPulse control system while making the reading divider draggable at every height and making feed actions selection-driven.

**Architecture:** `PaperPulseControls.xaml` owns explicit WinUI templates for PaperPulse-facing input and action controls. Dialog views consume these styles through existing bindings and ContentDialog behavior. `MainWindow` owns pointer capture for workspace resize; `LibrarySidebar` maps its existing selected feed to row-local action visibility without changing the feed domain model.

**Tech Stack:** C#, WinUI 3, Windows App SDK, XAML ResourceDictionary, CommunityToolkit.Mvvm, GitHub Actions Windows packaging.

## Global Constraints

- Modify only `Apps/PaperPulseWindows` UI/theme presentation files and migration documentation.
- Do not modify iOS, macOS, Swift PaperCore, retrieval/download/LLM rules, SQLite/SwiftData schema, or Keychain/PasswordVault behavior.
- Keep all existing `ContentDialog` modal, validation, save/cancel, keyboard, accessibility, and localization behavior.
- Keep keyword-library labels and placeholders in English in both interface languages.
- Keep the favorite detail action, language-save/restart acknowledgement, automatic download-before-save behavior, and 1:1 default reading split unchanged.
- Do not add dependencies or use browser/computer-use tools.
- Use focused static validation on macOS; Windows CI is the build/test/package authority. Do not add ceremonial red-green tests for purely visual templates.

---

### Task 1: Create the Reusable PaperPulse Control Templates

**Files:**
- Modify: `Apps/PaperPulseWindows/src/PaperPulse.Windows/Themes/PaperPulseControls.xaml`
- Modify: `Apps/PaperPulseWindows/src/PaperPulse.Windows/Themes/PaperPulseTheme.xaml`

**Interfaces:**
- Consumes: existing brushes and dimensions including `MidnightBrush`, `GlassFillBrush`, `GlassStrokeBrush`, `PulseAccentBrush`, `PulseMagentaBrush`, `ShellTextBrush`, `ShellSecondaryTextBrush`, `InputCornerRadius`, and `OnePixelThickness`.
- Produces: stable `PaperPulseInputStyle`, `PaperPulsePasswordBoxStyle`, `PaperPulseComboBoxStyle`, `PaperPulseNumberBoxStyle`, `PaperPulseCheckBoxStyle`, `PaperPulseDialogStyle`, and existing button style keys with explicit visual state templates.

- [x] **Step 1: Define one shared input visual vocabulary in the theme dictionary**

Add input-state resources without changing semantic colors:

```xml
<SolidColorBrush x:Key="InputSurfaceBrush" Color="#171923" />
<SolidColorBrush x:Key="InputSurfacePointerOverBrush" Color="#202332" />
<SolidColorBrush x:Key="InputSurfaceFocusedBrush" Color="#252035" />
<SolidColorBrush x:Key="InputBorderFocusedBrush" Color="#EB1FA3" />
<SolidColorBrush x:Key="InputDisabledBrush" Color="#0CFFFFFF" />
```

Keep the existing dark-only theme dictionary and existing accent/favorite resources intact.

- [x] **Step 2: Replace input setter-only styles with explicit templates**

In `PaperPulseControls.xaml`, define custom control templates that retain WinUI editable content hosts. The TextBox template must keep `x:Name="ContentElement"` as the `ScrollViewer`, and the PasswordBox template must keep an editable content host. Both templates use a single `Root` border and unique state groups:

```xml
<Style x:Key="PaperPulseInputStyle" TargetType="TextBox">
    <Setter Property="MinHeight" Value="40" />
    <Setter Property="Padding" Value="12,8" />
    <Setter Property="Foreground" Value="{StaticResource ShellTextBrush}" />
    <Setter Property="PlaceholderForeground" Value="{StaticResource ShellSecondaryTextBrush}" />
    <Setter Property="SelectionHighlightColor" Value="#806B2BEB" />
    <Setter Property="Template">
        <Setter.Value>
            <ControlTemplate TargetType="TextBox">
                <Border x:Name="Root" Background="{StaticResource InputSurfaceBrush}"
                        BorderBrush="{StaticResource GlassStrokeBrush}" BorderThickness="{StaticResource OnePixelThickness}"
                        CornerRadius="{StaticResource InputCornerRadius}">
                    <ScrollViewer x:Name="ContentElement" Padding="{TemplateBinding Padding}"
                                  HorizontalScrollMode="Disabled" VerticalScrollMode="Auto"
                                  IsTabStop="False" />
                </Border>
                <VisualStateManager.VisualStateGroups>
                    <VisualStateGroup x:Name="CommonStates">
                        <VisualState x:Name="Normal" />
                        <VisualState x:Name="PointerOver"><VisualState.Setters><Setter Target="Root.Background" Value="{StaticResource InputSurfacePointerOverBrush}" /></VisualState.Setters></VisualState>
                        <VisualState x:Name="Disabled"><VisualState.Setters><Setter Target="Root.Background" Value="{StaticResource InputDisabledBrush}" /><Setter Target="Root.Opacity" Value="0.55" /></VisualState.Setters></VisualState>
                    </VisualStateGroup>
                    <VisualStateGroup x:Name="FocusStates">
                        <VisualState x:Name="Focused"><VisualState.Setters><Setter Target="Root.Background" Value="{StaticResource InputSurfaceFocusedBrush}" /><Setter Target="Root.BorderBrush" Value="{StaticResource InputBorderFocusedBrush}" /><Setter Target="Root.BorderThickness" Value="2" /></VisualState.Setters></VisualState>
                        <VisualState x:Name="Unfocused" />
                    </VisualStateGroup>
                </VisualStateManager.VisualStateGroups>
            </ControlTemplate>
        </Setter.Value>
    </Setter>
</Style>
```

Use the same surface hierarchy for PasswordBox, ComboBox, NumberBox, CheckBox, and ToggleButton. Give every template its own state-group names once only; do not merge duplicate `CommonStates` or `FocusStates` into a single control template. Preserve visible drop-down and spin affordances, and keep all compact icon buttons at their current fixed size.

- [x] **Step 3: Make the modal system consume the same component vocabulary**

Update `PaperPulseDialogStyle` and `PaperPulseFormSectionStyle` so dialog chrome is midnight, form sections are dark glass, corners stay within the documented 8-10 px range, and button footer behavior remains supplied by `ContentDialog`. Do not introduce a second nested card around the modal content.

- [x] **Step 4: Perform focused static validation**

Run:

```bash
git diff --check
rg -n 'x:Name="(Root|ContentElement)"|VisualStateGroup x:Name=' Apps/PaperPulseWindows/src/PaperPulse.Windows/Themes/PaperPulseControls.xaml
```

Expected: no whitespace errors; each control template has one editable host and no duplicated state-group names inside a template.

- [x] **Step 5: Commit the control-system foundation**

```bash
git add Apps/PaperPulseWindows/src/PaperPulse.Windows/Themes/PaperPulseControls.xaml Apps/PaperPulseWindows/src/PaperPulse.Windows/Themes/PaperPulseTheme.xaml
git commit -m "feat: add PaperPulse control templates"
```

### Task 2: Apply the Control System to Dialogs and Repair Their Header Composition

**Files:**
- Modify: `Apps/PaperPulseWindows/src/PaperPulse.Windows/Views/FeedEditorDialog.xaml`
- Modify: `Apps/PaperPulseWindows/src/PaperPulse.Windows/Views/SettingsDialog.xaml`
- Modify: `Apps/PaperPulseWindows/src/PaperPulse.Windows/MainWindow.xaml.cs`

**Interfaces:**
- Consumes: all style keys from Task 1; existing `FeedEditorDialog.EditedFeed`, `SettingsDialog.UiLanguageChanged`, and existing ContentDialog button events.
- Produces: a shared left-aligned icon/title/subtitle layout in both dialogs, with every visible form control using the PaperPulse template system.

- [x] **Step 1: Repair the shared dialog header grid**

Add explicit columns in both dialog headers so the icon and text form a single left-aligned unit:

```xml
<Grid ColumnSpacing="12">
    <Grid.ColumnDefinitions>
        <ColumnDefinition Width="38" />
        <ColumnDefinition Width="*" />
    </Grid.ColumnDefinitions>
    <Border Width="38" Height="38" Background="{StaticResource PulseAccentBrush}"
            CornerRadius="{StaticResource SmallCornerRadius}">
        <SymbolIcon HorizontalAlignment="Center" VerticalAlignment="Center" Foreground="White" Symbol="Edit" />
    </Border>
    <StackPanel Grid.Column="1" VerticalAlignment="Center" Spacing="2">
        <TextBlock x:Name="DialogTitleText" Foreground="{StaticResource ShellTextBrush}" FontSize="24" FontWeight="SemiBold" />
        <TextBlock x:Uid="FeedEditorDescription" Foreground="{StaticResource ShellSecondaryTextBrush}" TextWrapping="Wrap" />
    </StackPanel>
</Grid>
```

Use `Symbol="Setting"` and the existing settings resource identifiers for the Settings header. Do not put the icon in a separate right column or change dialog commands.

- [x] **Step 2: Apply explicit styles to every dialog control**

Use `PaperPulseInputStyle` on every `TextBox`, `PaperPulseComboBoxStyle` on every `ComboBox`, `PaperPulseNumberBoxStyle` on every `NumberBox`, and the new password/check styles wherever those controls appear. Keep field names, `x:Uid` values, placeholders, `AcceptsReturn`, `Minimum`, `Maximum`, `SpinButtonPlacementMode`, and event handlers unchanged.

- [x] **Step 3: Make acknowledgement and confirmation dialogs inherit the PaperPulse dialog style**

In `MainWindow.xaml.cs`, set `Style = (Style)Application.Current.Resources["PaperPulseDialogStyle"]`, `PrimaryButtonStyle`, and `CloseButtonStyle` on existing clear/delete confirmations, matching the already-styled settings-save acknowledgement. Do not change confirmation text or delete/clear behavior.

- [x] **Step 4: Perform focused static validation**

Run:

```bash
git diff --check
rg -n 'Grid.ColumnDefinitions|PaperPulse(Input|ComboBox|NumberBox|PasswordBox|CheckBox)Style' Apps/PaperPulseWindows/src/PaperPulse.Windows/Views/FeedEditorDialog.xaml Apps/PaperPulseWindows/src/PaperPulse.Windows/Views/SettingsDialog.xaml
```

Expected: both headers have explicit two-column layouts and all form-control style references resolve to Task 1 keys.

- [x] **Step 5: Commit the dialog integration**

```bash
git add Apps/PaperPulseWindows/src/PaperPulse.Windows/Views/FeedEditorDialog.xaml Apps/PaperPulseWindows/src/PaperPulse.Windows/Views/SettingsDialog.xaml Apps/PaperPulseWindows/src/PaperPulse.Windows/MainWindow.xaml.cs
git commit -m "feat: unify PaperPulse dialog controls"
```

### Task 3: Make Feed Actions Selection-Driven and Splitter Dragging Full-Height

**Files:**
- Modify: `Apps/PaperPulseWindows/src/PaperPulse.Windows/MainWindow.xaml`
- Modify: `Apps/PaperPulseWindows/src/PaperPulse.Windows/MainWindow.xaml.cs`
- Modify: `Apps/PaperPulseWindows/src/PaperPulse.Windows/Views/LibrarySidebar.xaml`
- Modify: `Apps/PaperPulseWindows/src/PaperPulse.Windows/Views/LibrarySidebar.xaml.cs`
- Modify: `Apps/PaperPulseWindows/src/PaperPulse.Windows/Presentation/WorkspaceSplitter.cs`

**Interfaces:**
- Consumes: `MainWindowViewModel.SaveWorkspaceSplitRatioAsync(double)`, `WorkspaceSplitState.Clamp(double)`, and `SelectedFeed` binding.
- Produces: `WorkspaceGrid_PointerPressed`, `WorkspaceGrid_PointerMoved`, `WorkspaceGrid_PointerReleased`, `WorkspaceGrid_PointerCaptureLost`, and `FeedsList_SelectionChanged` UI event handlers. No public domain API changes.

- [ ] **Step 1: Put pointer capture on a full-height workspace hit surface**

Set `WorkspaceGrid.Background="Transparent"` and attach the four pointer handlers to `WorkspaceGrid`. Keep the 8 px `WorkspaceSplitter` visual column and its centered 2 px x 48 px grip. On press, begin resize only when the pointer x-coordinate falls in the divider column:

```csharp
private bool IsPointerOverWorkspaceDivider(PointerRoutedEventArgs e)
{
    double x = e.GetCurrentPoint(WorkspaceGrid).Position.X;
    double dividerStart = InfoColumn.ActualWidth;
    return x >= dividerStart && x <= dividerStart + WorkspaceSplitter.ActualWidth;
}

private void WorkspaceGrid_PointerPressed(object sender, PointerRoutedEventArgs e)
{
    if (!IsPointerOverWorkspaceDivider(e)) return;
    workspaceAvailableWidth = InfoColumn.ActualWidth + PdfColumn.ActualWidth;
    if (workspaceAvailableWidth <= 0) return;
    workspaceStartInfoWidth = InfoColumn.ActualWidth;
    workspaceStartPointerX = e.GetCurrentPoint(WorkspaceGrid).Position.X;
    isResizingWorkspace = WorkspaceGrid.CapturePointer(e.Pointer);
    WorkspaceSplitterGrip.Opacity = isResizingWorkspace ? 1 : 0.7;
    e.Handled = isResizingWorkspace;
}
```

Move/release/capture-lost handlers keep the existing ratio calculation and persistence but operate on `WorkspaceGrid`. Keep `WorkspaceSplitter` solely for its full-height visual and resize cursor; remove its direct pointer handlers. This makes the entire divider column actionable even when the visual grip is short.

- [ ] **Step 2: Replace hover handlers with selected-feed action state**

Name the feed `ListView` `FeedsList`, remove `FeedRow_PointerEntered` and `FeedRow_PointerExited`, and add `SelectionChanged="FeedsList_SelectionChanged"`. Name the action stack `FeedActions` and register its `Loaded`/`Unloaded` events.

In `LibrarySidebar.xaml.cs`, track realized row action elements by feed ID and update them from `FeedsList.SelectedItem`:

```csharp
private readonly Dictionary<Guid, FrameworkElement> feedActionsById = new();

private void FeedActions_Loaded(object sender, RoutedEventArgs e)
{
    if (sender is not FrameworkElement { DataContext: FeedConfig feed } actions) return;
    feedActionsById[feed.Id] = actions;
    UpdateSelectedFeedActions();
}

private void FeedsList_SelectionChanged(object sender, SelectionChangedEventArgs e) => UpdateSelectedFeedActions();

private void UpdateSelectedFeedActions()
{
    Guid? selectedId = FeedsList.SelectedItem is FeedConfig feed ? feed.Id : null;
    foreach ((Guid feedId, FrameworkElement actions) in feedActionsById)
    {
        bool visible = feedId == selectedId;
        actions.Opacity = visible ? 1 : 0;
        actions.IsHitTestVisible = visible;
    }
}
```

On `Unloaded`, remove the action element only if it is the currently registered instance for that feed. Leave paper-plane button markup and existing edit/delete events untouched. This preserves selection behavior for keyboard and mouse without new feed properties.

- [ ] **Step 3: Keep the splitter control's layout full-height**

Make `WorkspaceSplitter` expose its resize cursor and stretch its XAML content across the final arrangement rectangle so the visual track and the parent hit-test column remain coherent:

```csharp
public sealed class WorkspaceSplitter : ContentControl
{
    public WorkspaceSplitter()
    {
        ProtectedCursor = InputSystemCursor.Create(InputSystemCursorShape.SizeWestEast);
        HorizontalContentAlignment = HorizontalAlignment.Stretch;
        VerticalContentAlignment = VerticalAlignment.Stretch;
    }
}
```

Do not alter the splitter width, ratio clamp, or persisted setting key.

- [ ] **Step 4: Perform focused static validation**

Run:

```bash
git diff --check
rg -n 'WorkspaceGrid_Pointer|IsPointerOverWorkspaceDivider|FeedsList_SelectionChanged|FeedRow_Pointer' Apps/PaperPulseWindows/src/PaperPulse.Windows
```

Expected: `WorkspaceGrid_Pointer*` and `FeedsList_SelectionChanged` are present; `FeedRow_Pointer*` is absent; no whitespace errors occur.

- [ ] **Step 5: Commit the interaction repairs**

```bash
git add Apps/PaperPulseWindows/src/PaperPulse.Windows/MainWindow.xaml Apps/PaperPulseWindows/src/PaperPulse.Windows/MainWindow.xaml.cs Apps/PaperPulseWindows/src/PaperPulse.Windows/Views/LibrarySidebar.xaml Apps/PaperPulseWindows/src/PaperPulse.Windows/Views/LibrarySidebar.xaml.cs Apps/PaperPulseWindows/src/PaperPulse.Windows/Presentation/WorkspaceSplitter.cs
git commit -m "fix: refine windows workspace interactions"
```

### Task 4: Verify on Windows CI and Complete the Manual Gate

**Files:**
- Modify: `docs/development/windows-migration-handoff.md` only if the exact CI URL, commit SHA, and manual-verification outcome need recording.

**Interfaces:**
- Consumes: GitHub Actions workflow `.github/workflows/windows-validation.yml` and the Windows manual verification checklist from the approved design.
- Produces: a Windows build/test/package result for the implementation SHA and a user-confirmed F5 visual gate.

- [ ] **Step 1: Push the implementation commits**

```bash
git push origin codex/paperpulse-windows-migration
```

Expected: the Windows validation workflow starts for the pushed SHA.

- [ ] **Step 2: Check the exact GitHub Actions result through the GitHub CLI**

```bash
gh run list --branch codex/paperpulse-windows-migration --workflow windows-validation.yml --limit 1
gh run view <run-id> --log-failed
```

Expected: Build, test, unsigned MSIX package, and artifact upload all conclude successfully. If not, use the failed log to make a focused code correction before requesting Windows manual verification.

- [ ] **Step 3: Ask for the Windows F5 gate**

Ask the Windows operator to verify normal and maximized window states; drag from upper/middle/lower divider positions; selection actions by mouse/keyboard; dialog input, typing, focus, validation, Save/Cancel; and retained favorite/language/keyword behavior. Ask for screenshots only for a failed visual state.

- [ ] **Step 4: Record the completed milestone**

When CI and the manual gate both succeed, append the resulting commit SHA, Actions run URL, and concise manual-verification result to `docs/development/windows-migration-handoff.md`, then commit:

```bash
git add docs/development/windows-migration-handoff.md
git commit -m "docs: record control system verification"
git push origin codex/paperpulse-windows-migration
```

## Plan Self-Review

- **Spec coverage:** Task 1 covers the reusable template layer and distinct visual language. Task 2 covers the left-aligned dialog header and complete dialog control adoption. Task 3 covers full-height splitter drag and selected-row feed actions. Task 4 covers CI and the required Windows visual/interaction gate.
- **No-placeholder review:** Commands, file paths, handlers, bindings, and expected results are explicit. The only variable is `<run-id>`, which is emitted by the preceding `gh run list` command.
- **Type consistency:** Task 3 consumes only existing `FeedConfig`, `FrameworkElement`, `ListView`, `WorkspaceGrid`, and `WorkspaceSplitter` identifiers; new methods are named consistently in XAML and code-behind.
