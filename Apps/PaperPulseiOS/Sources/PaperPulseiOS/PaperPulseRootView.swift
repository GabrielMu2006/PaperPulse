import SwiftData
import SwiftUI

struct PaperPulseRootView: View {
    @Environment(PaperPulseAppModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab: PaperPulseTab = .today

    var body: some View {
        let language = appModel.appLanguage
        TabView(selection: $selectedTab) {
            FeedListView()
                .tabItem { Label(language.text(en: "Feeds", zh: "订阅"), systemImage: "line.3.horizontal.decrease.circle") }
                .tag(PaperPulseTab.feeds)

            TodayView()
                .tabItem { Label(language.text(en: "Today", zh: "今日"), systemImage: "sun.max") }
                .tag(PaperPulseTab.today)

            LibraryView()
                .tabItem { Label(language.text(en: "Library", zh: "论文库"), systemImage: "books.vertical") }
                .tag(PaperPulseTab.library)

            SettingsView()
                .tabItem { Label(language.text(en: "Settings", zh: "设置"), systemImage: "gearshape") }
                .tag(PaperPulseTab.settings)
        }
        .task {
            appModel.bootstrapProviderProfile()
            appModel.bootstrapFeeds(modelContext: modelContext)
        }
    }
}

private enum PaperPulseTab: Hashable {
    case feeds
    case today
    case library
    case settings
}
