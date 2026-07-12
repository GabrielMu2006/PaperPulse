import PaperCore
import SwiftUI

struct MacFeedEditorDraft: Identifiable {
    var id = UUID()
    var feedID: UUID?
    var name: String
    var categoriesText: String
    var selectedLibraryKeywords: Set<String>
    var customKeywordsText: String
    var excludedKeywordsText: String
    var institutionsText: String
    var venuesText: String
    var dailyLimit: Int
    var lookbackDays: Int
    var enabledSources: Set<PaperSourceKind>

    init(feed: FeedConfig? = nil, keywordLibrary: [String] = []) {
        feedID = feed?.id
        name = feed?.name ?? ""
        categoriesText = feed?.categories.joined(separator: ", ") ?? "cs.AI, cs.CL"
        let keywords = feed?.keywords ?? []
        selectedLibraryKeywords = Set(keywords.filter { keywordLibrary.contains($0) })
        customKeywordsText = keywords.filter { !keywordLibrary.contains($0) }.joined(separator: ", ")
        excludedKeywordsText = feed?.excludedKeywords.joined(separator: ", ") ?? ""
        institutionsText = feed?.requiredInstitutions.joined(separator: ", ") ?? ""
        venuesText = feed?.requiredVenues.joined(separator: ", ") ?? ""
        dailyLimit = feed?.authorityPolicy.dailyLimit ?? 5
        lookbackDays = feed?.lookbackDays ?? 7
        enabledSources = Set(feed?.enabledSources ?? FeedConfig.defaultEnabledSources)
    }

    func makeFeed() -> FeedConfig {
        FeedConfig(
            id: feedID ?? UUID(),
            name: name.trimmed,
            categories: categoriesText.commaSeparated,
            keywords: Array(selectedLibraryKeywords).sorted() + customKeywordsText.commaSeparated,
            excludedKeywords: excludedKeywordsText.commaSeparated,
            requiredInstitutions: institutionsText.commaSeparated,
            requiredVenues: venuesText.commaSeparated,
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
        ZStack {
            MacBrandShellBackground()
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        MacBrandPageHeader(
                            icon: draft.feedID == nil ? "plus" : "slider.horizontal.3",
                            title: draft.feedID == nil ? language.text(en: "New Feed", zh: "新建订阅") : language.text(en: "Edit Feed", zh: "编辑订阅"),
                            subtitle: language.text(en: "Tune categories, keywords, authority requirements, and source mix.", zh: "配置分类、关键词、权威筛选与学术来源。")
                        )

                        editorSection(language.text(en: "Feed", zh: "订阅")) {
                            TextField(language.text(en: "Name", zh: "名称"), text: $draft.name)
                            TextField(language.text(en: "Categories", zh: "分类"), text: $draft.categoriesText)
                        }

                        editorSection(language.text(en: "Keywords (any match)", zh: "关键词（任一匹配）")) {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], alignment: .leading, spacing: 10) {
                                ForEach(appModel.keywordLibrary, id: \.self) { keyword in
                                    Toggle(keyword, isOn: keywordBinding(keyword))
                                        .toggleStyle(.checkbox)
                                }
                            }
                            TextField(language.text(en: "Custom keywords, comma separated", zh: "自定义关键词，逗号分隔"), text: $draft.customKeywordsText)
                        }

                        editorSection(language.text(en: "Requirements", zh: "筛选要求")) {
                            TextField(language.text(en: "Excluded keywords", zh: "排除关键词"), text: $draft.excludedKeywordsText)
                            TextField(language.text(en: "Institutions: Any", zh: "机构：任意"), text: $draft.institutionsText)
                            TextField(language.text(en: "Venues: Any", zh: "期刊或会议：任意"), text: $draft.venuesText)
                            Text(language.text(en: "Leave institutions or venues empty to keep the authority policy without adding a requirement.", zh: "机构或期刊/会议留空即为任意，不增加额外要求；仍会执行权威性判断。"))
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.70))
                        }

                        editorSection(language.text(en: "Sources", zh: "学术来源")) {
                            HStack(spacing: 18) {
                                ForEach([PaperSourceKind.arxiv, .openAlex, .crossref], id: \.self) { source in
                                    Toggle(source.editorTitle(language: language), isOn: sourceBinding(source))
                                        .toggleStyle(.checkbox)
                                }
                            }
                        }

                        editorSection(language.text(en: "Selection", zh: "筛选")) {
                            Stepper(language.text(en: "Papers per run: \(draft.dailyLimit)", zh: "每次篇数：\(draft.dailyLimit)"), value: $draft.dailyLimit, in: 1...20)
                            Stepper(language.text(en: "Look back: \(draft.lookbackDays) days", zh: "检索范围：\(draft.lookbackDays) 天"), value: $draft.lookbackDays, in: 1...30)
                        }
                    }
                    .padding(24)
                }

                HStack {
                    Button(language.text(en: "Cancel", zh: "取消")) { dismiss() }
                    Spacer()
                    Button(language.text(en: "Save Feed", zh: "保存订阅")) {
                        onSave(draft.makeFeed())
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(MacBrand.pulseRed)
                    .disabled(!canSave)
                }
                .padding(16)
                .background(Color.black.opacity(0.22))
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color.white.opacity(0.12))
                        .frame(height: 1)
                }
            }
        }
        .preferredColorScheme(.dark)
        .frame(width: 720, height: 700)
        .navigationTitle(draft.feedID == nil ? language.text(en: "New Feed", zh: "新建订阅") : language.text(en: "Edit Feed", zh: "编辑订阅"))
    }

    private var canSave: Bool {
        !draft.name.trimmed.isEmpty && (!draft.categoriesText.commaSeparated.isEmpty || !draft.selectedLibraryKeywords.isEmpty || !draft.customKeywordsText.commaSeparated.isEmpty) && !draft.enabledSources.isEmpty
    }

    private func sourceBinding(_ source: PaperSourceKind) -> Binding<Bool> {
        Binding(
            get: { draft.enabledSources.contains(source) },
            set: { enabled in
                if enabled { draft.enabledSources.insert(source) } else { draft.enabledSources.remove(source) }
            }
        )
    }

    private func keywordBinding(_ keyword: String) -> Binding<Bool> {
        Binding(
            get: { draft.selectedLibraryKeywords.contains(keyword) },
            set: { selected in
                if selected { draft.selectedLibraryKeywords.insert(keyword) }
                else { draft.selectedLibraryKeywords.remove(keyword) }
            }
        )
    }

    private func editorSection<Content: View>(_ title: String, @ViewBuilder content: @escaping () -> Content) -> some View {
        MacFormCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                content()
            }
        }
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
