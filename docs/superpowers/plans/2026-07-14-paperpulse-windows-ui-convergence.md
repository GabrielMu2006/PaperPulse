# PaperPulse Windows UI Convergence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Do not add artificial red/green cycles for XAML styling, resource dictionaries, documentation, scripts, or CI wiring.

**Goal:** Replace the Windows functional verification shell with the documented PaperPulse research workspace, make each manual feed push download at most 10 verified PDFs before saving papers, and complete the remaining Phase 3/4 work while preserving all existing product and security contracts.

**Architecture:** Keep `PaperPulse.Contracts`, `PaperPulse.Engine`, `PaperPulse.Storage`, and `PaperPulse.Pdf` portable and independent of WinUI. A feed paper-plane action discovers and ranks metadata, selects no more than 10 papers, downloads and validates each verified PDF, writes it locally, and only then persists the paper/feed relationship; a failed paper does not become a new brief-only library row. Recompose the Windows UI as one 300-420 px navigation/library sidebar plus a remaining workspace split 1:1 between paper information and the local PDF. Source adapters may be corrected only to carry the same verified-open-access evidence already required by Swift PaperCore; the HTTPS, evidence, MIME, signature, size, hashing, storage, and no-paywall rules remain unchanged.

**Tech Stack:** C# 14, .NET 10.0.301, WinUI 3, Windows App SDK, CommunityToolkit.Mvvm, SQLite, WebView2, xUnit, GitHub Actions, single-project MSIX.

## Status And Evidence

- Active branch: `codex/paperpulse-windows-migration`.
- The existing Mac-first build/CI/runtime-gate plan remains authoritative for cross-device ownership and validation.
- `MainWindow.xaml` is still a verification shell with fixed columns `250 / * / 360`; this directly causes the maximized layout shown in screenshot 1050.
- Screenshot 1049 shows DOI-shaped source IDs. With the current adapters this is most likely a Crossref-only result set. Crossref metadata links are intentionally not treated as verified open-access evidence, so these rows must not promise a working PDF download.
- Screenshot 1050 proves WebView2 can render at least one local PDF, while another attempted download ended with HTTP 403. A 403 is a source-host refusal, not evidence that PDF rendering is broken.
- The current Windows push path saves every discovered candidate immediately; this is why the screenshot can show a group count of 80 even though the feed limit is much lower. It also exposes a separate download button for every selected paper. Both behaviors differ from the required download-before-save pipeline.

## Global Constraints

- Read and follow `docs/macos/ui-design-specification.md`, `docs/macos/ui-handoff.md`, and `docs/development/windows-migration-handoff.md` before every implementation batch.
- Do not modify `Apps/PaperPulseiOS`, `Apps/PaperPulseMac`, `Sources/PaperCore`, SwiftData schemas, or Apple Keychain behavior.
- Do not change PasswordVault's security boundary or store API keys in SQLite, settings, logs, fixtures, reports, or CI artifacts.
- Do not loosen verified-open-access requirements, HTTPS enforcement, redirect checks, MIME validation, PDF signature validation, 100 MiB limit, SHA-256 behavior, or one-PDF-per-paper storage.
- Never treat a Crossref `link` as verified open access by itself. A DOI paper becomes downloadable only when an existing trusted source supplies verified direct-PDF evidence.
- Do not add paywall bypasses, cookies copied from a browser, embedded login automation, or host-specific scraping.
- A 401/403 response remains a failed download. The UI may offer a feed-level retry and an available source-page action, but it must not pretend the PDF is local or restore the old normal per-paper download workflow.
- One manual feed push may download/process/save at most 10 papers. `AuthorityPolicy.DailyLimit` remains configurable but its effective Windows V0.1 processing limit is clamped to `1...10`.
- Metadata search may inspect additional lightweight candidates for ranking, but tests and runtime gates must never download, extract, summarize, or save more than 10 papers in one batch.
- A newly discovered paper is persisted only after its verified PDF has been downloaded, validated, and written locally. Generated short summaries occur after local PDF processing, never before download.
- One failed candidate does not abort the remaining batch. It is reported in the feed-run result and is not inserted as a new metadata-only paper.
- An already stored paper with a valid local PDF may be linked to another feed without downloading a duplicate. A legacy linked row whose PDF is missing is eligible for retry on the next push instead of being permanently skipped.
- Preserve manual per-feed push, multi-feed paper membership, group expansion behavior, favorites-only classification, nonblocking full interpretation, 1:1 interpretation/PDF split, and independent UI/summary languages.
- Use terminal and local files. Do not use Codex Browser or Computer Use.
- Do not touch the unrelated untracked `arxiv_morning_brief/` directory.
- No implementation push occurs until the user approves this plan. During execution, push only focused commits to the migration branch so GitHub Windows validation can evaluate the exact SHA.

