import BackgroundTasks
import Foundation
import SwiftData
import UserNotifications

final class BackgroundRefreshCoordinator {
    static let shared = BackgroundRefreshCoordinator()
    static let refreshIdentifier = "com.gabrielmu.PaperPulse.refresh"

    private weak var appModel: PaperPulseAppModel?
    private var modelContainer: ModelContainer?

    private init() {}

    @MainActor
    func register(appModel: PaperPulseAppModel, modelContainer: ModelContainer) {
        self.appModel = appModel
        self.modelContainer = modelContainer
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.refreshIdentifier, using: nil) { task in
            Task { await self.handle(task: task) }
        }
        schedule()
    }

    func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: Self.refreshIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    @MainActor
    private func handle(task: BGTask) async {
        schedule()
        guard let appModel, let feed = appModel.activeFeed else {
            task.setTaskCompleted(success: false)
            return
        }
        let context = modelContainer.map(ModelContext.init)
        await appModel.run(feed: feed, modelContext: context)
        task.setTaskCompleted(success: true)
    }
}

final class NotificationCoordinator {
    static let shared = NotificationCoordinator()

    private init() {}

    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }

    func notifyRunComplete(selectedCount: Int) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
            let content = UNMutableNotificationContent()
            content.title = "PaperPulse Updated"
            content.body = "Selected \(selectedCount) new papers."
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request)
        }
    }
}
