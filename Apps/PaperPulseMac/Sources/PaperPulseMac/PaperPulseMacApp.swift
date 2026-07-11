import AppKit
import SwiftData
import SwiftUI
import PaperCore

@main
struct PaperPulseMacApp: App {
    @State private var appModel = PaperPulseMacModel()
    private let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try MacPersistenceStore.makeContainer()
        } catch {
            fatalError("Unable to create the macOS PaperPulse store: \(error)")
        }
        NSApplication.shared.setActivationPolicy(.regular)
        DispatchQueue.main.async {
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }

    var body: some Scene {
        WindowGroup("PaperPulse") {
            MacRootView()
                .environment(appModel)
                .modelContainer(modelContainer)
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
