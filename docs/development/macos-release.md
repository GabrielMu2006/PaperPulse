# macOS Release

PaperPulse macOS uses semantic marketing versions. The initial local release is `0.1.0`; its archive is named with the user-facing `v` prefix.

Create a local arm64 Release archive:

```bash
./scripts/package_macos_release.sh 0.1.0
```

The archive is written to `releases/PaperPulse-v0.1.0-macOS-arm64.zip`. The `releases/` directory is intentionally ignored by Git.

This project currently has no Developer ID signing identity, so local archives are not notarized. A recipient may need to explicitly allow the app in macOS Privacy & Security after downloading it.
