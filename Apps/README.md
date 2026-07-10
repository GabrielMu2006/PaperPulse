# PaperPulse Apps

`PaperCore` is a SwiftPM package and builds with `swift build`.

The iOS and macOS source folders are native SwiftUI app targets intended to be added to an Xcode project or generated with XcodeGen once full Xcode is installed and selected. They deliberately share `PaperCore` but do not depend on each other:

- `PaperPulseiOS`: SwiftUI tabs, SwiftData models, Keychain API-key storage, BackgroundTasks registration, PDFKit reader, local notifications.
- `PaperPulseMac`: SwiftUI `NavigationSplitView`, settings scene, command-menu refresh, PDFKit detail pane.

The current machine has Command Line Tools only, so app build/run verification requires selecting a full Xcode installation first.

When Xcode is available, generate the project with:

```bash
xcodegen generate
```

Then open `PaperPulse.xcodeproj` and run either `PaperPulseiOS` or `PaperPulseMac`.
