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

    init(feed: FeedConfig? = nil) {
        feedID = feed?.id
        name = feed?.name ?? ""
        categoriesText = feed?.categories.joined(separator: ", ") ?? "cs.AI, cs.CL"
        keywordsText = feed?.keywords.joined(separator: ", ") ?? ""
        excludedKeywordsText = feed?.excludedKeywords.joined(separator: ", ") ?? ""
        dailyLimit = feed?.authorityPolicy.dailyLimit ?? 5
        enableWebAugmentation = feed?.enableWebAugmentation ?? false
    }
}

struct FeedEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: FeedEditorDraft
    var onSave: (FeedConfig) -> Void

    init(draft: FeedEditorDraft, onSave: @escaping (FeedConfig) -> Void) {
        _draft = State(initialValue: draft)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Feed") {
                    TextField("Name", text: $draft.name)
                        .textInputAutocapitalization(.words)

                    TextField("arXiv categories", text: $draft.categoriesText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    TextField("Keywords", text: $draft.keywordsText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    TextField("Excluded keywords", text: $draft.excludedKeywordsText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section("Selection") {
                    Stepper("Daily limit: \(draft.dailyLimit)", value: $draft.dailyLimit, in: 1...20)
                    Toggle("Use web augmentation when academic APIs are sparse", isOn: $draft.enableWebAugmentation)
                }

                Section {
                    Text("Separate categories and keywords with commas. Example categories: cs.AI, cs.CL, cs.LG, cs.RO, stat.ML.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(draft.feedID == nil ? "New Feed" : "Edit Feed")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(Color(.secondarySystemBackground))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
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
            enableWebAugmentation: draft.enableWebAugmentation
        )
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
