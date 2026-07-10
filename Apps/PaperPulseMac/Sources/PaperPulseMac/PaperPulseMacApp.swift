import SwiftUI
import PaperCore

@main
struct PaperPulseMacApp: App {
    @State private var appModel = PaperPulseMacModel()

    var body: some Scene {
        WindowGroup("PaperPulse") {
            MacRootView()
                .environment(appModel)
                .task {
                    appModel.bootstrapProviderProfile()
                }
        }
        .commands {
            CommandMenu("PaperPulse") {
                Button("Refresh Latest Papers") {
                    Task { await appModel.runDefaultFeed() }
                }
                .keyboardShortcut("r", modifiers: [.command])
            }
        }

        Settings {
            MacSettingsView()
                .environment(appModel)
        }
    }
}