## Test Policy

- Use one focused failing test first only when changing portable behavior: source JSON mapping, open-access evidence, the 10-paper batch cap, download-before-save orchestration, split-ratio clamping, or state mapping.
- Do not manufacture failing tests for XAML colors, spacing, resource keys, file presence, workflow YAML, or documentation.
- Run `./scripts/validate-core.sh Debug` after portable C# changes.
- Run `git diff --check` after every task.
- Let GitHub Actions prove WinUI build, Windows tests, and MSIX packaging after each approved push.
- Use the physical Windows 11 machine only at the Phase 3 visual interaction gate and Phase 4 WebView2/runtime gate, not after every styling commit.
- Every unit/integration fixture and every manual push verification uses at most 10 paper records. The PDF extraction spike also uses no more than 10 PDFs total.

---

### Task 1: Download Before Saving A Bounded Feed Push

**Files:**

- Modify: `Apps/PaperPulseWindows/src/PaperPulse.Engine/AcademicSources.cs`
- Create: `Apps/PaperPulseWindows/src/PaperPulse.Engine/PaperPushService.cs`
- Modify: `Apps/PaperPulseWindows/tests/PaperPulse.Engine.Tests/RetrievalAndRankingTests.cs`
- Modify: `Apps/PaperPulseWindows/src/PaperPulse.Windows/MainWindowViewModel.cs`
- Modify: `Apps/PaperPulseWindows/src/PaperPulse.Windows/MainWindow.xaml.cs`

**Interfaces:**

- `PaperPushService.RunAsync(FeedConfig, IReadOnlySet<string> alreadyLinkedPaperIds, IReadOnlySet<string> reusableLocalPaperIds, IProgress<PaperPushProgress>?, CancellationToken)` returns a `PaperPushResult` whose ordered attempts contain at most 10 entries total. Each attempt is either a successful `PaperPushItem` or a `PaperPushFailure`, so successes plus failures can never exceed 10.
- A `PaperPushItem` is either `Downloaded`, carrying `PaperCandidate` and `DownloadedPaperPdf`, or `ReuseExisting`, carrying the stable paper ID. Storage remains outside `PaperPulse.Engine`.
- `MainWindowViewModel.RefreshSelectedFeedAsync()` is the orchestrator that writes each successful PDF atomically and persists the paper/feed relationship only after that write succeeds.
- OpenAlex mapping may mark a URL verified only when the response supplies a direct PDF URL. `open_access.oa_url` alone is not sufficient because it can be a landing page.
- Crossref mapping continues to preserve DOI, source page, metadata, and any unverified link without constructing `OpenAccessEvidence(Status = Verified)`.

