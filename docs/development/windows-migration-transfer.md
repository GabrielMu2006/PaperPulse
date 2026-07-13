# PaperPulse Windows Migration Transfer Guide

Updated: 2026-07-12

This document explains what is currently useful in Git, what must move to a Windows machine, and how to continue the PaperPulse Windows native migration without losing context.

## Current Git State

Repository:

```text
/Users/gabrielmu/Documents/papers
origin https://github.com/GabrielMu2006/PaperPulse.git
```

Current local branch:

```text
codex/paperpulse-windows-migration
```

Current known local commits on top of `origin/main`:

```text
97c025a docs: add windows primary development handoff
83bc79d docs: add windows migration transfer guide
ab63f04 chore: scaffold PaperPulse Windows phase 0
a241f27 docs: add windows migration handoff
3481d62 origin/main docs: restore feature overview before downloads
```

The local working tree was clean when this transfer guide was written.

## Is The Current Git Code Useful?

Yes. The current branch contains useful migration state and should be preserved.

Useful commits:

- `a241f27 docs: add windows migration handoff`
  - This is the strategic migration contract.
  - It defines the Windows native route, product behavior that must be preserved, module boundaries, data rules, toolchain expectations, and phased plan.
  - Keep this commit. Future Codex tasks should read it first.

- `ab63f04 chore: scaffold PaperPulse Windows phase 0`
  - This creates the Windows project skeleton under `Apps/PaperPulseWindows`.
  - It includes the WinUI 3 solution shell, C# project layout, central package versions, repeatable PowerShell build/test/package scripts, initial tests, placeholder MSIX assets, and Windows README.
  - Keep this commit. It is the starting point for Windows validation.

There is no committed business logic migration yet. That is intentional. Phase 0 only creates the Windows shell and repeatable project structure.

## What Is Not Yet Verified

The current macOS machine cannot verify the Windows runtime path because:

- `dotnet` is not installed.
- `pwsh` is not installed.
- WinUI 3, Windows App SDK, WebView2 runtime behavior, MSIX packaging, and Credential Locker require Windows.

The following checks were completed on macOS:

```text
swift test
xcodebuild -project PaperPulse.xcodeproj -scheme PaperPulseMacTests -configuration Debug -derivedDataPath /private/tmp/PaperPulseMacDerivedData test CODE_SIGNING_ALLOWED=NO
```

Both passed after the Windows scaffold was added, confirming that the existing Swift package and macOS app were not broken by Phase 0.

## Files To Preserve

These files are the handoff source of truth:

```text
docs/development/windows-migration-handoff.md
docs/development/windows-migration-transfer.md
Apps/PaperPulseWindows/README.md
Apps/PaperPulseWindows/PaperPulse.Windows.sln
Apps/PaperPulseWindows/global.json
Apps/PaperPulseWindows/Directory.Build.props
Apps/PaperPulseWindows/Directory.Packages.props
Apps/PaperPulseWindows/scripts/build.ps1
Apps/PaperPulseWindows/scripts/test.ps1
Apps/PaperPulseWindows/scripts/package.ps1
```

The whole `Apps/PaperPulseWindows` directory should be transferred together.

## Windows Development Machine Requirements

Use a Windows development machine with:

- Windows 11 x64 as the first target.
- Developer Mode enabled.
- Visual Studio 2026.
- Visual Studio `WinUI application development` workload.
- .NET 10 SDK matching `Apps/PaperPulseWindows/global.json`.
- Git for Windows.
- Microsoft Edge WebView2 Runtime.
- PowerShell 7 or Windows PowerShell capable of running the provided `.ps1` scripts.

The current Phase 0 package versions are pinned in:

```text
Apps/PaperPulseWindows/Directory.Packages.props
```

Current key packages:

```text
Microsoft.WindowsAppSDK 2.2.0
Microsoft.Web.WebView2 1.0.4078.44
Microsoft.Data.Sqlite 10.0.9
CommunityToolkit.Mvvm 8.4.2
xunit 2.9.3
Microsoft.NET.Test.Sdk 18.7.0
```

## Recommended Transfer Method

The safest transfer method is GitHub.

On the current Mac, push the local branch:

```bash
cd /Users/gabrielmu/Documents/papers
git status --short --branch
git push origin codex/paperpulse-windows-migration
```

On the Windows machine, clone or fetch the branch:

```powershell
git clone https://github.com/GabrielMu2006/PaperPulse.git
cd PaperPulse
git checkout codex/paperpulse-windows-migration
```

If the repository is already cloned on Windows:

```powershell
cd PaperPulse
git fetch origin
git checkout codex/paperpulse-windows-migration
git pull --ff-only
```

