# PaperPulse macOS Deep Brand Shell Design

## Goal

Make PaperPulse macOS feel like the provided app icon: a fixed dark academic technology workspace with high-saturation red, magenta, purple, and deep-blue gradients. The whole window should feel redesigned, not lightly tinted.

## Non-Negotiable Scope

- macOS UI only.
- Do not modify iOS.
- Do not modify PaperCore retrieval, download, ranking, PDF extraction, or LLM flows.
- Do not modify SwiftData schema or Keychain storage.
- Keep manual per-feed paper-plane pushes.
- Keep one local paper/PDF entity shared across multiple feed links.
- Keep library grouped by feed plus unclassified, all collapsible.
- Selecting a feed expands that feed and collapses other groups plus unclassified.
- Keep favorites only; do not restore read/unread UI.
- Empty institutions and venues mean any, while authority filtering remains active.
- Full reading remains asynchronous; when opened, it shares the view with the PDF and preserves the user-adjusted split ratio.
- Deleting a full reading requires confirmation and deletes only the current paper's reading.
- App language and summary language stay independent.
- Do not push to GitHub; only local commits.

## Visual Direction

PaperPulse uses a fixed dark shell for macOS. It does not follow system light mode.

The main background is a layered deep-blue, purple, and red-magenta gradient. Content surfaces are light or translucent panels on top of that shell, echoing the bright open book in the icon. Primary actions use red-to-magenta gradients. Secondary actions stay readable and restrained. The result should feel like a polished scientific reading cockpit, not a default macOS sidebar with accent colors.

## Window Architecture

### Main Window

- Use a full-window dark branded background behind all panes.
- Replace the mostly native source-list look with a custom dark brand sidebar.
- Keep a stable sidebar/detail/PDF structure so the current interaction model survives.
- Avoid nested cards. Use top-level panels for sidebar sections, detail summaries, full-reading sections, settings groups, and feed-editor groups.

### Sidebar

- The sidebar uses a deep translucent panel with a PaperPulse identity header.
- Feed rows use active red-magenta treatment and keep the paper-plane push button visible per feed.
- Library groups remain collapsible and show feed/unclassified counts.
- Selected feed expansion behavior remains unchanged.
- Search and filter controls should feel integrated into the dark shell.

### Paper Detail

- The paper identity area is a bright reading panel: title, authors, metadata pills, favorite action.
- The brief summary sits in a distinct bright panel with the full-reading action.
- The source link is a smaller action panel.
- PDF empty state uses dark-shell styling and localized copy.

### Full Reading

- Full reading opens with the sidebar hidden as today.
- The reading pane uses light cards over the dark shell.
- Section headers use red/magenta accents and page anchors remain visible.
- Close and delete remain explicit; delete confirmation remains unchanged in semantics.

### Feed Editor

- The sheet uses the same dark shell.
- Sections become bright or translucent panels: feed identity, keyword matching, requirements, sources, selection.
- The “institutions/venues empty means any but authority remains active” copy stays visible and unambiguous.
- Footer stays fixed with cancel/save.

### Settings

- The Settings window uses the same dark shell.
- Language, keyword library, model configurations, status, and storage each become clear panels.
- Model profile actions remain native enough to be accessible, but visually tied to the red-magenta brand.
- Language and summary language remain separate controls.

## App Icon

- Use `/Users/gabrielmu/Downloads/PaperPulse.png` as the source.
- Remove the outside white ring/background so the icon artwork sits cleanly in macOS.
- Add a macOS AppIcon asset set and wire it to the macOS target only.
- Do not modify iOS icon assets unless separately approved.

## Implementation Notes

- Because the project uses XcodeGen, target/resource changes must be represented in `project.yml` and then `scripts/generate_project.sh` must regenerate `PaperPulse.xcodeproj`.
- UI-only Swift changes should stay under `Apps/PaperPulseMac/Sources/PaperPulseMac`.
- If new helper files are added, regenerate the Xcode project so the macOS target includes them.
- Verification for each implementation phase:
  - Run `PaperPulseMacTests`.
  - Run macOS Release build.
  - Build product should be available at `/private/tmp/PaperPulseMacReleaseDerivedData/Build/Products/Release/PaperPulse.app`.
