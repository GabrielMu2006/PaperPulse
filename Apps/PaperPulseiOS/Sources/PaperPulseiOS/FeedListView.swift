import PaperCore
import SwiftData
import SwiftUI

struct FeedListView: View {
    @Environment(PaperPulseAppModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext
    @State private var editorDraft: FeedEditorDraft?

    var body: some View {
        let language = appModel.appLanguage
        NavigationStack {
            PaperPulseScreen(title: language.text(en: "Feeds", zh: "订阅")) {
                Button {
                    editorDraft = FeedEditorDraft()
                } label: {
                    Label(language.text(en: "Add Feed", zh: "新增订阅"), systemImage: "plus")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)

                ForEach(appModel.feeds) { feed in
                    PaperPulseCard {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(feed.name)
                                    .font(.headline)
                                Text(feed.categories.joined(separator: ", "))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            if appModel.activeFeed?.id == feed.id {
                                Label(language.text(en: "Active", zh: "当前"), systemImage: "checkmark.circle.fill")
                                    .labelStyle(.iconOnly)
                                    .foregroundStyle(.blue)
                            }
                        }

                        Text(feed.keywords.joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)

                        HStack {
                            Button(language.text(en: "Use for Today", zh: "设为今日订阅")) {
                                appModel.selectFeed(feed)
                            }
                            .buttonStyle(.bordered)
                            .disabled(appModel.activeFeed?.id == feed.id)

                            Button(language.text(en: "Edit", zh: "编辑")) {
                                editorDraft = FeedEditorDraft(feed: feed)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
            .sheet(item: $editorDraft) { draft in
                FeedEditorView(draft: draft) { feed in
                    appModel.saveFeed(feed, modelContext: modelContext)
                }
            }
        }
    }
}
