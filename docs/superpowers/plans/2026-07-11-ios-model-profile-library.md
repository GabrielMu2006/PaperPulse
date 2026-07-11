# iOS Model Profile Library Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the confusing iOS provider settings form with a named, file-backed model profile library.

**Architecture:** Add a platform-neutral `LLMProfileFileStore` to `PaperCore`. Each profile is encoded as a separate JSON file named from its model, while the API key remains in the iOS Keychain under the profile UUID. The iOS store migrates its existing UserDefaults array once, then the settings UI selects, creates, edits, saves, and deletes profiles through the app model.

**Tech Stack:** Swift 6, SwiftPM XCTest, SwiftUI, Foundation file APIs, Keychain.

## Global Constraints

- iOS 17 minimum; do not alter macOS behavior.
- Profile file payloads exclude API keys.
- API key deletion must occur together with profile deletion.
- No network request is part of profile-library tests.

---

### Task 1: Add the core profile file store

**Files:**
- Create: `Sources/PaperCore/LLMProfileFileStore.swift`
- Create: `Tests/PaperCoreTests/LLMProfileFileStoreTests.swift`

**Interfaces:**
- Produces `LLMProfileFileStore.loadProfiles()`, `save(_:)`, and `delete(_:)`.
- File names use a sanitized model name and profile UUID to prevent collisions.

- [ ] Write a failing XCTest that saves two configurations, reloads them in deterministic order, and confirms that JSON does not contain either API key.
- [ ] Run `swift test --filter LLMProfileFileStoreTests`; expect compilation failure because `LLMProfileFileStore` does not exist.
- [ ] Implement one-file-per-profile JSON storage using `LLMProfile.persistedConfiguration`, atomic writes, and safe relative filenames.
- [ ] Add a failing delete test, then implement deletion and verify it passes.
- [ ] Run the full Core test suite and commit `feat: store named model profile files`.

### Task 2: Migrate iOS settings storage and app model

**Files:**
- Modify: `Apps/PaperPulseiOS/Sources/PaperPulseiOS/LLMProfileSettingsStore.swift`
- Modify: `Apps/PaperPulseiOS/Sources/PaperPulseiOS/PaperPulseAppModel.swift`

**Interfaces:**
- `loadProfiles` reads the file store and migrates existing UserDefaults profiles only when no profile files exist.
- `saveProfiles` writes one JSON file per profile and saves matching API keys in Keychain.
- `deleteProfile(_:)` removes its JSON file and Keychain account; the app model selects a remaining profile or adds a default one.

- [ ] Replace the configuration-array persistence with the profile file store while retaining one-time migration support.
- [ ] Make the display name equal the nonempty model name when saving; use the provider label only until a model is entered.
- [ ] Add app-model deletion handling and preserve selection by UUID.
- [ ] Build the iOS target; expect `BUILD SUCCEEDED`.

### Task 3: Reshape the iOS settings interface

**Files:**
- Modify: `Apps/PaperPulseiOS/Sources/PaperPulseiOS/SettingsView.swift`

**Interfaces:**
- Profile library card: current profile menu, New, Delete.
- Current profile editor card: provider, API style, base URL, model, API key, Save, Test API.
- Preferences card: UI language and summary language.

- [ ] Remove the duplicate provider/profile controls from the existing card.
- [ ] Add destructive deletion confirmation and disable deletion for the last profile.
- [ ] Rebuild, install, and launch the iOS app in the existing simulator.
- [ ] Validate create, save, select, delete, and API-test entry visually; commit `feat: simplify iOS model profile settings`.
