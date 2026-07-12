# PaperPulse Mac-First Windows Gates Implementation Plan

> **For agentic workers:** Use a task-by-task execution workflow. Track the checkboxes, but do not add artificial red/green cycles for configuration, scripts, documentation, or CI wiring.

**Goal:** Make macOS the main implementation environment while GitHub Actions proves every pushed commit can build, test, and package on Windows, leaving only native runtime checks for the Windows 11 computer.

**Architecture:** Portable C# projects get a dedicated core solution and one macOS validation script. The full WinUI solution remains Windows-only and is verified on GitHub Actions after each push. A Windows 11 gate script records the checks CI cannot prove, including F5 launch, WebView2, PasswordVault, and local MSIX installation.

**Tech Stack:** .NET SDK 10.0.301, C# net10.0, WinUI 3, Windows App SDK, Bash, PowerShell, GitHub Actions, single-project MSIX.

## Global Constraints

- Keep C# + WinUI 3 + Windows App SDK and the current single-project MSIX route.
- Keep Windows 11 x64 as the first runtime and release-validation target.
- Do not modify Apple app behavior or Swift PaperCore.
- Mac owns portable Contracts, Engine, Storage logic, PDF abstractions, tests, documentation, commits, and pushes.
- Windows owns native runtime gates and unavoidable Windows-specific fixes only.
- CI artifacts are unsigned validation packages, not releases.
- Do not put API keys in Git, logs, CI artifacts, fixtures, SQLite, or validation reports.
- Work on codex/paperpulse-windows-migration; do not merge into main in this plan.
- Use terminal and local files. Do not use Browser Use or Computer Use.
- Use red/green testing later for business behavior, but not for solution membership, workflow YAML, script existence, or documentation.

---

## Task 1: Add the macOS Core Build Surface

**Files:**

- Create: Apps/PaperPulseWindows/PaperPulse.Core.sln
- Create: Apps/PaperPulseWindows/scripts/validate-core.sh
- Modify: Apps/PaperPulseWindows/README.md

**Deliverable:** One command on macOS restores, builds, and tests every portable C# project without loading PaperPulse.Windows or PaperPulse.Windows.Tests.

- [ ] Install the SDK pinned by global.json:

~~~bash
curl -fsSL https://dot.net/v1/dotnet-install.sh -o /private/tmp/dotnet-install.sh
chmod +x /private/tmp/dotnet-install.sh
/private/tmp/dotnet-install.sh --version 10.0.301 --install-dir "$HOME/.dotnet"
export DOTNET_ROOT="$HOME/.dotnet"
export PATH="$DOTNET_ROOT:$PATH"
dotnet --info
~~~

Expected: SDK 10.0.301 is available.

- [ ] Generate PaperPulse.Core.sln:

~~~bash
cd Apps/PaperPulseWindows
dotnet new sln --name PaperPulse.Core
dotnet sln PaperPulse.Core.sln add   src/PaperPulse.Contracts/PaperPulse.Contracts.csproj   src/PaperPulse.Engine/PaperPulse.Engine.csproj   src/PaperPulse.Storage/PaperPulse.Storage.csproj   src/PaperPulse.Pdf/PaperPulse.Pdf.csproj   tests/PaperPulse.Contracts.Tests/PaperPulse.Contracts.Tests.csproj   tests/PaperPulse.Engine.Tests/PaperPulse.Engine.Tests.csproj   tests/PaperPulse.Storage.Tests/PaperPulse.Storage.Tests.csproj
~~~

PaperPulse.Windows.csproj and PaperPulse.Windows.Tests.csproj must not appear.

- [ ] Create validate-core.sh with this contract:

~~~text
Input: optional Debug or Release; default Debug.
SDK: dotnet must be available on PATH.
Commands:
  dotnet restore PaperPulse.Core.sln
  dotnet build PaperPulse.Core.sln --configuration <value> --no-restore
  dotnet test PaperPulse.Core.sln --configuration <value> --no-build
Failure:
  exit 2 for an invalid configuration;
  exit 1 with an installation message when dotnet is missing;
  propagate restore/build/test failures.
Shell safety: set -euo pipefail.
~~~

Give the script executable mode.

- [ ] Add README guidance stating that macOS does not validate WinUI, MSIX, WebView2, or PasswordVault.

