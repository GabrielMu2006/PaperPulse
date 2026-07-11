import SwiftData
import SwiftUI
import PaperCore

@main
struct PaperPulseiOSApp: App {
    @State private var appModel = PaperPulseAppModel()
    private let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try Self.makeModelContainer()
        } catch {
            fatalError("Unable to create SwiftData container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            PaperPulseRootView()
                .environment(appModel)
                .modelContainer(modelContainer)
                .task {
                    BackgroundRefreshCoordinator.shared.register(appModel: appModel, modelContainer: modelContainer)
                }
        }
    }

    private static func makeModelContainer() throws -> ModelContainer {
        let schema = Schema([
            FeedEntity.self,
            PaperEntity.self,
            SummaryEntity.self,
            RunEntity.self,
            ProcessingJobEntity.self
        ])
        let storeURL = try FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("PaperPulse-development.store")
        let configuration = ModelConfiguration(schema: schema, url: storeURL)

        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            // Development builds may carry an incompatible pre-versioned schema.
            for suffix in ["", "-shm", "-wal"] {
                try? FileManager.default.removeItem(atPath: storeURL.path + suffix)
            }
            return try ModelContainer(for: schema, configurations: configuration)
        }
    }
}