- [x] Extend the existing source fixture with separate OpenAlex fields for `best_oa_location.pdf_url`, `primary_location.pdf_url`, and `open_access.oa_url`.
- [x] Assert that a direct OpenAlex `pdf_url` produces verified evidence and that an `oa_url`-only record does not.
- [x] Keep the existing assertion that Crossref metadata does not produce verified evidence.
- [x] Correct only the OpenAlex JSON field selection needed to satisfy those assertions. Do not add fallback scraping, browser cookies, or a relaxed downloader path.
- [x] Add a pure effective-limit test asserting that configured values below 1 become 1, values from 1 through 10 are preserved, and values above 10 become 10. This test does not need more than 10 paper fixtures.
- [x] Add one portable push test with exactly 10 ranked candidates and an oversized configured daily limit; assert that exactly 10 attempts are returned.
- [x] Add one partial-failure test with no more than 10 candidates: verified successes remain ordered, an unverified Crossref candidate and an HTTP 403 candidate become failures, and later candidates still run.
- [x] Add one reuse test proving that a paper with a valid local PDF can join another feed without invoking the downloader, while an already-linked paper with no valid local PDF is not treated as complete.
- [x] Change the feed push path from “discover all and save all” to “discover, rank, cap at 10, download/validate, write PDF, then save/link.” Do not save a new paper when download or file writing fails.
- [x] Keep source abstracts as metadata, but do not generate or display a new short-summary library entry before the local PDF exists.
- [x] Remove the normal selected-paper download command and `DownloadSelectedPdfAsync()` after the automatic path is in place. Existing metadata-only rows remain visible as legacy data; do not delete them silently.
- [x] Map batch failures to actionable copy. HTTP 401/403 becomes “The source refused direct PDF access.” Invalid content becomes “The source did not return a valid PDF.” Missing verified evidence becomes “No verified open-access PDF is available.” Do not show raw exception text in the normal UI.
- [x] Report stable per-feed progress such as `Processing 3 of 8` and a final result such as `5 saved, 3 skipped`; never claim more than 10 attempted papers.
- [x] Run:

```bash
cd Apps/PaperPulseWindows
./scripts/validate-core.sh Debug
cd ../..
git diff --check
```

Expected: portable tests pass; Windows presentation tests are deferred to GitHub Windows validation because they reference the WinUI project.

- [x] Commit this task as `feat: download feed papers before saving`.

**Acceptance:** One paper-plane push attempts no more than 10 ranked papers. Every newly inserted paper already has a validated local PDF; an HTTP 403, unverified Crossref record, or invalid file is skipped without stopping later candidates. Existing PDFs are reused across feeds, legacy metadata-only rows are not silently deleted, and the detail view no longer asks the user to perform the normal download manually.

---

### Task 2: Establish The Windows Visual System

**Files:**

- Create: `Apps/PaperPulseWindows/src/PaperPulse.Windows/Themes/PaperPulseTheme.xaml`
- Create: `Apps/PaperPulseWindows/src/PaperPulse.Windows/Themes/PaperPulseControls.xaml`
- Modify: `Apps/PaperPulseWindows/src/PaperPulse.Windows/App.xaml`
- Modify: `Apps/PaperPulseWindows/src/PaperPulse.Windows/MainWindow.xaml`

**Interfaces:**

- `PaperPulseTheme.xaml` owns named brushes, typography sizes, spacing constants, 1 px strokes, and 6/8/10 px corner radii.
- `PaperPulseControls.xaml` owns reusable styles for glass panels, paper surfaces, icon buttons, metadata pills, selected rows, form fields, and prominent actions.
- Views consume semantic resource keys rather than literal colors.

- [x] Add the documented color roles: `midnight #05030F`, `deepBlue #080D29`, `deepPurple #290538`, `pulseRed #F01A1F`, `pulseMagenta #EB1FA3`, `pulsePurple #6B2BEB`, `warmGold #FFA11F`, `paper #FFF7E8`, `paperSoft #FFEEDA`, `paperInk #1F1A21`, and `paperSecondary #5C4F5C`.
- [x] Implement the fixed dark shell and warm paper reading surfaces. Do not follow system light mode, and do not create nested cards.
- [x] Define native focus, hover, pressed, disabled, selected, and destructive states with sufficient contrast.
- [x] Keep icon-only commands stable in size and attach tooltips plus accessible names.
- [x] Replace default black/gray surfaces in the root shell with semantic resources, without yet moving interaction logic.
- [x] Run `git diff --check`, then push the focused commit after user approval so GitHub Windows validation catches XAML resource failures.
- [x] Commit this task as `feat: add windows visual system`.

