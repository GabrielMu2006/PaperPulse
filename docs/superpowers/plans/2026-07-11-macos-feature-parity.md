# macOS Feature Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make PaperPulse for macOS independently provide the iOS paper-discovery, library, PDF, LLM-profile, and full-reading workflow.

**Architecture:** Keep all network, ranking, download, extraction, and LLM logic in `PaperCore`. Give macOS independent SwiftData, Keychain, profile files, and a desktop-native split-view shell.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, PDFKit, Security, PaperCore, XCTest, XcodeGen.

## Global Constraints

- Minimum macOS is 14.0; use native SwiftUI and SwiftData only.
- macOS storage and Keychain are independent from iOS; no synchronization.
- Default UI and summary language are Chinese; all user-facing desktop text supports English.
- Do not make a real API request until the user is explicitly notified and opts in.
- Every behavioral change follows a failing-test, passing-test cycle and ends in a local commit.

---

### Task 1: Independent macOS data and profile foundations

**Files:**
- Create: `Apps/PaperPulseMac/Sources/PaperPulseMac/MacSwiftDataModels.swift`
- Create: `Apps/PaperPulseMac/Sources/PaperPulseMac/MacPersistenceStore.swift`
- Modify: `Apps/PaperPulseMac/Sources/PaperPulseMac/MacLLMProfileSettingsStore.swift`
- Modify: `Apps/PaperPulseMac/Sources/PaperPulseMac/PaperPulseMacApp.swift`
- Test: `Apps/PaperPulseMac/Tests/PaperPulseMacTests/PersistenceTests.swift`
- Modify: `project.yml`

- [ ] Add an in-memory SwiftData test proving feed, paper, short summary, full summary, favorite, and read state round-trip.
- [ ] Run the test and observe it fail because macOS entities/store do not exist.
- [ ] Add macOS entities mirroring iOS persisted fields and a platform-local persistence store.
- [ ] Make `PaperPulseMacApp` own a macOS-only `ModelContainer` and inject it into the root scene.
- [ ] Run the macOS persistence test and verify it passes.
- [ ] Commit `feat: persist macos paper library`.

### Task 2: Multiple macOS LLM profiles and feed model

**Files:**
- Modify: `Apps/PaperPulseMac/Sources/PaperPulseMac/MacLLMProfileSettingsStore.swift`
- Modify: `Apps/PaperPulseMac/Sources/PaperPulseMac/PaperPulseMacModel.swift`
- Modify: `Apps/PaperPulseMac/Sources/PaperPulseMac/MacSettingsView.swift`
- Create: `Apps/PaperPulseMac/Tests/PaperPulseMacTests/ProfileStoreTests.swift`

- [ ] Add a failing test proving profiles save as separate configuration files without API keys and deletion removes only the matching macOS Keychain item.
- [ ] Implement multi-profile load/save/delete and selected-profile restoration using `com.gabrielmu.PaperPulse.macOS` keys.
- [ ] Extend the model with independent feeds, active-feed selection, provider role lookup, localized health-check status, and no-key local-summary fallback.
- [ ] Replace the single-profile settings controls with named profile selection, add/delete/edit, Base URL/model/API-style controls, and role assignment.
- [ ] Run macOS profile tests and commit `feat: add macos model profile library`.

### Task 3: Feed management and desktop library

**Files:**
- Create: `Apps/PaperPulseMac/Sources/PaperPulseMac/MacFeedEditorView.swift`
- Create: `Apps/PaperPulseMac/Sources/PaperPulseMac/MacLibraryView.swift`
- Create: `Apps/PaperPulseMac/Sources/PaperPulseMac/MacPaperDetailView.swift`
- Modify: `Apps/PaperPulseMac/Sources/PaperPulseMac/PaperPulseMacModel.swift`
- Modify: `Apps/PaperPulseMac/Sources/PaperPulseMac/MacRootView.swift`
- Test: `Apps/PaperPulseMac/Tests/PaperPulseMacTests/LibraryStateTests.swift`

- [ ] Add failing library-state tests for title search plus favorite/unread filters.
- [ ] Implement feed create/edit/delete and persist user selection locally.
- [ ] Replace the prototype paper list with a sidebar that exposes feeds, Today, and a searchable library with native selection.
- [ ] Add center-detail favorite/read actions, metadata, short summary, source link, and PDF availability state.
- [ ] Run tests and commit `feat: add macos feeds and paper library`.

### Task 4: Full reading and PDF workspace

**Files:**
- Create: `Apps/PaperPulseMac/Sources/PaperPulseMac/MacFullInterpretationView.swift`
- Modify: `Apps/PaperPulseMac/Sources/PaperPulseMac/PaperPulseMacModel.swift`
- Modify: `Apps/PaperPulseMac/Sources/PaperPulseMac/MacPaperDetailView.swift`
- Test: `Apps/PaperPulseMac/Tests/PaperPulseMacTests/FullInterpretationStateTests.swift`

- [ ] Add a failing test for full-summary persistence by paper ID and an error state isolated to that paper.
- [ ] Implement PDFKit extraction, `PaperSummaryService.generateFullSummary`, save/reopen/regenerate full readings, and localized HTTP failure text.
- [ ] Present full reading in a dedicated desktop sheet/window with section cards, page anchors, model metadata, progress, and retry.
- [ ] Keep the PDF inspector independent from the full-reading window; add Finder export/share for local PDFs.
- [ ] Run tests and commit `feat: add macos full paper reading`.

### Task 5: Desktop finish and API gate

**Files:**
- Modify: `Apps/PaperPulseMac/Sources/PaperPulseMac/PaperPulseMacApp.swift`
- Modify: `Apps/PaperPulseMac/Sources/PaperPulseMac/MacRootView.swift`
- Modify: `Apps/PaperPulseMac/Sources/PaperPulseMac/MacSettingsView.swift`
- Modify: `project.yml`

- [ ] Add a failing UI/state test for Chinese/English labels and a refresh command path.
- [ ] Add app commands, toolbar refresh, Settings menu access, keyboard shortcuts, and localized empty/error states.
- [ ] Run all core and macOS tests, then Debug/Release macOS builds.
- [ ] Stop and ask the user for the macOS API profile only after all mock and build checks pass; do not call a provider before consent.
- [ ] After the user supplies a profile, run one health check and one manually chosen paper summary, then commit `test: verify macos provider integration`.
