import SwiftData
import SwiftUI
import PaperCore

@main
struct PaperPulseiOSApp: App {
    @State private var appModel = PaperPulseAppModel()
    private let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainer(for: FeedEntity.self, PaperEntity.self, SummaryEntity.self, RunEntity.self)
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
}