**Acceptance:** The app has one coherent dark research-workbench palette, warm reading surfaces, restrained emphasis, no default white/gray source-list background, no clipped icon controls, and no resource lookup failures.

---

### Task 3: Replace The Fixed Three-Column Shell

**Files:**

- Create: `Apps/PaperPulseWindows/src/PaperPulse.Windows/Presentation/WorkspaceSplitState.cs`
- Modify: `Apps/PaperPulseWindows/src/PaperPulse.Windows/MainWindow.xaml`
- Modify: `Apps/PaperPulseWindows/src/PaperPulse.Windows/MainWindow.xaml.cs`
- Modify: `Apps/PaperPulseWindows/src/PaperPulse.Windows/MainWindowViewModel.cs`
- Modify: `Apps/PaperPulseWindows/tests/PaperPulse.Windows.Tests/WindowsShellTests.cs`

**Interfaces:**

- The root has two zones: a navigation/library sidebar and a detail workspace.
- Sidebar width is minimum 300, preferred 340, maximum 420.
- The detail workspace has `PaperInfo`, an 8 px `GridSplitter`, and `PdfReader` columns.
- `WorkspaceSplitState.Clamp(double)` limits the detail/PDF ratio to `0.25...0.75`; the default is `0.5`.
- The persisted setting key remains `splitRatio` in the existing SQLite `settings` table.

- [x] Add focused tests for default `0.5`, lower/upper clamping, invalid persisted text, and round-trip invariant formatting.
- [x] Remove the `250 / * / 360` top-level layout.
- [x] Move the paper library into the sidebar below feeds, matching the documented information order.
- [x] Split all remaining width 1:1 between paper information and PDF; do not place both inside a 360 px inspector.
- [x] Add an 8 px splitter with a visible 2 x 48 grip and pointer cursor.
- [x] Load `splitRatio` on startup and save after a completed drag, not continuously on every pointer move.
- [x] Preserve the selected paper and WebView2 source while resizing or maximizing.
- [x] Enforce a practical 900 x 600 minimum content experience and verify that text wraps rather than overlaps at the minimum.
- [x] Run GitHub Windows validation after the focused commit.
- [x] Commit this task as `feat: balance windows reading workspace`.

**Acceptance:** At 1920 x 1080 maximized, the sidebar stays near 340 px and the rest of the window is divided approximately 1:1 between details and PDF. Resizing does not create the giant center list/tiny side panes shown in screenshot 1050, and the user-adjusted ratio survives restart.

---

### Task 4: Rebuild The Sidebar And Library

**Files:**

- Create: `Apps/PaperPulseWindows/src/PaperPulse.Windows/Views/LibrarySidebar.xaml`
- Create: `Apps/PaperPulseWindows/src/PaperPulse.Windows/Views/LibrarySidebar.xaml.cs`
- Modify: `Apps/PaperPulseWindows/src/PaperPulse.Windows/MainWindow.xaml`
- Modify: `Apps/PaperPulseWindows/src/PaperPulse.Windows/MainWindowViewModel.cs`
- Modify: `Apps/PaperPulseWindows/src/PaperPulse.Windows/PaperLibraryGroup.cs`
- Modify: `Apps/PaperPulseWindows/tests/PaperPulse.Windows.Tests/WindowsShellTests.cs`

**Interfaces:**

- Sidebar order is brand/status, search, `All papers / Favorites`, settings/new subscription, feeds, then grouped paper library.
- Every feed row owns its paper-plane command and stable progress position.
- Each group exposes its expanded state and paper count; selecting a feed expands it and collapses other feeds plus unclassified.
- Paper rows expose title, favorite, author, short brief, and date with the documented line limits.

