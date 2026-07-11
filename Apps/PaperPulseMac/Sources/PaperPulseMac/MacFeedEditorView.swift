import PaperCore
import SwiftUI

struct MacFeedEditorDraft: Identifiable {
    var id = UUID()
    var feedID: UUID?
    var name: String
    var categoriesText: String
    var keywordsText: String
    var excludedKeywordsText: String
    var dailyLimit: Int
    var lookbackDays: Int
    var enabledSources: Set<PaperSourceKind>

    init(feed: FeedConfig? = nil) {
        feedID = feed?.id
        name = feed?.name ?? ""
        categoriesText = feed?.categories.joined(separator: ", ") ?? "cs.AI, cs.CL"
        keywordsText = feed?.keywords.joined(separator: ", ") ?? ""
        excludedKeywordsText = feed?.excludedKeywords.joined(separator: ", ") ?? ""
        dailyLimit = feed?.authorityPolicy.dailyLimit ?? 5
        lookbackDays = feed?.lookbackDays ?? 7
        enabledSources = Set(feed?.enabledSources ?? FeedConfig.defaultEnabledSources)
    }

    func makeFeed() -> FeedConfig {
        FeedConfig(
            id: feedID ?? UUID(),
            name: name.trimmed,
            categories: categoriesText.commaSeparated,
            keywords: keywordsText.commaSeparated,
            excludedKeywords: excludedKeywordsText.commaSeparated,
            authorityPolicy: AuthorityPolicy(dailyLimit: dailyLimit),
            enabledSources: Array(enabledSources),
            lookbackDays: lookbackDays
        )
    }
}

struct MacFeedEditorView: View {
    @Environment(PaperPulseMacModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @State private var draft: MacFeedEditorDraft
    var onSave: (FeedConfig) -> Void

    init(draft: MacFeedEditorDraft, onSave: @escaping (FeedConfig) -> Void) {
        _draft = State(initialValue: draft)
        self.onSave = onSave
    }

    var body: some View {
        let language = appModel.appLanguage
        VStack(spacing: 0) {
            Form {
                Section(language.text(en: "Feed", zh: "订阅")) {
                    TextField(language.text(en: "Name", zh: "名称"), text: $draft.name)
                    TextField(language.text(en: "arXiv categories", zh: "arXiv 分类"), text: $draft.categoriesText)
                    TextField(language.text(en: "Keywords", zh: "关键词"), text: $draft.keywordsText)
                    TextField(language.text(en: "Excluded keywords", zh: "排除关键词"), text: $draft.excludedKeywordsText)
                }
                Section(language.text(en: "Sources", zh: "学术来源")) {
                    ForEach([PaperSourceKind.arxiv, .openAlex, .crossref], id: \.self) { source in
                        Toggle(source.editorTitle(language: language), isOn: sourceBinding(source))
                    }
                }
                Section(language.text(en: "Selection", zh: "筛选")) {
                    Stepper(language.text(en: "Papers per run: \(draft.dailyLimit)", zh: "每次篇数：\(draft.dailyLimit)"), value: $draft.dailyLimit, in: 1...20)
                    Stepper(language.text(en: "Look back: \(draft.lookbackDays) days", zh: "检索范围：\(draft.lookbackDays) 天"), value: $draft.lookbackDays, in: 1...30)
                }
            }
            Divider()
            HStack {
                Button(language.text(en: "Cancel", zh: "取消")) { dismiss() }
                Spacer()
                Button(language.text(en: "Save Feed", zh: "保存订阅")) {
                    onSave(draft.makeFeed())
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSave)
            }
            .padding()
        }
        .frame(width: 520, height: 500)
        .navigationTitle(draft.feedID == nil ? language.text(en: "New Feed", zh: "新建订阅") : language.text(en: "Edit Feed", zh: "编辑订阅"))
    }

    private var canSave: Bool {
        !draft.name.trimmed.isEmpty && (!draft.categoriesText.commaSeparated.isEmpty || !draft.keywordsText.commaSeparated.isEmpty) && !draft.enabledSources.isEmpty
    }

    private func sourceBinding(_ source: PaperSourceKind) -> Binding<Bool> {
        Binding(
            get: { draft.enabledSources.contains(source) },
            set: { enabled in
                if enabled { draft.enabledSources.insert(source) } else { draft.enabledSources.remove(source) }
            }
        )
    }
}

private extension PaperSourceKind {
    func editorTitle(language: AppLanguage) -> String {
        switch self {
        case .arxiv: "arXiv"
        case .openAlex: "OpenAlex"
        case .crossref: "Crossref"
        default: language.text(en: rawValue, zh: rawValue)
        }
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    var commaSeparated: [String] { split(separator: ",").map { String($0).trimmed }.filter { !$0.isEmpty } }
}
