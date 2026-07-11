# PaperPulse macOS A+B UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refine PaperPulse macOS into a native research workbench with restrained red-purple pulse branding.

**Architecture:** Keep the existing `NavigationSplitView`, SwiftData entities, PaperCore flows, Keychain storage, and iOS app untouched. Apply visual changes inside existing macOS SwiftUI files so the checked-in Xcode project continues to build without project regeneration.

**Tech Stack:** SwiftUI, AppKit/PDFKit bridge, SwiftData, XCTest, Xcode `PaperPulseMacTests` and `PaperPulseMac` schemes.

## Global Constraints

- Only adjust macOS presentation and interaction details.
- Do not modify iOS, PaperCore retrieval/download/LLM flows, SwiftData data structures, or Keychain storage without explicit approval.
- Keep per-feed manual paper-plane pushes.
- Keep shared local paper/PDF storage across multiple feed links.
- Keep library groups by feed plus collapsible unclassified group.
- Selecting a feed expands that feed and collapses other groups plus unclassified.
- Keep favorites only; do not restore read/unread categories.
- Empty institutions and venues mean any, while authority filtering remains active.
- Full reading generation stays asynchronous; completed full reading opens side-by-side with PDF at default 1:1 and preserves user-adjusted split ratio.
- Deleting a full reading must require confirmation and delete only the current paper's full reading.
- App language and summary language remain independent.
- Do not push to GitHub. Each completed stage creates only a local commit.

---

### Task 1: Main Workbench Visual Foundation

**Files:**
- Modify: `Apps/PaperPulseMac/Sources/PaperPulseMac/MacLibraryView.swift`
- Modify: `Apps/PaperPulseMac/Sources/PaperPulseMac/MacRootView.swift`
- Modify: `Apps/PaperPulseMac/Sources/PaperPulseMac/MacFullInterpretationView.swift`
- Test: `Apps/PaperPulseMac/Tests/PaperPulseMacTests/LibraryFilterTests.swift`

**Interfaces:**
- Consumes: `MacLibraryScope`, `MacLibraryFilter.visible`, `MacFeedRow`, `MacLibraryRow`, `PaperDetailView`, `MacInterpretationPane`.
- Produces: Branded macOS workbench visual primitives contained in existing macOS view files; localized empty states and action labels.

- [ ] Step 1: Add failing XCTest coverage for macOS library UI contract strings and search trimming.
- [ ] Step 2: Run `PaperPulseMacTests` and verify the new tests fail before implementation.
- [ ] Step 3: Implement minimal UI-support behavior needed by the tests.
- [ ] Step 4: Apply A+B visual treatment to sidebar rows, paper rows, detail surfaces, PDF empty state, and full-reading sections.
- [ ] Step 5: Run `PaperPulseMacTests`.
- [ ] Step 6: Run Release build for `PaperPulseMac`.
- [ ] Step 7: Commit locally with `git commit -m "style: refine macos research workbench"`.

### Task 2: Feed Editor and Settings Surfaces

**Files:**
- Modify: `Apps/PaperPulseMac/Sources/PaperPulseMac/MacFeedEditorView.swift`
- Modify: `Apps/PaperPulseMac/Sources/PaperPulseMac/MacSettingsView.swift`
- Test: `Apps/PaperPulseMac/Tests/PaperPulseMacTests/LibraryFilterTests.swift` or a new macOS test file if behavior helpers are introduced.

**Interfaces:**
- Consumes: existing `MacFeedEditorDraft`, `PaperPulseMacModel` settings actions, `LLMProfile` bindings.
- Produces: Branded but native configuration surfaces with clearer sections and preserved semantics for institutions, venues, language, profiles, and storage cleanup.

- [ ] Step 1: Write failing tests only if extracting behavior helpers.
- [ ] Step 2: Rework editor sections into compact research-filter groups with clear helper copy.
- [ ] Step 3: Rework settings into native grouped/tabs or sectioned layout with model profile hierarchy clarified.
- [ ] Step 4: Run `PaperPulseMacTests`.
- [ ] Step 5: Run Release build for `PaperPulseMac`.
- [ ] Step 6: Commit locally with `git commit -m "style: refine macos configuration surfaces"`.

### Task 3: App Icon Asset Cleanup

**Files:**
- Modify or create macOS resource asset files after confirming the current app icon asset path.
- Do not modify iOS assets unless explicitly approved.

**Interfaces:**
- Consumes: `/Users/gabrielmu/Downloads/PaperPulse.png`.
- Produces: macOS icon artwork without the outside white ring, wired only to the macOS target if asset wiring is needed.

- [ ] Step 1: Inspect current macOS app icon/resource wiring.
- [ ] Step 2: Produce a transparent-background macOS icon variant from the provided artwork.
- [ ] Step 3: Wire it to the macOS target only if the current project has an icon asset path.
- [ ] Step 4: Run `PaperPulseMacTests`.
- [ ] Step 5: Run Release build for `PaperPulseMac`.
- [ ] Step 6: Commit locally with `git commit -m "style: add macos app icon artwork"`.
