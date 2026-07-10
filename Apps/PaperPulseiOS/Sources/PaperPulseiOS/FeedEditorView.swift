import PaperCore
import SwiftUI

struct FeedEditorDraft: Identifiable, Hashable {
    var id = UUID()
    var feedID: UUID?
    var name: String
    var categoriesText: String
    var keywordsText: String
    var excludedKeywordsText: String
    var dailyLimit: Int
    var enableWebAugmentation: Bool
    var searchProviderProfileID: UUID?
    var rerankProviderProfileID: UUID?
    var shortSummaryProviderProfileID: UUID?
    var fullSummaryProviderProfileID: UUID?
    var extractionProviderProfileID: UUID?

    init(feed: FeedConfig? = nil) {
        feedID = feed?.id
        name = feed?.name ?? ""
        categoriesText = feed?.categories.joined(separator: ", ") ?? "cs.AI, cs.CL"
        keywordsText = feed?.keywords.joined(separator: ", ") ?? ""
        excludedKeywordsText = feed?.excludedKeywords.joined(separator: ", ") ?? ""
        dailyLimit = feed?.authorityPolicy.dailyLimit ?? 5
        enableWebAugmentation = feed?.enableWebAugmentation ?? false
        searchProviderProfileID = feed?.searchProviderProfileID
        rerankProviderProfileID = feed?.rerankProviderProfileID
        shortSummaryProviderProfileID = feed?.shortSummaryProviderProfileID
        fullSummaryProviderProfileID = feed?.fullSummaryProviderProfileID
        extractionProviderProfileID = feed?.extractionProviderProfileID
    }
}

struct FeedEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PaperPulseAppModel.self) private var appModel
    @State private var draft: FeedEditorDraft
    var onSave: (FeedConfig) -> Void

    init(draft: FeedEditorDraft, onSave: @escaping (FeedConfig) -> Void) {
        _draft = State(initialValue: draft)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(appModel.appLanguage.text(en: "Feed", zh: "订阅")) {
                    TextField(appModel.appLanguage.text(en: "Name", zh: "名称"), text: $draft.name)
                        .textInputAutocapitalization(.words)

                    TextField(appModel.appLanguage.text(en: "arXiv categories", zh: "arXiv 分类"), text: $draft.categoriesText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    TextField(appModel.appLanguage.text(en: "Keywords", zh: "关键词"), text: $draft.keywordsText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    TextField(appModel.appLanguage.text(en: "Excluded keywords", zh: "排除关键词"), text: $draft.excludedKeywordsText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section(appModel.appLanguage.text(en: "Selection", zh: "筛选")) {
                    Stepper(appModel.appLanguage.text(en: "Daily limit: \(draft.dailyLimit)", zh: "每日数量：\(draft.dailyLimit)"), value: $draft.dailyLimit, in: 1...20)
                    Toggle(appModel.appLanguage.text(en: "Use web augmentation when academic APIs are sparse", zh: "学术源结果不足时使用联网补充"), isOn: $draft.enableWebAugmentation)
                }

                Section(appModel.appLanguage.text(en: "Provider Roles", zh: "模型角色")) {
                    profilePicker(appModel.appLanguage.text(en: "Search", zh: "搜索"), selection: $draft.searchProviderProfileID)
                    profilePicker(appModel.appLanguage.text(en: "Rerank", zh: "重排"), selection: $draft.rerankProviderProfileID)
                    profilePicker(appModel.appLanguage.text(en: "Short Summary", zh: "短简介"), selection: $draft.shortSummaryProviderProfileID)
                    profilePicker(appModel.appLanguage.text(en: "Full Summary", zh: "完整简介"), selection: $draft.fullSummaryProviderProfileID)
                    profilePicker(appModel.appLanguage.text(en: "Cloud Extraction", zh: "云端抽取"), selection: $draft.extractionProviderProfileID)
                }

                Section {
                    Text(appModel.appLanguage.text(en: "Separate categories and keywords with commas. Example categories: cs.AI, cs.CL, cs.LG, cs.RO, stat.ML.", zh: "分类和关键词请用英文逗号分隔，例如：cs.AI、cs.CL、cs.LG、cs.RO、stat.ML。"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(draft.feedID == nil ? appModel.appLanguage.text(en: "New Feed", zh: "新建订阅") : appModel.appLanguage.text(en: "Edit Feed", zh: "编辑订阅"))
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(Color(.secondarySystemBackground))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(appModel.appLanguage.text(en: "Cancel", zh: "取消")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(appModel.appLanguage.text(en: "Save", zh: "保存")) {
                        onSave(feedConfig)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        !draft.name.cleanedInput.isEmpty && (!parsedCategories.isEmpty || !parsedKeywords.isEmpty)
    }

    private var feedConfig: FeedConfig {
        FeedConfig(
            id: draft.feedID ?? UUID(),
            name: draft.name.cleanedInput,
            categories: parsedCategories,
            keywords: parsedKeywords,
            excludedKeywords: parsedExcludedKeywords,
            authorityPolicy: AuthorityPolicy(dailyLimit: draft.dailyLimit),
            enableWebAugmentation: draft.enableWebAugmentation,
            searchProviderProfileID: draft.searchProviderProfileID,
            rerankProviderProfileID: draft.rerankProviderProfileID,
            shortSummaryProviderProfileID: draft.shortSummaryProviderProfileID,
            fullSummaryProviderProfileID: draft.fullSummaryProviderProfileID,
            extractionProviderProfileID: draft.extractionProviderProfileID
        )
    }

    private func profilePicker(_ title: String, selection: Binding<UUID?>) -> some View {
        Picker(title, selection: selection) {
            Text(appModel.appLanguage.text(en: "Use default", zh: "使用默认配置")).tag(UUID?.none)
            ForEach(appModel.providerProfiles) { profile in
                Text(profile.name).tag(Optional(profile.id))
            }
        }
    }

    private var parsedCategories: [String] {
        draft.categoriesText.commaSeparatedValues
    }

    private var parsedKeywords: [String] {
        draft.keywordsText.commaSeparatedValues
    }

    private var parsedExcludedKeywords: [String] {
        draft.excludedKeywordsText.commaSeparatedValues
    }
}

private extension String {
    var commaSeparatedValues: [String] {
        split(separator: ",")
            .map { String($0).cleanedInput }
            .filter { !$0.isEmpty }
    }

    var cleanedInput: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