- [x] Move search and favorites filtering from the center shell into the sidebar header.
- [x] Replace the current global bottom paper-plane button with one icon button per feed row.
- [x] Keep edit in the feed context menu and show delete only where allowed by the existing behavior.
- [x] Render feed and unclassified groups as collapsible sections inside one sidebar scroll surface.
- [x] Keep selected-paper state independent from favorite refreshes so favoriting does not select another feed or collapse the unclassified group.
- [x] Add the 3 px selected-paper emphasis line, gold favorite star, two-line title, one-line author, two-line brief, date, and low-emphasis empty-group row.
- [x] Verify search covers title, author, and abstract using the existing filtering behavior.
- [x] Commit this task as `feat: rebuild windows library sidebar`.

**Acceptance:** The sidebar is dense but readable, every feed has the correct manual push action, group expansion follows the preserved contract, favoriting does not disturb selection/expansion, and paper rows remain stable in English and Chinese-length content.

---

### Task 5: Build The Paper And PDF Workbench

**Files:**

- Create: `Apps/PaperPulseWindows/src/PaperPulse.Windows/Views/PaperDetailPane.xaml`
- Create: `Apps/PaperPulseWindows/src/PaperPulse.Windows/Views/PaperDetailPane.xaml.cs`
- Create: `Apps/PaperPulseWindows/src/PaperPulse.Windows/Views/PdfReaderPane.xaml`
- Create: `Apps/PaperPulseWindows/src/PaperPulse.Windows/Views/PdfReaderPane.xaml.cs`
- Modify: `Apps/PaperPulseWindows/src/PaperPulse.Windows/MainWindow.xaml`
- Modify: `Apps/PaperPulseWindows/src/PaperPulse.Windows/MainWindow.xaml.cs`
- Modify: `Apps/PaperPulseWindows/src/PaperPulse.Windows/MainWindowViewModel.cs`

**Interfaces:**

- `PaperDetailPane` renders identity, metadata, favorite, brief/full-reading action, source action, and per-paper task state.
- `PdfReaderPane` owns WebView2 initialization and the `NoSelection`, `Ready`, `MissingLegacyFile`, and `Unavailable` visual states. Feed-level download progress and failures remain with the feed row/run status.
- WebView2 navigates only to the resolved local PDF path after successful storage.

- [x] Build a warm-paper identity surface with title, authors, source, venue, date, citation count, and a top-right gold favorite action.
- [ ] Build a separate warm-paper brief surface with one prominent full-reading action and explicit generation/error state.
- [x] Add a low-emphasis source-page action only when a source URL exists.
- [x] Make PDF occupy its full column height. Remove the fixed `Height="420"` viewer and the PDF-inside-detail-scroll layout.
- [x] Show one centered glass empty/failure surface when no local PDF exists; never leave the pane blank.
- [x] Bind the pane to `PaperPdfPresentation`. A normal stored paper opens its already-local PDF; a legacy metadata-only row explains that its feed must be pushed again and may expose the source-page action, but it does not restore a general download button.
- [x] Preserve local PDF display when selecting the same paper, resizing, maximizing, or toggling favorite.
- [ ] Commit this task as `feat: build windows paper workspace`.

**Acceptance:** Paper identity and brief are scannable on warm paper surfaces, the PDF is an equal full-height work surface, new library rows already own local PDFs, legacy missing files are explained honestly, and a valid downloaded PDF opens in WebView2 without a separate normal download step.

---

### Task 6: Complete Native Editors, Settings, And Localization

**Files:**

