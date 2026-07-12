# Project Folder Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove retired arXiv automation and generated artifacts while preserving a buildable PaperPulse source tree.

**Architecture:** Keep `Apps/`, `Sources/PaperCore/`, `Tests/`, root build configuration, and reusable commands in `scripts/`. Place durable setup material under `docs/development/`, macOS handoff material under `docs/macos/`, and retain `docs/superpowers/` as engineering history.

**Tech Stack:** SwiftPM, Xcode, XcodeGen, XCTest, Git.

## Global Constraints

- Do not change app behavior, PaperCore, SwiftData, or Keychain storage.
- Preserve `Package.swift`, `project.yml`, `PaperPulse.xcodeproj`, `scripts/generate_project.sh`, and `.tools/xcodegen-2.45.4`.
- Delete only `automation/`, `arxiv_morning_brief/`, `logs/`, `tmp/`, and `.build/`.
- Do not push to GitHub; make one local commit after verification.

### Task 1: Verify the preserved build inputs

**Files:** `Package.swift`, `project.yml`, `PaperPulse.xcodeproj`

- [ ] Run the macOS test target before cleanup.
- [ ] Require `** TEST SUCCEEDED **` before deleting generated output.

### Task 2: Remove retired material

**Files:** Delete `automation/`, `arxiv_morning_brief/`, `logs/`, `tmp/`, `.build/`

- [ ] Delete only the approved directories.
- [ ] Assert the five paths are absent and all preserved build inputs exist.

### Task 3: Organize durable documentation

**Files:**
- Move `docs/setup.md` to `docs/development/setup.md`
- Move `docs/macos-ui-handoff.md` to `docs/macos/ui-handoff.md`
- Modify `.gitignore`

- [ ] Create the two subject directories and use `git mv` for both documents.
- [ ] Remove the obsolete historical `automation/` statement from the current macOS handoff.
- [ ] Remove `arxiv_morning_brief/` from `.gitignore`; retain ignores for `.build/`, `.tools/`, `logs/`, and `tmp/`.

### Task 4: Prove a clean checkout builds

**Files:** `scripts/generate_project.sh`, `PaperPulse.xcodeproj`

- [ ] Regenerate the Xcode project with `./scripts/generate_project.sh`.
- [ ] Run macOS tests from fresh DerivedData and require `** TEST SUCCEEDED **`.
- [ ] Build `PaperPulseMac` in Release and require `** BUILD SUCCEEDED **`.

### Task 5: Review and commit

- [ ] Check `git diff --check`, verify only approved changes exist, then commit `chore: organize project structure` locally.
