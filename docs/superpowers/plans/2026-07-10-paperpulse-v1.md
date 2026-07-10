# PaperPulse V1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:test-driven-development for behavior changes. Work only on the assigned task, commit locally, and never push.

**Goal:** Deliver independent iOS and macOS PaperPulse apps that discover authoritative recent papers, download only verified open-access PDFs, and create evidence-anchored summaries through user-configured LLM APIs.

**Architecture:** Keep platform-neutral discovery, ranking, download validation, extraction, and summarization in `PaperCore`. Split discovery from per-paper processing, then let each app persist and resume processing jobs locally. iOS uses SwiftData, BackgroundTasks, and a background URLSession; macOS uses its own SwiftData store and scheduler helper.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, PDFKit, BackgroundTasks, URLSession, CryptoKit, Keychain, XCTest, XcodeGen.

## Global Constraints

- Minimum deployment targets remain iOS 17 and macOS 14.
- Default interface and summary language are Chinese; both support English independently.
- Default feed searches the last 7 days and selects 5 papers.
- Only verified open-access PDFs are downloaded; never bypass authentication, subscriptions, or paywalls.
- API keys remain in Keychain and must not appear in UserDefaults, logs, fixtures, commits, or test output.
- GPT, Claude, Gemini, Qwen, GLM, Kimi, DeepSeek, and custom relays support user-defined Base URLs where their configured API style permits it.
- iOS runs independently of a Mac. Background execution is best-effort; exact-time cloud scheduling is outside local V1.
- Keep `project.yml` as the Xcode project source of truth and regenerate `PaperPulse.xcodeproj` after target changes.
- Commit locally after each reviewed task; never push without explicit user authorization.

---

### Task 1: Core contracts and resilient HTTP transport

Extend feed, paper, authority, open-access, progress, provider, and summary models. Add retry-aware HTTP transport with typed failures, timeouts, cancellation, and injectable sleeping. Preserve source compatibility where practical. Add focused tests before each behavior.

### Task 2: Academic discovery, metadata merge, and open-access resolution

Complete arXiv, Semantic Scholar, OpenAlex, Crossref, and Unpaywall adapters. Query enabled sources concurrently, merge complementary records by DOI/arXiv ID/normalized title hash, preserve provenance, and never treat an unverified Crossref link as open access. Test request headers, pagination/date filters, malformed payloads, partial failure, and merge precedence.

### Task 3: Authority filtering and optional LLM reranking

Implement hard blocked-institution exclusion, deterministic authority and relevance scoring, and top `4 x N` candidate preparation. Add an OpenAI-compatible structured reranker that may reorder only supplied stable IDs and falls back to deterministic ranking on malformed output, timeout, or quota failure.

### Task 4: Secure PDF processing and evidence-preserving extraction

Stream foreground downloads to disk, enforce HTTPS, redirect and 100 MiB limits, validate MIME/signature, compute SHA-256, and reuse valid duplicates. Preserve PDFKit page text and hashes. Add an extracted-text file store and opt-in cloud extraction adapters with explicit capability checks.

### Task 5: Provider registry and high-quality summaries

Add provider health checks, role assignment, response error parsing, and structured-output repair. Generate short summaries from high-signal pages. Generate full summaries with page-based map/reduce into research question, contributions, method, experiments, results, limitations, and intended readers. Validate anchors and set identity/model/time metadata locally.

### Task 6: iOS persistence, provider profiles, and durable jobs

Expand SwiftData to retain complete feed policies, source metadata, provenance, authority results, run stages, failures, summaries, and processing jobs. Store multiple provider configurations without keys and isolate each Keychain key by profile ID. Persist relative PDF/text paths and resume unfinished jobs after relaunch.

### Task 7: iOS localization and complete product workflow

Replace partial hand-written bilingual copy with a String Catalog and dynamic locale switching. Use native scrollable lists for Feeds and Library, add feed CRUD and authority/source/schedule controls, progress in Today, library search/filter/favorite/read state, full-screen PDF reading, export/share, and short/full summary actions.

### Task 8: iOS background execution

Declare BGAppRefresh/BGProcessing identifiers and background modes. Persist scheduled downloads through a background URLSession, restore delegate events, handle expiration/cancellation/deduplication, and notify only after durable state is saved.

### Task 9: Independent macOS completion

Give macOS its own SwiftData library, feed CRUD, provider profiles, bilingual UI, full summaries, PDF reading, and a local LaunchAgent helper that invokes shared app-owned processing rather than legacy Codex automation.

### Task 10: Automated and acceptance verification

Add PaperCore integration tests, iOS unit/UI tests, macOS tests, fixture launch configuration, release builds, security checks, offline relaunch tests, 50-paper Library scrolling, provider relay contracts, and background recovery scenarios. Record real API/device tests separately so paid credentials and device-only behavior are never required by deterministic CI.