- Create: `Apps/PaperPulseWindows/src/PaperPulse.Windows/Views/FeedEditorDialog.xaml`
- Create: `Apps/PaperPulseWindows/src/PaperPulse.Windows/Views/FeedEditorDialog.xaml.cs`
- Create: `Apps/PaperPulseWindows/src/PaperPulse.Windows/Views/SettingsDialog.xaml`
- Create: `Apps/PaperPulseWindows/src/PaperPulse.Windows/Views/SettingsDialog.xaml.cs`
- Create: `Apps/PaperPulseWindows/src/PaperPulse.Windows/Strings/en-US/Resources.resw`
- Create: `Apps/PaperPulseWindows/src/PaperPulse.Windows/Strings/zh-CN/Resources.resw`
- Modify: `Apps/PaperPulseWindows/src/PaperPulse.Windows/MainWindow.xaml.cs`
- Modify: `Apps/PaperPulseWindows/src/PaperPulse.Windows/MainWindowViewModel.cs`

**Interfaces:**

- The feed editor exposes the complete existing `FeedConfig` fields without changing their AND/OR semantics.
- Settings stores UI language and summary language independently through existing non-sensitive settings.
- LLM profile metadata and API-key UI are introduced only with Task 7; API keys remain in PasswordVault.

- [x] Replace the two-field ad hoc `ContentDialog` with the documented 720 x 700 scrollable editor and fixed footer.
- [x] Include name, arXiv categories, OR keywords, exclusions, institutions, venues, arXiv/OpenAlex/Crossref toggles, daily limit clamped to `1...10`, and lookback days.
- [x] State that empty institution/venue means any while authority evaluation still runs.
- [x] Build the settings shell with language, keyword library, status, and storage. Task 7 inserts the complete model-configuration section between keyword library and status; do not show an inert model panel before then.
- [x] Localize all user-facing Windows strings; retain source, model, and protocol proper names.
- [ ] Verify long Chinese and English labels wrap without resizing stable toolbar controls.
- [x] Commit this task as `feat: complete windows editors and localization`.

**Acceptance:** Feed editing no longer loses contract fields, UI and summary languages are independent, the shell has no obvious mixed-language fixed strings, and no API key leaves PasswordVault.

---

### Task 7: Finish Phase 4 Without Folding It Into The UI Refactor

**Files:**

- Create after spike: `Apps/PaperPulseWindows/src/PaperPulse.Pdf/PdfTextExtractionResult.cs`
- Create after spike: `Apps/PaperPulseWindows/src/PaperPulse.Pdf/PdfPigTextExtractor.cs`
- Create: `Apps/PaperPulseWindows/src/PaperPulse.Engine/LLM/` provider files matching existing C# contracts
- Create: `Apps/PaperPulseWindows/src/PaperPulse.Windows/Views/FullInterpretationPane.xaml`
- Create: `Apps/PaperPulseWindows/src/PaperPulse.Windows/Views/FullInterpretationPane.xaml.cs`
- Modify: `Apps/PaperPulseWindows/src/PaperPulse.Windows/Views/SettingsDialog.xaml`
- Modify: `Apps/PaperPulseWindows/src/PaperPulse.Windows/MainWindowViewModel.cs`
- Test: corresponding `PaperPulse.Pdf`, `PaperPulse.Engine`, `PaperPulse.Storage`, and `PaperPulse.Windows` test projects

- [ ] Run a maximum 10-document extraction spike: three Chinese papers, three English double-column papers, two formula-heavy papers, and two scanned papers. A paper may satisfy more than one category, but the total corpus must not exceed 10 PDFs.
- [ ] Record extraction order, page anchors, memory, exceptions, and license. Scanned PDFs remain “no extractable text”; do not add OCR in V0.1.
- [ ] Add a PDF library only if the spike meets the handoff criteria. Keep it behind `IPdfTextExtractor`.
- [ ] Port provider/profile behavior from existing contracts without changing prompts, fallback meaning, or provider wire formats.
- [ ] Store profile metadata in ordinary local storage and API keys only through `WindowsPasswordVaultCredentialStore`.
- [ ] Track generation and errors by paper ID so the user can browse other papers while work continues.
- [ ] When full interpretation opens, collapse the sidebar and reuse the same 1:1 interpretation/PDF splitter.
- [ ] Render section cards, page anchors, model, generation time, source range, and local Markdown filename.
- [ ] Require confirmation before deleting; remove only the current paper's interpretation metadata and Markdown.
- [ ] Commit extraction, provider, and full-reading work as separate focused commits, each with portable tests where applicable.

