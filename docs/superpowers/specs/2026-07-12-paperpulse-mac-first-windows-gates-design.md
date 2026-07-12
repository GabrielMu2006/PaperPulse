# PaperPulse Mac-First Windows Gates Design

## Goal

Make the Mac the primary implementation environment for the PaperPulse Windows migration while preserving reliable Windows-native validation. A Mac push must produce an objective Windows build result, and the Windows 11 machine must be used only for capabilities that cannot be simulated by macOS or CI.

## Decision

Keep the approved Windows product route:

- C# + WinUI 3 + Windows App SDK for the native client.
- Single-project MSIX as the current build-validation package format.
- Windows 11 x64 as the first runtime and release-validation target.

This decision does not commit the project to a public distribution channel. The CI MSIX is an unsigned validation artifact only. Public signing, Microsoft Store distribution, and external installer choices remain Phase 5 decisions.

## Why This Route

Switching to MAUI, Avalonia, Electron, or an unpackaged app would not remove the need to validate Windows-specific behaviors such as WebView2, Credential Locker, local paths, package installation, and signing. It would add a framework or deployment migration while the product is intentionally Windows-native.

Windows App SDK supports both MSIX and unpackaged deployment. For this project, single-project MSIX gives an auditable package artifact now; unpackaged deployment would add bootstrap/runtime and installer ownership before there is a product requirement for it.

## Ownership Boundaries

| Owner | Responsibilities | Must not own by default |
| --- | --- | --- |
| Mac | `PaperPulse.Contracts`, `PaperPulse.Engine`, portable `PaperPulse.Storage` schema/file logic, `PaperPulse.Pdf` abstractions, C# tests, Swift behavior comparison, migration documentation, Git commits and pushes. | WinUI runtime acceptance, MSIX installation, WebView2 runtime behavior, Credential Locker behavior. |
| GitHub Actions | On every migration-branch push, Windows restore, build, test, unsigned MSIX package, and artifact/status publication. | F5 interaction, real credential storage, local PDF viewer behavior, release signing. |
| Windows 11 | Only the defined runtime gates: F5, WebView2/PDF, PasswordVault, local MSIX installation, and clean-machine release checks. A Windows-only defect may be fixed here when it cannot be diagnosed on macOS. | General Contracts/Engine implementation or daily development. |

`Apps/PaperPulseMac`, `Apps/PaperPulseiOS`, `Sources/PaperCore`, and `PaperPulse.xcodeproj` remain outside the Windows migration unless an explicitly approved cross-platform contract change requires a narrow update.

## Build Surfaces

### Mac Core Surface

The repository will provide a core-only C# build/test entry point that excludes `PaperPulse.Windows` and all Windows-only APIs. It will run on macOS after the .NET SDK specified by `Apps/PaperPulseWindows/global.json` is installed.

The Mac pre-push evidence for a Windows migration change is:

1. The core-only C# build and tests pass.
2. Relevant Swift fixtures or `swift test` pass when a behavior contract changes.
3. The commit is pushed to `codex/paperpulse-windows-migration`.

The Mac must not claim that a WinUI solution, MSIX, WebView2, or PasswordVault test passed locally.

### GitHub Windows CI Surface

A GitHub Actions workflow will run on `windows-latest` for every push to `codex/paperpulse-windows-migration` and on manual dispatch. It will:

1. Use the SDK version required by `global.json`.
2. Run the existing Windows build script.
3. Run the existing Windows test script.
4. Run the existing MSIX package script.
5. Upload the unsigned MSIX output as a CI validation artifact.

The workflow status is the authoritative answer to "did this commit compile, test, and package on Windows?" A failed workflow returns to Mac for diagnosis unless the failure depends on a Windows-only runtime condition.

### Windows 11 Runtime Surface

Windows work is event-driven, not commit-driven. It occurs only after a green CI result at these gates:

| Gate | Required Windows 11 evidence |
| --- | --- |
| Phase 0 | Visual Studio Restore, x64 Debug F5 blank shell, local unsigned MSIX installation. |
| Phase 1 | No manual gate unless CI exposes a Windows-only issue. |
| Phase 2 | PasswordVault storage/retrieval and `%LOCALAPPDATA%\\PaperPulse` data-path behavior. |
| Phase 3 | F5 smoke test for the library, feed, grouping, search, favorite, and manual paper-plane interactions. |
| Phase 4 | WebView2 local PDF loading, split persistence, missing-key UX, and asynchronous full-reading states. |
| Phase 5 | Clean Windows 11 VM install, upgrade, uninstall/data behavior, and signed release candidate verification. |

Each runtime gate will be driven by one repeatable PowerShell verification command. It will write a concise, commit-addressed validation record under `docs/development/windows-validation/`. The Windows Codex task may create and push that documentation-only record after a successful gate. This is evidence flowing back to Git, not a handoff of day-to-day implementation ownership.

## Git Flow

1. Mac starts from the current remote migration branch, implements a bounded change, runs core tests, commits, and pushes.
2. GitHub Actions publishes a Windows build/test/package status for that exact commit.
3. If CI fails, Mac fixes portable code or configuration and pushes again. Windows is not involved by default.
4. At a listed runtime gate, Windows fetches the exact green commit, runs the verification command, and pushes only a validation record or a minimal Windows-specific fix.
5. Mac fetches before the next change. The remote branch, not either machine's local state, is authoritative.

No archive copying, partial-directory copying, or chat-only state transfer is allowed.

## Quality and Security Rules

- A green macOS core build never substitutes for a green Windows CI build.
- A green Windows CI build never substitutes for the runtime gates that require an actual Windows 11 machine.
- No API key may enter Git, workflow logs, SQLite fixtures, validation records, or CI artifacts.
- CI packages stay unsigned and are not published as releases.
- Phase boundaries and product contracts remain those in `docs/development/windows-migration-handoff.md`.

## Planned Implementation Sequence

1. Add the macOS-runnable core build/test surface and install the pinned .NET SDK on the Mac.
2. Add the Windows GitHub Actions workflow and ensure its artifact path is deterministic.
3. Add the repeatable Windows gate verification script and validation-record format.
4. Update the Windows migration handoff documents and Windows Codex prompt to enforce this workflow.
5. Validate Phase 0 with the first green CI run and the first Windows 11 runtime gate before beginning Phase 1.
