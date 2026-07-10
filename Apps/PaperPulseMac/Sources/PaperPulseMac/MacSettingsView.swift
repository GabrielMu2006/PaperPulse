import PaperCore
import SwiftUI

struct MacSettingsView: View {
    @Environment(PaperPulseMacModel.self) private var appModel
    @State private var apiKey = ""

    var body: some View {
        @Bindable var appModel = appModel
        let language = appModel.appLanguage

        Form {
            Section(language.text(en: "Default Feed", zh: "默认订阅")) {
                TextField(language.text(en: "Name", zh: "名称"), text: Binding(
                    get: { appModel.feed.name },
                    set: { appModel.feed.name = $0 }
                ))
                TextField(language.text(en: "Keywords", zh: "关键词"), text: Binding(
                    get: { appModel.feed.keywords.joined(separator: ", ") },
                    set: { appModel.feed.keywords = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } }
                ))
            }

            Section(language.text(en: "LLM Provider", zh: "大模型服务")) {
                Text(language.text(
                    en: "App Language controls the app interface: tabs, buttons, titles, and hints.",
                    zh: "界面语言：切换 App 的标签、按钮、标题和提示文字。"
                ))
                .foregroundStyle(.secondary)
                Picker(language.text(en: "App Language", zh: "界面语言"), selection: $appModel.appLanguage) {
                    ForEach(AppLanguage.allCases) { appLanguage in
                        Text(appLanguage.displayName).tag(appLanguage)
                    }
                }
                .onChange(of: appModel.appLanguage) { _, newValue in
                    appModel.saveAppLanguage(newValue)
                }

                Text(language.text(
                    en: "Summary Language controls paper summaries and full paper explanations.",
                    zh: "简介语言：切换论文短简介和完整解读的输出语言。"
                ))
                .foregroundStyle(.secondary)
                Picker(language.text(en: "Summary Language", zh: "简介语言"), selection: $appModel.summaryLanguage) {
                    ForEach(SummaryLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .onChange(of: appModel.summaryLanguage) { _, newValue in
                    appModel.saveSummaryLanguage(newValue)
                }

                Picker(language.text(en: "Provider", zh: "服务商"), selection: $appModel.llmProfile.providerKind) {
                    ForEach(LLMProviderKind.allCases) { kind in
                        Text(kind.displayName).tag(kind)
                    }
                }
                .onChange(of: appModel.llmProfile.providerKind) { _, newValue in
                    appModel.applyProviderPreset(newValue)
                }

                Picker(language.text(en: "API Style", zh: "API 格式"), selection: $appModel.llmProfile.apiStyle) {
                    ForEach(LLMAPIStyle.allCases) { style in
                        Text(style.displayName).tag(style)
                    }
                }

                TextField(language.text(en: "Base URL", zh: "Base URL"), text: Binding(
                    get: { appModel.llmProfile.baseURL.absoluteString },
                    set: { value in
                        if let url = URL(string: value) {
                            appModel.llmProfile = appModel.llmProfile.withBaseURL(url)
                        }
                    }
                ))
                TextField(language.text(en: "Model", zh: "模型"), text: $appModel.llmProfile.model)
                SecureField(language.text(en: "API Key", zh: "API Key"), text: $apiKey)
                Button(language.text(en: "Save Provider Settings", zh: "保存模型设置")) {
                    appModel.saveLLMProfile(apiKey: apiKey)
                }
                Text(language.text(
                    en: "For Claude/Gemini/GPT/DeepSeek relay services, choose API Style = OpenAI-compatible, then enter the relay Base URL and provider model name.",
                    zh: "Claude、Gemini、GPT、DeepSeek 或中转站可选择 OpenAI-compatible，然后填写 Base URL 和模型名。"
                ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(language.text(en: "Scheduling", zh: "定时")) {
                Text(language.text(
                    en: "macOS scheduling will use a LaunchAgent helper that invokes the app pipeline, not the legacy Codex automation.",
                    zh: "macOS 定时将使用 LaunchAgent 调用 App 流程，而不是旧自动化脚本。"
                ))
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 520)
        .onAppear {
            apiKey = appModel.llmProfile.apiKey
        }
    }
}
