# PaperPulse macOS Deep Brand Shell Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rework PaperPulse macOS into a fixed dark, high-brand research workspace and wire the provided PaperPulse icon into the macOS app.

**Architecture:** Keep all business logic and persistence contracts unchanged. Add reusable macOS-only SwiftUI shell primitives in the existing macOS UI files, apply them to the main window, full reading, feed editor, and settings, then add macOS-only app icon resources via XcodeGen.

**Tech Stack:** SwiftUI, PDFKit bridge, SwiftData, XcodeGen, XCTest, macOS Xcode build.

## Global Constraints

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
- PaperPulse macOS uses a fixed dark shell and does not follow system light mode.

---

### Task 1: Deep Brand Shell Primitives

**Files:**
- Modify: `Apps/PaperPulseMac/Sources/PaperPulseMac/MacLibraryView.swift`
- Modify: `Apps/PaperPulseMac/Sources/PaperPulseMac/MacRootView.swift`
- Test: `Apps/PaperPulseMac/Tests/PaperPulseMacTests/LibraryFilterTests.swift`

**Interfaces:**
- Consumes: existing `MacBrand`, `MacSurfaceCard`, `MacWorkbenchBackground`.
- Produces: fixed dark shell primitives: deep background, light paper panel, dark glass panel, gradient primary button style, localized empty-state styling.

- [ ] Add a small test for `MacLibraryFilter.visible` if behavior helpers are touched.
- [ ] Replace muted system materials with explicit dark-shell and light-paper surfaces.
- [ ] Apply `.preferredColorScheme(.dark)` to the macOS root and modal surfaces.
- [ ] Run `PaperPulseMacTests`.

### Task 2: Main Window and Full Reading Strong Restyle

**Files:**
- Modify: `Apps/PaperPulseMac/Sources/PaperPulseMac/MacRootView.swift`
- Modify: `Apps/PaperPulseMac/Sources/PaperPulseMac/MacLibraryView.swift`
- Modify: `Apps/PaperPulseMac/Sources/PaperPulseMac/MacFullInterpretationView.swift`

**Interfaces:**
- Consumes: Task 1 shell primitives.
- Produces: custom dark sidebar, full-window gradient background, light paper detail cards, dark PDF empty state, full-reading cards over dark shell.

- [ ] Replace native sidebar visual feel with a dark glass sidebar while preserving List selection and feed expansion behavior.
- [ ] Restyle feed rows, library groups, and paper rows for dark contrast.
- [ ] Restyle detail and full-reading panels as light paper surfaces over the dark shell.
- [ ] Run `PaperPulseMacTests`.

### Task 3: Feed Editor and Settings Strong Restyle

**Files:**
- Modify: `Apps/PaperPulseMac/Sources/PaperPulseMac/MacFeedEditorView.swift`
- Modify: `Apps/PaperPulseMac/Sources/PaperPulseMac/MacSettingsView.swift`

**Interfaces:**
- Consumes: Task 1 shell primitives and existing `MacFeedEditorDraft` / `PaperPulseMacModel` bindings.
- Produces: feed editor and settings windows that match the fixed dark PaperPulse shell.

- [ ] Wrap feed editor sheet in dark shell and use light panels for each section.
- [ ] Preserve fixed footer and existing save/cancel behavior.
- [ ] Wrap settings in dark shell and use clear panels for language, keyword library, model profiles, status, and storage.
- [ ] Preserve Keychain/profile/language/storage semantics.
- [ ] Run `PaperPulseMacTests`.

### Task 4: macOS App Icon Resource

**Files:**
- Create: `Apps/PaperPulseMac/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`
- Create: `Apps/PaperPulseMac/Resources/Assets.xcassets/AppIcon.appiconset/*.png`
- Modify: `project.yml`
- Regenerate: `PaperPulse.xcodeproj`

**Interfaces:**
- Consumes: `/Users/gabrielmu/Downloads/PaperPulse.png`.
- Produces: macOS-only AppIcon asset set wired by `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon`.

- [ ] Generate transparent-background icon PNGs from the provided image by removing the outside white border/ring.
- [ ] Add `Assets.xcassets/AppIcon.appiconset/Contents.json` with macOS icon idioms.
- [ ] Set `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon` only for `PaperPulseMac` in `project.yml`.
- [ ] Run `scripts/generate_project.sh`.
- [ ] Run `PaperPulseMacTests`.
- [ ] Run macOS Release build.
- [ ] Commit locally with `git commit -m "style: apply macos deep brand shell"`.
