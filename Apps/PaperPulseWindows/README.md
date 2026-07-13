# PaperPulse Windows

Phase 0 creates the native Windows client shell for PaperPulse. It is intentionally isolated from `Apps/PaperPulseMac`, `Apps/PaperPulseiOS`, and the Swift `Sources/PaperCore` package.

## Scope

- Create a C# WinUI 3 packaged app shell under `Apps/PaperPulseWindows`.
- Keep the Windows domain modules separate: `Contracts`, `Engine`, `Storage`, `Pdf`, and `Windows`.
- Add repeatable build, test, and MSIX package scripts.
- Do not migrate retrieval, download, LLM, SwiftData, Keychain, or PDF text extraction behavior in Phase 0.
- Do not read the macOS SwiftData store. Windows data will live under `%LOCALAPPDATA%\PaperPulse`.

## Required Windows Toolchain

- Windows 11 x64 is the first supported runtime and release-validation target.
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

The package script creates an unsigned MSIX for CI artifact validation. Windows 11 rejects direct installation of this package even with `Add-AppxPackage -AllowUnsigned`, so local installation validation uses a developer-signed copy:

```powershell
# Run once from an elevated PowerShell window to trust the local development certificate.
.\scripts\install-local-dev-msix.ps1
```

The helper creates or reuses a self-signed certificate in the current user's certificate store, trusts only its public certificate on the local machine, signs a copy of the MSIX, and installs it. Certificates and private keys remain outside the repository. Public release packages must use a trusted code-signing certificate.

`test.ps1` runs the portable core test suite. WinUI runtime checks require a registered Windows App Runtime and are performed through the Windows validation gate after CI succeeds.

## Build Ownership

- macOS develops and validates portable C# modules with `validate-core.sh`.
- GitHub Actions is the authority for Windows build, portable tests, unsigned MSIX packaging, and validation artifacts.
- Windows 11 is used only after a green workflow for F5 launch and local MSIX-install checks through `verify-windows-gate.ps1`.

## macOS Core Validation

The macOS workflow validates only portable C# projects. It does not build WinUI, package MSIX, or validate WebView2 or Credential Locker.

Install the SDK version pinned by `global.json`, then run:

```bash
export DOTNET_ROOT="$HOME/.dotnet"
export PATH="$DOTNET_ROOT:$PATH"
cd Apps/PaperPulseWindows
./scripts/validate-core.sh Debug
```

## macOS Status

macOS validates portable C# code only. It does not build WinUI, package MSIX, or validate F5, WebView2, PasswordVault, or local MSIX installation.

## Phase 0 Boundary

The only executable user experience is a blank WinUI shell window. Product behavior remains governed by `docs/development/windows-migration-handoff.md`; implementation of models, retrieval, storage, PDF reading, and LLM providers starts in later phases after user confirmation.
