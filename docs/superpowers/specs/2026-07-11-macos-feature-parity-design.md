# macOS Feature Parity Design

## Goal

Bring the verified iOS PaperPulse workflow to a standalone macOS app without synchronizing feeds, papers, PDFs, profiles, or API keys between platforms.

## Architecture

`PaperCore` remains the only shared processing layer. The macOS target gets its own SwiftData schema, document directory, UserDefaults keys, file-backed profile store, and macOS Keychain service. It reads and writes only `com.gabrielmu.PaperPulse.macOS` state.

The desktop app uses a native three-pane `NavigationSplitView`: feed/library navigation in the sidebar, paper detail in the center, and the downloaded PDF in an inspector pane. Settings remains a dedicated Settings scene. A full interpretation opens in its own desktop window/sheet rather than being appended to the short summary.

## Included iOS Capabilities

- Multiple named LLM profiles with independent Keychain keys, editable Base URL, model, API style, and deletion.
- Feed creation, editing, deletion, source selection, authority policy, provider role assignment, and bilingual UI.
- Independent SwiftData persistence for feeds, papers, short/full summaries, metadata, local PDF paths, favorites, and read state.
- arXiv, OpenAlex, and Crossref discovery, deterministic ranking, open-access PDF download, local PDFKit reading, and readable partial-source failures.
- Searchable library with favorite/unread filters; short summaries in detail; a separate full-reading surface with page anchors, progress, retry, and regeneration.
- Desktop commands and toolbar actions for refresh, settings, PDF export/share, and full-reading generation.

## Deliberate Scope Limits

- No iCloud, network, or file synchronization with iOS.
- No real macOS API key is requested or used until mock tests, local persistence, and desktop UI tests have passed. The first real API action is an explicit health check only.
- iOS-only BackgroundTasks and local notifications are not ported. A separate macOS scheduling pass can add LaunchAgent support after feature parity.

## Acceptance Criteria

- A fresh macOS installation can create a feed, run the fixture pipeline, persist papers/PDF metadata, restart, and browse its local library.
- The library supports search, favorite/unread filters, short summary, PDF reading, and a separate full-reading surface.
- Switching UI language updates desktop labels; summary language remains independent.
- Profiles are files plus Keychain secrets local to macOS; deleting a profile removes only its macOS key.
- Core mock tests, macOS tests, and a Debug build pass before any real API configuration is requested.
