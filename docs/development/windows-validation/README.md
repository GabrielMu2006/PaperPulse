# PaperPulse Windows Runtime Validation

GitHub Actions is the authority for Windows restore, build, portable core tests, unsigned MSIX package creation, and artifact upload. Run this gate only after the green Windows validation workflow for the same commit.

Windows 11 is reserved for checks CI cannot prove:

- F5 launches the native WinUI shell.
- The unsigned MSIX installs and starts locally.
- PasswordVault works when Phase 2 reaches credential storage.
- WebView2 works when Phase 4 reaches PDF viewing.
- A clean Windows VM passes installation checks before Phase 5 distribution.

From Apps\PaperPulseWindows on Windows 11:

```powershell
.\scripts\verify-windows-gate.ps1 -Stage Phase0 -F5Verified -MsixInstalled
```

The script requires Windows 11 build 22000 or later, verifies the supplied evidence before it runs any build command, then runs Debug build, portable core tests, and Release unsigned MSIX packaging. It writes a report only if all commands succeed:

```text
docs/development/windows-validation/Phase0-<commit>.md
```

Do not pass a switch before performing its associated manual check. Reports are evidence for a specific commit and must not include API keys, log payloads, user data, or copied secrets.

Required evidence:

| Stage | Evidence |
| --- | --- |
| Phase0 | F5Verified, MsixInstalled |
| Phase2 | PasswordVaultVerified |
| Phase3 | F5Verified |
| Phase4 | F5Verified, WebView2Verified |
| Phase5 | F5Verified, MsixInstalled, CleanVmVerified |

Phase 1 is portable contract work and has no separate Windows runtime gate unless CI identifies a Windows-only defect.