**Acceptance:** Full interpretation is evidence-anchored, nonblocking, paired with PDF, safely persisted, and honest about missing API keys or unextractable PDFs. No local brief is presented as a generated full interpretation.

---

### Task 8: Validate At The Two Remaining Windows Gates

**Mac before each approved push:**

```bash
cd Apps/PaperPulseWindows
./scripts/validate-core.sh Debug
cd ../..
git diff --check
git status --short
```

**GitHub after each push:**

- [ ] Confirm Windows restore, x64 Debug build, tests, Release package, and artifact for the exact commit SHA.
- [ ] Fix compile/XAML failures on Mac where possible; do not move daily implementation to Windows.

**Phase 3 Windows 11 gate after Tasks 1-6:**

- [ ] F5 at 1280 x 720, 1920 x 1080, and 2560 x 1440; repeat the maximized check at 125% and 150% scaling where available.
- [ ] Verify no overlap, clipping, blank panels, layout jumps, or resource lookup exceptions.
- [ ] Verify one feed push with no more than 10 selected papers: progress remains responsive, every newly saved row already has a local PDF, failures are skipped without aborting the batch, and the final attempted/saved/skipped counts never exceed 10.
- [ ] Verify group behavior, search, favorites, unclassified handling, source-page action, and truthful legacy-PDF state.
- [ ] Run:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
Set-Location Apps\PaperPulseWindows
.\scripts\verify-windows-gate.ps1 -Stage Phase3 -F5Verified
```

**Phase 4 Windows 11 gate after Task 7:**

- [ ] Verify valid local PDF rendering, 1:1 default, splitter persistence, feed-level HTTP 403 reporting, missing-key state, nonblocking generation, full-reading close/delete, and restart restoration. Use no more than 10 test papers.
- [ ] Run:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
Set-Location Apps\PaperPulseWindows
.\scripts\verify-windows-gate.ps1 -Stage Phase4 -F5Verified -WebView2Verified
```

- [ ] Commit only the generated gate records after their exact implementation SHA is green in GitHub Actions.

## Explicitly Deferred

- Public release, trusted signing, Store submission, `.appinstaller`, ARM64, clean-VM upgrade/uninstall behavior: Phase 5.
- OCR, PDF annotation, highlighting, relation graphs, recommendations, background scheduling, and cross-device sync: outside V0.1.
- Making every Crossref record downloadable: not a valid goal. Only records with independently verified open-access PDF evidence may become downloadable.
- Any host-specific 403 bypass: prohibited. The supported outcomes are a valid direct open PDF, an actionable feed-run failure, rerunning the feed, or opening an available source page.

## Final Acceptance

- The maximized layout follows the documented sidebar plus balanced reading workspace rather than `250 / * / 360`.
- The deep branded shell, warm paper surfaces, hierarchy, density, icon semantics, and empty/error states match the UI specification in native WinUI form.
- Each paper-plane push processes at most 10 ranked papers, and every newly saved paper already has a validated local PDF before its metadata or later short summary appears in the library.
- Screenshot 1049-style unverified Crossref candidates are skipped instead of being inserted as new metadata-only rows.
- Screenshot 1050-style source refusal is counted as a feed-run failure rather than appearing as raw `HTTP 403` in the global footer.
- WebView2 PDFs remain full-height and usable after selection, resize, maximize, favorite, and restart.
- All preserved product contracts still pass, Apple targets remain behaviorally untouched, GitHub Windows validation is green, and Windows work is limited to the two named runtime gates.
