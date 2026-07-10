# PaperPulse V1 Task 2 Report

## Status

Completed Task 2 from starting commit `4f7c7fd` on `codex/paperpulse-v1`. No network requests were used by tests.

## TDD Evidence

### RED

Before production edits, I added fixture/fake-only adapter and discovery tests, then ran:

```sh
env XDG_CACHE_HOME=/private/tmp/PaperPulseCache CLANG_MODULE_CACHE_PATH=/private/tmp/PaperPulseClangModuleCache SWIFTPM_CONFIG_PATH=/private/tmp/PaperPulseSwiftPMConfig SWIFTPM_CACHE_PATH=/private/tmp/PaperPulseSwiftPMCache swift test --disable-sandbox --filter 'AcademicSourceTests|PaperDiscoveryServiceTests'
```

Expected failure occurred at compile time because `PaperDiscoveryService`, `PaperCandidateMerger`, and `SemanticScholarSource(apiKey:)` did not yet exist. This established the initial RED state for the new production surface.

During self-review, I added a second regression test for a DOI-bearing candidate merging with a DOI-less candidate through a shared arXiv base ID. Its focused RED command was:

```sh
env XDG_CACHE_HOME=/private/tmp/PaperPulseCache CLANG_MODULE_CACHE_PATH=/private/tmp/PaperPulseClangModuleCache SWIFTPM_CONFIG_PATH=/private/tmp/PaperPulseSwiftPMConfig SWIFTPM_CACHE_PATH=/private/tmp/PaperPulseSwiftPMCache swift test --disable-sandbox --filter PaperDiscoveryServiceTests/testMergerUsesArxivIDWhenOnlyOneRecordHasDOI
```

Expected failure: the merger returned two candidates rather than one and therefore did not retain the Semantic Scholar DOI/provenance in the arXiv candidate.

### GREEN

Focused verification after implementation:

```sh
env XDG_CACHE_HOME=/private/tmp/PaperPulseCache CLANG_MODULE_CACHE_PATH=/private/tmp/PaperPulseClangModuleCache SWIFTPM_CONFIG_PATH=/private/tmp/PaperPulseSwiftPMConfig SWIFTPM_CACHE_PATH=/private/tmp/PaperPulseSwiftPMCache swift test --disable-sandbox --filter 'AcademicSourceTests|PaperDiscoveryServiceTests'
```

Result: 10 tests passed, 0 failures.

Final full-suite verification:

```sh
env XDG_CACHE_HOME=/private/tmp/PaperPulseCache CLANG_MODULE_CACHE_PATH=/private/tmp/PaperPulseClangModuleCache SWIFTPM_CONFIG_PATH=/private/tmp/PaperPulseSwiftPMConfig SWIFTPM_CACHE_PATH=/private/tmp/PaperPulseSwiftPMCache swift test --disable-sandbox
```

Result: 37 tests passed, 0 failures. SwiftPM emitted pre-existing sandbox cache warnings for user-level directories, but the command exited successfully.

## Implementation

- Added `DiscoveryResult`, `PaperDiscoveryService`, and `PaperCandidateMerger`.
- Discovery honors `FeedConfig.enabledSources`, excludes Unpaywall from discovery, uses `lookbackDays * 86_400`, runs source searches in a task group, preserves successful results, and records per-source `PipelineFailure` values.
- Merging uses normalized DOI, then arXiv base ID, then a deterministic normalized title hash. It preserves deterministic metadata precedence, unions collections, aggregates deduplicated provenance, retains the highest citation count, and prioritizes verified OA evidence.
- arXiv, Semantic Scholar, OpenAlex, and Crossref now attach source provenance. arXiv, Semantic Scholar's explicit `openAccessPdf`, and OpenAlex OA URLs create verified OA evidence. Crossref PDF links remain ordinary candidate links without OA evidence. Unpaywall supplies verified evidence only when it returns a PDF URL.
- `SemanticScholarSource(apiKey:)` remains compatible with the prior initializer; it sends only a nonempty API key as `x-api-key` and does not expose or persist it.

## Files

- Modified: `Sources/PaperCore/AcademicSources.swift`
- Added: `Sources/PaperCore/PaperDiscoveryService.swift`
- Added: `Sources/PaperCore/PaperCandidateMerger.swift`
- Modified: `Sources/PaperCore/Models.swift`
- Modified: `Tests/PaperCoreTests/AcademicSourceTests.swift`
- Added: `Tests/PaperCoreTests/PaperDiscoveryServiceTests.swift`
- Modified: `Tests/PaperCoreTests/TestSupport.swift`
- Added: `.superpowers/sdd/task-2-report.md`

## Self-Review

- Confirmed source APIs remain callable through their original initializers.
- Confirmed no Task 1 files outside the stated ownership were edited.
- Confirmed Crossref does not accidentally claim verified OA from a PDF link.
- Confirmed merger ordering is independent of concurrent source completion order.
- Confirmed `git diff --check` reports no whitespace errors.

## Concern

`PaperSource` predates Swift 6 `Sendable` conformance. To fan out existing source implementations concurrently without breaking that public protocol, `PaperDiscoveryService` uses a private `@unchecked Sendable` wrapper. Built-in adapters use stateless value types and injected HTTP clients; custom sources supplied to this service must themselves be safe for concurrent invocation.

## Commit

Local commit: `feat: add academic discovery and metadata merge`. The canonical commit hash is reported in the task status after the final amend.
