# PaperPulse Windows Control System Design

## Purpose

Make the Windows client visually distinctive and maintainable by replacing the remaining PaperPulse-facing default WinUI controls with reusable PaperPulse control templates. This revision also fixes the full-height reading-workspace splitter and makes feed actions a selection-state affordance.

The design follows the PaperPulse visual specification: a dark research workspace, restrained glass surfaces, red-magenta-purple emphasis for active or primary states, and warm gold only for favorites. It is a WinUI 3 implementation of the product language, not a pixel copy of macOS.

## Scope and Constraints

This work is limited to `Apps/PaperPulseWindows/src/PaperPulse.Windows` presentation and theme files.

- Keep the existing retrieval, download, local-PDF, LLM, persistence, and credential behavior unchanged.
- Do not modify iOS, macOS, Swift PaperCore, SwiftData schema, or Keychain/PasswordVault boundaries.
- Preserve ContentDialog modal behavior, keyboard navigation, focus trapping, escape handling, and accessible control names.
- Preserve the already accepted behavior: English keyword-library copy in both UI languages, immediate filled favorite star, and language-save/restart acknowledgement.

## Chosen Approach

PaperPulse will own explicit WinUI templates instead of relying on setters that leave default control chrome visible. The reusable style layer is the only place that defines visual surfaces and interaction state; dialogs and views consume those styles rather than constructing ad-hoc variants.

The alternative of only overriding colours is rejected because it leaves system geometry and focus surfaces visible. The alternative of a separate custom windowing/modal system is rejected because ContentDialog provides required accessibility and lifecycle behavior.

## Reusable Control Layer

`Themes/PaperPulseControls.xaml` becomes the source of truth for these components:

| Component | Visual contract |
| --- | --- |
| Quiet, icon, prominent, destructive buttons | Glass surface or deliberate accent surface; stable dimensions; hover, pressed, disabled, and keyboard-focus states. |
| TextBox and PasswordBox | Custom dark translucent input well, 8 px corner radius, 1 px glass boundary, muted placeholder, readable selection, and a thin magenta-to-purple focus treatment. Multi-line input preserves scrolling and text selection. |
| ComboBox and NumberBox | Same input-well geometry and focus language as TextBox. Popup and spin actions remain legible and keyboard accessible. |
| ToggleButton and CheckBox | Quiet glass base, distinct selected/checked state, and visible keyboard focus without imitating default Windows chrome. |
| ContentDialog and form sections | Midnight modal container, fixed footer semantics, left-aligned branded header, grouped dark-glass form surfaces, and no nested decorative cards. |

Templates retain the required WinUI content presenters, editable text host, focus behavior, and disabled state. They do not change command bindings, validation, or stored values. Template state names will be unique per template so XAML compilation does not repeat the prior duplicate-state failure.

## Dialog Layout

Feed Editor and Settings use a shared header composition:

```text
[38 x 38 accent icon]  Title
                        Supporting sentence
```

The icon is immediately left of the title block, vertically centered with it, and never placed as a separate right-side ornament. Content remains scrollable; action buttons remain in the ContentDialog footer. Feed Editor keeps its practical approximately 720 px working width and Settings its approximately 620 px width, subject to the application's 900 x 600 minimum window.

All existing TextBox, ComboBox, NumberBox, PasswordBox, CheckBox, and action controls in these dialogs consume the new shared styles. Inputs must visually read as PaperPulse controls, not as gray native rectangles embedded in a custom modal.

### Post-CI Dialog Refinement

The modal frame may remain centered while its content still reads as left-weighted. Feed Editor and Settings therefore use a fixed-width content column with `HorizontalAlignment="Center"`; their header, form sections, and footer actions share this visual axis. The scroll rail stays at the dialog edge and must not define the content alignment.

`ComboBox` receives a full PaperPulse template built from the WinUI named-part contract. Its popup is a dark glass surface aligned to the input width, with a 1 px glass stroke, restrained shadow, compact option rows, low-contrast hover, and a blue selection rail. It keeps the standard popup, keyboard navigation, focus, and `ComboBoxItem` selection semantics. Styling only ComboBoxItem rows is insufficient because it leaves the system popup chrome visible.

The academic-source checkboxes use an explicit two-column template: a fixed 20 px indicator column followed by a content column. The source group uses a wrapping layout, so arXiv, OpenAlex, and Crossref cannot overlap or compress into one another at any supported dialog width.

## Sidebar Text Constraints

Each paper-row metadata line has two explicit columns: a shrinkable author column and an auto-sized date column. The author field is limited to one ellipsized line within the remaining width; the date may never overlay it. Title and brief keep their existing two-line limits. This is presentation-only and does not alter paper metadata or grouping.

## Workspace Splitter

The reading workspace keeps an 8 px divider column and a centered 2 px x 48 px visual grip. A dedicated transparent drag surface fills the entire divider column from the workspace top to bottom; it owns pointer capture and resize calculations. The grip is only a visual affordance.

Consequences:

- Pressing anywhere along the divider column begins a resize.
- Moving or releasing after capture continues to work even after the pointer leaves the column.
- Normal and maximized windows behave identically, aside from the larger available height.
- The persisted 0.25 through 0.75 split ratio contract remains unchanged.

## Feed Selection Actions

The feed list's existing `SelectedItem` is the sole source of visibility for per-row edit and delete actions.

- Exactly the selected feed row exposes compact edit and delete icon buttons.
- Switching selection hides the previous row's actions immediately.
- Pointer hover does not reveal actions and is not required to operate them.
- The row's paper-plane push action stays permanently visible in its current stable slot.
- Delete remains confirmed by the existing destructive confirmation flow.

No feed model fields, selection rules, push behavior, or context persistence change.

## Failure and Accessibility Behavior

- Keyboard focus remains visible on every interactive control.
- Edit, delete, push, and dialog actions retain automation names and tooltips.
- Disabled states remain distinguishable without relying solely on color.
- Existing validation text remains authoritative; visual templates do not suppress it.
- Text and input content wraps or scrolls rather than altering fixed button and toolbar dimensions.

## Validation

Mac validation is limited to `git diff --check`, XAML/resource consistency checks, and focused source-level verification because this machine cannot build WinUI.

GitHub Windows CI must build, test, package, and upload the unsigned MSIX for the exact implementation commit. After CI is green, Windows manual verification covers:

1. Drag the detail/PDF divider from its upper, middle, and lower thirds in normal and maximized windows.
2. Select each feed with mouse and keyboard; only the selected row shows edit and delete, while every row retains its paper-plane action.
3. Open New Subscription, Edit Subscription, and Settings; verify the icon-title header, form column, and footer share a centered axis; every text, choice, numeric, secure, and checkbox control follows the PaperPulse control system.
4. Open each language ComboBox and verify its popup is PaperPulse dark glass, not system gray. Verify source checkboxes remain separately readable and paper-row author/date text never overlaps.
5. Verify text entry, selection, focus traversal, Save, Cancel, validation, and destructive confirmation still operate normally.
6. Reconfirm favorite fill, English keyword library, and language save/restart acknowledgement.

## Non-goals

- No new product features, provider settings, business rules, data migrations, or changes to automatic download-before-save behavior.
- No system-light-theme support.
- No top-level custom window or custom modal framework.
