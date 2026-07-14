# PaperPulse Windows UI Polish Design

## Purpose

Bring the Windows research workspace, dialogs, and controls into the documented PaperPulse visual system without changing retrieval, download, PDF validation, data schema, or credential storage behavior.

## Scope

This revision makes seven targeted changes.

1. **Keyword library stays English.** The `Keyword library` label, placeholder, and built-in keyword examples remain English in both `en-US` and `zh-CN`. User-entered keyword text is never translated or changed.
2. **Favorite state is explicit.** The detail-pane star binds to the selected paper's favorite state: an outline for not-favorited, a filled warm-gold star for favorited. The change is immediate after the existing favorite command completes.
3. **Splitter has a full-height hit target.** The visual separator remains a restrained 2 px grip in an 8 px track, but the track itself accepts pointer capture from the workspace top through bottom. Maximize changes only its height, never its drag affordance.
4. **Feed actions are discoverable.** Every feed row shows compact edit and delete icon buttons only while hovered or keyboard-focused. The existing paper-plane action keeps its stable location. Delete remains destructive and confirmed; the context menu may be removed once the buttons provide the equivalent actions.
5. **Settings save contract is visible.** Settings display a persistent helper that changes take effect only after Save. When a UI-language change is saved, a follow-up PaperPulse-styled dialog says that the change is saved and PaperPulse must be restarted. No setting is written before Save.
6. **Dialogs use the PaperPulse system.** Feed editing and settings retain `ContentDialog` behavior for focus management, keyboard navigation, escape handling, and modal layering. Their visual content is rebuilt as a dark in-app panel: branded header, grouped glass form surfaces, scrolling content, and a fixed footer with PaperPulse styles rather than default WinUI presentation.
7. **Shared controls lose default WinUI appearance.** PaperPulse-specific button, toggle, text, combo, and number-input templates provide the same dark-glass surface, 1 px stroke, focus ring, hover, pressed, disabled, and destructive states. The primary action alone uses the documented red-magenta-purple emphasis; ordinary controls remain quiet.

## Component Boundaries

- `Themes/PaperPulseControls.xaml` owns the reusable control templates and dialog, form-section, and action-button styles.
- `Views/LibrarySidebar.xaml` owns feed-row hover/focus presentation. Its existing code-behind events and feed selection/push behavior remain unchanged.
- `Views/PaperDetailPane.xaml(.cs)` owns favorite icon presentation only. Persistence stays in `MainWindowViewModel.ToggleFavoriteAsync`.
- `MainWindow.xaml(.cs)` owns splitter hit-testing and the save/restart notification after the settings dialog closes.
- `Views/SettingsDialog.xaml(.cs)` and `Views/FeedEditorDialog.xaml(.cs)` own presentation and unsaved-change guidance. Their existing feed fields, validation, and settings persistence boundary remain intact.
- `.resw` resources own all localized copy except the intentionally invariant English keyword-library text and source/model/protocol proper names.

## Interaction Details

- Feed-row edit/delete opacity is controlled by the row hover state. The buttons have accessible names/tooltips and do not change the row's fixed paper-plane position.
- Favorite star uses an outline icon when `IsFavorite` is false and a filled `Favorite` icon when true. The control is not recreated or repositioned during refresh.
- The separator's full-height pointer surface is transparent except for its central grip. Its hover and drag state strengthen the accent without changing column widths until the pointer moves.
- Settings always include: `Changes are applied only after Save.` When the saved UI-language value differs from the value that opened the dialog, the follow-up message is: `Settings saved. Restart PaperPulse to apply the interface language.`
- Dialog width is responsive to the documented minimum window. Feed editing preserves its approximately 720 x 700 working area; settings preserve a narrower approximately 620 px working area. Text wraps inside content sections; buttons retain stable height and do not overflow.

## Non-goals

- No changes to iOS, macOS, Swift PaperCore, SQLite schema, retrieval ranking, PDF validation, automatic download-before-save behavior, LLM behavior, or PasswordVault security boundary.
- No custom top-level windows, custom modal input routing, browser automation, or system-theme support.
- No new full interpretation UI or provider configuration; those remain Phase 4 work.

## Validation

- Static: XML/resource-key completeness and `git diff --check` on Mac.
- CI: GitHub Windows workflow builds, tests, and packages the exact commit.
- Windows manual gate after CI: F5 at normal and maximized sizes; full-height splitter drag; favorite outline-to-filled transition; hover and keyboard access to feed edit/delete; settings save/restart message; English/Chinese label wrapping; Feed Editor and Settings visual review.
