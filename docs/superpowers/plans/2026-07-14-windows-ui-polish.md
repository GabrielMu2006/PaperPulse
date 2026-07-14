# PaperPulse Windows UI Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Do not add artificial red/green cycles for XAML visual styling or resource edits.

**Goal:** Make the PaperPulse Windows controls, dialogs, feed actions, favorite state, and workspace separator match the documented research-workbench visual system.

**Architecture:** Keep persistence and feed behavior in the existing view model and repository. XAML theme resources provide the shared visual treatment; views expose only local visual state and events. `ContentDialog` remains the modal host while custom PaperPulse content, headers, form sections, and footer actions replace its stock appearance.

**Tech Stack:** C# 14, WinUI 3, Windows App SDK, XAML resources, CommunityToolkit.Mvvm, xUnit, GitHub Actions.

## Global Constraints

- Do not modify iOS, macOS, Swift PaperCore, SQLite schema, retrieval, ranking, download-before-save, PDF validation, LLM behavior, or PasswordVault boundaries.
- `Keyword library`, its placeholder, and built-in examples remain English in every UI language; user-entered values remain unchanged.
- Source/model/protocol proper names remain unlocalized.
- Keep native ContentDialog focus, keyboard, escape, and modal behavior.
- Windows CI proves build/tests/MSIX; Windows 11 is used only after CI for a single visual F5 gate.

---

### Task 1: Shared PaperPulse Control and Dialog System

**Files:**
- Modify: `Apps/PaperPulseWindows/src/PaperPulse.Windows/Themes/PaperPulseControls.xaml`
- Modify: `Apps/PaperPulseWindows/src/PaperPulse.Windows/Views/FeedEditorDialog.xaml`
- Modify: `Apps/PaperPulseWindows/src/PaperPulse.Windows/Views/SettingsDialog.xaml`

**Produces:** named styles for quiet, icon, primary, destructive, form, form-section, and dialog controls used by both dialogs and the workspace.

- [x] Add explicit visual-state templates for PaperPulse buttons and toggles: normal, pointer-over, pressed, disabled, and focused.
- [x] Add dark-glass text, combo, and number input styles plus reusable rounded form sections.
- [x] Rebuild Feed Editor and Settings as branded in-app dialog panels with icon/header, scrollable grouped form content, and fixed styled footer actions.
- [x] Add a visible settings helper stating that changes apply only after Save.
- [x] Keep keyword-library static text and placeholder English in both resource languages.
- [x] Run resource XML validation and `git diff --check`.

### Task 2: Workspace Favorite and Splitter Interaction

**Files:**
- Modify: `Apps/PaperPulseWindows/src/PaperPulse.Windows/Views/PaperDetailPane.xaml`
- Modify: `Apps/PaperPulseWindows/src/PaperPulse.Windows/Views/PaperDetailPane.xaml.cs`
- Modify: `Apps/PaperPulseWindows/src/PaperPulse.Windows/MainWindow.xaml`
- Modify: `Apps/PaperPulseWindows/src/PaperPulse.Windows/Presentation/WorkspaceSplitter.cs`
- Test: `Apps/PaperPulseWindows/tests/PaperPulse.Windows.Tests/WindowsShellTests.cs`

**Produces:** favorite icon state mapped from `PaperDetailPresentation.IsFavorite` and a full-height 8 px workspace splitter hit target.

- [x] Add one focused presentation test covering the favorite boolean exposed for a favorited stored paper.
- [x] Render the detail favorite icon as outline or filled gold based on the existing presentation state.
- [x] Make the separator's transparent control surface fill its entire column/height, leaving only its centered 2 px grip visibly drawn.
- [x] Add hover/drag visual feedback without changing persisted split-ratio logic.
- [ ] Run the focused test when .NET is available; otherwise record the Mac SDK blocker and rely on Windows CI.

### Task 3: Discoverable Feed Actions

**Files:**
- Modify: `Apps/PaperPulseWindows/src/PaperPulse.Windows/Views/LibrarySidebar.xaml`
- Modify: `Apps/PaperPulseWindows/src/PaperPulse.Windows/Views/LibrarySidebar.xaml.cs`
- Modify: `Apps/PaperPulseWindows/src/PaperPulse.Windows/Strings/en-US/Resources.resw`
- Modify: `Apps/PaperPulseWindows/src/PaperPulse.Windows/Strings/zh-CN/Resources.resw`

**Produces:** right-side edit/delete icon actions that fade in on feed-row hover and emit the existing typed feed events.

- [x] Replace the feed context-menu dependency with edit/delete icon buttons that have fixed slots and tooltips/accessibility labels.
- [x] Keep paper-plane placement stable and show edit/delete only when the row is hovered.
- [x] Update code-behind event extraction for Button `DataContext` while preserving existing MainWindow confirmation flow.
- [x] Validate both resource files and `git diff --check`.

### Task 4: Settings Save/Restart Message and Localization

**Files:**
- Modify: `Apps/PaperPulseWindows/src/PaperPulse.Windows/MainWindow.xaml.cs`
- Modify: `Apps/PaperPulseWindows/src/PaperPulse.Windows/Views/SettingsDialog.xaml.cs`
- Modify: `Apps/PaperPulseWindows/src/PaperPulse.Windows/Strings/en-US/Resources.resw`
- Modify: `Apps/PaperPulseWindows/src/PaperPulse.Windows/Strings/zh-CN/Resources.resw`

**Produces:** a PaperPulse-styled acknowledgement after Save, with restart-specific copy only when the UI language changed.

- [x] Preserve the opening UI-language value in `SettingsDialog` and expose `UiLanguageChanged` after the primary Save action.
- [x] After settings persistence completes, show a stylized acknowledgement dialog; use restart copy only for an interface-language change.
- [x] Keep all setting writes inside the existing `SaveSettingsAsync` path.
- [x] Run resource/XML and whitespace checks.

### Task 5: Integration Verification and Handoff

**Files:**
- Modify: `docs/superpowers/plans/2026-07-14-windows-ui-polish.md`

- [x] Run local resource-key completeness checks and `git diff --check`.
- [ ] Commit the implementation as `feat: polish windows native UI` and push the migration branch.
- [ ] Confirm Windows CI build, tests, and MSIX package are green.
- [ ] Request one Windows Phase 3 F5 visual gate for normal/maximized splitter drag, favorite transition, hover feed actions, English/Chinese dialog wrapping, and save/restart acknowledgement.
