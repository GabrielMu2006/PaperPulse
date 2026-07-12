# PaperPulse Windows

Phase 0 creates the native Windows client shell for PaperPulse. It is intentionally isolated from `Apps/PaperPulseMac`, `Apps/PaperPulseiOS`, and the Swift `Sources/PaperCore` package.

## Scope

- Create a C# WinUI 3 packaged app shell under `Apps/PaperPulseWindows`.
- Keep the Windows domain modules separate: `Contracts`, `Engine`, `Storage`, `Pdf`, and `Windows`.
- Add repeatable build, test, and MSIX package scripts.
- Do not migrate retrieval, download, LLM, SwiftData, Keychain, or PDF text extraction behavior in Phase 0.
- Do not read the macOS SwiftData store. Windows data will live under `%LOCALAPPDATA%\PaperPulse`.

## Required Windows Toolchain

- Windows 10 version 1809 or later; Windows 11 x64 is the first supported target.
- Developer Mode enabled.
- Visual Studio 2026 with the `WinUI application development` workload.
- .NET 10 SDK, pinned by `global.json` to SDK feature band `10.0.301`.
- Git for Windows.
- Microsoft Edge WebView2 Runtime.

The solution uses these pinned NuGet versions:

- `Microsoft.WindowsAppSDK` `2.2.0`
- `Microsoft.Web.WebView2` `1.0.4078.44`
- `Microsoft.Data.Sqlite` `10.0.9`
- `CommunityToolkit.Mvvm` `8.4.2`
- `xunit` `2.9.3`

## Commands

Run these from PowerShell on a Windows development machine:

```powershell
cd Apps\PaperPulseWindows
.\scripts\build.ps1 -Configuration Debug
.\scripts\test.ps1 -Configuration Debug
.\scripts\package.ps1
```

The package script creates an unsigned sideload MSIX for local validation only. Public release packages must be code signed before distribution.

## macOS Status

This repository update was prepared on macOS arm64, where `dotnet` and `pwsh` are not installed. Windows build, test, package, and F5 launch must be verified on a Windows machine with the toolchain above.

## Phase 0 Boundary

The only executable user experience is a blank WinUI shell window. Product behavior remains governed by `docs/development/windows-migration-handoff.md`; implementation of models, retrieval, storage, PDF reading, and LLM providers starts in later phases after user confirmation.