- [ ] Verify once:

~~~bash
export DOTNET_ROOT="$HOME/.dotnet"
export PATH="$DOTNET_ROOT:$PATH"
cd Apps/PaperPulseWindows
./scripts/validate-core.sh Debug
rg -n 'PaperPulse\.Windows' PaperPulse.Core.sln
~~~

Expected: restore/build/test pass; rg returns no matches.

- [ ] Commit:

~~~bash
git add Apps/PaperPulseWindows/PaperPulse.Core.sln   Apps/PaperPulseWindows/scripts/validate-core.sh   Apps/PaperPulseWindows/README.md
git commit -m "chore: add mac core validation"
~~~

## Task 2: Add Automatic Windows Build Evidence

**Files:**

- Modify: Apps/PaperPulseWindows/scripts/package.ps1
- Create: .github/workflows/windows-validation.yml

**Deliverable:** Every push receives Windows build/test/package status and a deterministic unsigned MSIX artifact.

- [ ] Extend package.ps1 with OutputDirectory defaulting to Apps/PaperPulseWindows/BundleArtifacts.

- [ ] Delete only that output directory at package start, recreate it, pass it to MSBuild as AppxPackageDir, then require at least one .msix file. Throw a descriptive error when none exists and print each produced package path.

- [ ] Create windows-validation.yml:

~~~yaml
name: Windows validation

on:
  push:
    branches:
      - codex/paperpulse-windows-migration
  workflow_dispatch:

permissions:
  contents: read