Do not copy only `Apps/PaperPulseWindows` by hand unless GitHub is unavailable. The migration context depends on both the new Windows subtree and the documentation under `docs/development`.

## Windows Validation Procedure

Do not start a Windows runtime check until GitHub Actions is green for the current commit. Then, from the Windows checkout:

```powershell
git fetch origin --prune
git switch codex/paperpulse-windows-migration
git pull --ff-only
Set-Location Apps\PaperPulseWindows
.\scripts\verify-windows-gate.ps1 -Stage Phase0 -F5Verified -MsixInstalled
```

Expected Phase 0 result: the script reruns build, portable core tests, and unsigned MSIX packaging, then writes `docs/development/windows-validation/Phase0-<commit>.md`. F5 and local MSIX installation must be completed before their evidence switches are supplied. Windows 11 rejects direct installation of the unsigned artifact, so run `scripts\install-local-dev-msix.ps1` once from an elevated PowerShell window; it signs only a local copy with a self-signed certificate that is never committed or used for release.

If a command fails, record:

- Exact command.
- Full error message.
- Installed Visual Studio version.
- Installed .NET SDK versions from `dotnet --info`.
- Whether Developer Mode is enabled.
- Whether the WinUI workload is installed.

## Codex Continuation On Windows

Codex should continue from repository state, not from memory alone.

Official Codex documentation describes local projects as folders on your computer that provide the working directory for Codex tasks, and recommends keeping durable project guidance in `AGENTS.md` or checked-in documentation so future tasks can use it. This repository uses checked-in documentation for the migration handoff.

Start a new Codex task on Windows from the repository root and give it this prompt:

```text
请阅读 docs/development/windows-migration-handoff.md、docs/development/windows-migration-transfer.md 和 Apps/PaperPulseWindows/README.md。

当前目标：只验证 Phase 0 的 Windows 原生工程空壳。请不要迁移检索、下载、LLM、SwiftData、Keychain 或 PDF 文本抽取业务逻辑；不要修改现有 iOS、macOS 和 Swift PaperCore 行为；不要推送 GitHub。

请先检查 git status、当前分支、dotnet --info、Visual Studio/WinUI workload 是否满足要求，并确认当前 commit 的 GitHub Windows validation 已成功。然后执行 Apps/PaperPulseWindows/scripts/verify-windows-gate.ps1 的对应阶段 gate。若失败，请记录阻塞项和修复建议；若通过，只提交生成的 validation record，等待我确认是否进入 Phase 1。
```

Recommended Codex working directory:

```text
C:\Users\gabriel\src\PaperPulse
```

Use the actual clone path on the Windows machine if it differs.

Avoid starting Codex inside only `Apps\PaperPulseWindows` for planning tasks, because the agent also needs access to `docs/development/windows-migration-handoff.md` and existing Swift test fixtures in later phases.

## What To Avoid

Do not:

- Merge `codex/paperpulse-windows-migration` into `main` before Windows Phase 0 validation.
- Delete `a241f27` or `ab63f04`.
- Rewrite the Windows scaffold into a Swift-on-Windows approach.
- Modify `Apps/PaperPulseMac`, `Apps/PaperPulseiOS`, `Sources/PaperCore`, or `PaperPulse.xcodeproj` during Phase 0 validation.
- Migrate app business logic during Phase 0 validation.
- Put API keys into Git, SQLite, logs, JSON exports, or screenshots.
- Treat placeholder PNG assets as final product design.
- Publish or push release artifacts.

## If GitHub Push Is Not Available

Use a full repository archive, not a partial directory copy:

```bash
cd /Users/gabrielmu/Documents
tar --exclude='papers/.git/index.lock' -czf PaperPulse-transfer-2026-07-12.tar.gz papers
```

On Windows, extract it and verify:

```powershell
git status --short --branch
git log --oneline --max-count 3
```

This fallback is less clean than GitHub because remotes, credentials, line endings, and ignored build artifacts are easier to mishandle.

## Decision Point After Transfer

After Windows Phase 0 validation:

- If build/test/package pass, commit a small local validation note or doc update.
- If validation fails because of project configuration, fix only Phase 0 scaffolding.
- If validation fails because of missing Windows tooling, install the missing workload/runtime and rerun.
- Only after Phase 0 is green should Phase 1 begin: C# model contracts and fixture-based behavior tests.

## Next Phase Boundary

Phase 1 may start only after explicit user confirmation.

Phase 1 scope:

- C# records and enums equivalent to Swift `PaperCore` models.
- JSON fixture round-trip tests.
- Stable behavior contracts for later Engine migration.

Phase 1 must still avoid:

- Retrieval implementation.
- Download implementation.
- LLM providers.
- SQLite persistence.
- Credential Locker.
- Full WinUI product screens.