jobs:
  validate:
    name: Build, test, and package
    runs-on: windows-latest
    timeout-minutes: 20
    defaults:
      run:
        shell: pwsh

    steps:
      - name: Check out source
        uses: actions/checkout@v7

      - name: Set up pinned .NET SDK
        uses: actions/setup-dotnet@v5
        with:
          global-json-file: Apps/PaperPulseWindows/global.json

      - name: Build
        working-directory: Apps/PaperPulseWindows
        run: ./scripts/build.ps1 -Configuration Debug -Platform x64

      - name: Test
        working-directory: Apps/PaperPulseWindows
        run: ./scripts/test.ps1 -Configuration Debug -Platform x64

      - name: Package unsigned MSIX
        working-directory: Apps/PaperPulseWindows
        run: ./scripts/package.ps1 -Configuration Release -Platform x64

      - name: Upload validation package
        uses: actions/upload-artifact@v7
        with:
          name: paperpulse-windows-msix
          path: Apps/PaperPulseWindows/BundleArtifacts/**
          if-no-files-found: error
          retention-days: 7
~~~

- [ ] Run focused static checks:

~~~bash
git diff --check
rg -n 'windows-latest|build\.ps1|test\.ps1|package\.ps1|upload-artifact'   .github/workflows/windows-validation.yml
~~~

- [ ] Commit and push; GitHub is the integration test:

~~~bash
git add Apps/PaperPulseWindows/scripts/package.ps1   .github/workflows/windows-validation.yml
git commit -m "ci: validate windows build and package"
git push origin codex/paperpulse-windows-migration
~~~

- [ ] Check the exact pushed SHA:

~~~bash
sha="$(git rev-parse HEAD)"
curl -fsSL "https://api.github.com/repos/GabrielMu2006/PaperPulse/actions/runs?head_sha=$sha&per_page=20"
~~~

Acceptance: the matching Windows validation run is completed with conclusion success and has artifact paperpulse-windows-msix.

## Task 3: Add the Windows 11 Runtime Gate

**Files:**

- Create: Apps/PaperPulseWindows/scripts/verify-windows-gate.ps1
- Create: docs/development/windows-validation/README.md

**Deliverable:** One PowerShell command records native checks for an exact commit.

- [ ] Implement this interface as a single-line PowerShell command:

~~~powershell
.\scripts\verify-windows-gate.ps1 -Stage Phase0|Phase2|Phase3|Phase4|Phase5 [-F5Verified] [-MsixInstalled] [-PasswordVaultVerified] [-WebView2Verified] [-CleanVmVerified]
~~~

- [ ] Enforce these requirements before writing a report:

| Stage | Required evidence |
| --- | --- |
| Phase0 | F5Verified and MsixInstalled |
| Phase2 | PasswordVaultVerified |
| Phase3 | F5Verified |
| Phase4 | F5Verified and WebView2Verified |
| Phase5 | F5Verified, MsixInstalled, and CleanVmVerified |

Phase1 has no manual Windows gate unless CI exposes a Windows-only problem.

- [ ] The script must:

  1. Require Windows build 22000 or later.
  2. read git rev-parse HEAD.
  3. run build.ps1 Debug x64.
  4. run test.ps1 Debug x64.
  5. run package.ps1 Release x64.
  6. record Windows version, .NET SDK, Developer Mode, WebView2 Runtime, stage, commit, UTC time, and supplied evidence.
  7. write docs/development/windows-validation/<Stage>-<commit>.md.
  8. exit before writing when required evidence is missing.

- [ ] Document the report format and require a green Windows validation run for the same commit.

- [ ] Verify only the meaningful cases on Windows 11:

~~~powershell
.\scripts\verify-windows-gate.ps1 -Stage Phase0 -F5Verified
~~~

Expected: rejected because MsixInstalled is missing.

After F5 and local unsigned-MSIX installation:

~~~powershell
.\scripts\verify-windows-gate.ps1 -Stage Phase0 -F5Verified -MsixInstalled
~~~

Expected: build/test/package pass and one Phase0 report is written.

- [ ] Commit reusable files separately from generated evidence:

~~~bash
git add Apps/PaperPulseWindows/scripts/verify-windows-gate.ps1   docs/development/windows-validation/README.md
git commit -m "chore: add windows runtime validation gate"
~~~

## Task 4: Align Documentation and Establish the Evidence Chain

**Files:**

- Modify: Apps/PaperPulseWindows/README.md
- Modify: docs/development/windows-migration-handoff.md
- Modify: docs/development/windows-migration-transfer.md
- Modify: docs/development/windows-primary-development-handoff.md
- Create on Windows: docs/development/windows-validation/Phase0-<commit>.md

**Deliverable:** Mac code and push; GitHub CI validates; Windows returns runtime evidence only at named gates.

- [ ] Document these rules:

  - Mac is the daily implementation machine for portable Windows code.
  - GitHub Actions is the Windows compile/test/package authority.
  - Windows 11 is used only after green CI at named runtime gates.
  - Validation records are evidence, not a transfer of development ownership.
  - No manual archive or partial-directory transfer is allowed.
  - The remote migration branch is authoritative.

- [ ] Include the exact Mac sequence:

~~~bash
cd Apps/PaperPulseWindows
./scripts/validate-core.sh Debug
cd ../..
git push origin codex/paperpulse-windows-migration
sha="$(git rev-parse HEAD)"
curl -fsSL "https://api.github.com/repos/GabrielMu2006/PaperPulse/actions/runs?head_sha=$sha&per_page=20"
~~~

- [ ] Include the exact Windows sequence:

~~~powershell
git fetch origin --prune
git switch codex/paperpulse-windows-migration
git pull --ff-only
Set-Location Apps\PaperPulseWindows
.\scripts\verify-windows-gate.ps1 -Stage Phase0 -F5Verified -MsixInstalled
~~~

- [ ] Run final Mac verification:

~~~bash
export DOTNET_ROOT="$HOME/.dotnet"
export PATH="$DOTNET_ROOT:$PATH"
cd Apps/PaperPulseWindows
./scripts/validate-core.sh Debug
cd ../..
swift test
git diff --check
~~~

- [ ] Commit documentation and require green Windows CI:

~~~bash
git add Apps/PaperPulseWindows/README.md   docs/development/windows-migration-handoff.md   docs/development/windows-migration-transfer.md   docs/development/windows-primary-development-handoff.md
git commit -m "docs: document mac-first windows workflow"
git push origin codex/paperpulse-windows-migration
~~~

- [ ] On Windows 11, run Phase0 and commit only its generated record:

~~~powershell
git add docs\development\windows-validation
git commit -m "docs: record windows phase 0 validation"
git push origin codex/paperpulse-windows-migration
~~~

Final acceptance:

- Mac core validation passes.
- Swift regression tests pass.
- GitHub Windows validation is green for the implementation SHA.
- The unsigned MSIX artifact exists.
- The Windows 11 Phase0 report names the validated commit.
- Apple behavior is unchanged.
- Phase1 does not begin before these conditions pass.

