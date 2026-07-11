import PaperCore
import SwiftUI

struct MacSettingsView: View {
    @Environment(PaperPulseMacModel.self) private var appModel
    @State private var apiKey = ""

    var body: some View {
        @Bindable var appModel = appModel
        let language = appModel.appLanguage

        Form {
            Section(language.text(en: "Language", zh: "语言")) {
                Picker(language.text(en: "App Language", zh: "界面语言"), selection: $appModel.appLanguage) {
                    ForEach(AppLanguage.allCases) { Text($0.displayName).tag($0) }
                }
                .onChange(of: appModel.appLanguage) { _, value in appModel.saveAppLanguage(value) }

                Picker(language.text(en: "Summary Language", zh: "简介语言"), selection: $appModel.summaryLanguage) {
                    ForEach(SummaryLanguage.allCases) { Text($0.displayName).tag($0) }
                }
                .onChange(of: appModel.summaryLanguage) { _, value in appModel.saveSummaryLanguage(value) }
            }

            Section(language.text(en: "Model Configurations", zh: "模型配置")) {
                Picker(language.text(en: "Current Configuration", zh: "当前配置"), selection: Binding(
                    get: { appModel.llmProfile.id },
                    set: { appModel.selectLLMProfile($0); apiKey = appModel.llmProfile.apiKey }
                )) {
                    ForEach(appModel.providerProfiles) { Text($0.name).tag($0.id) }
                }

                HStack {
                    Menu {
                        ForEach(LLMProviderKind.allCases) { kind in
                            Button(kind.displayName) { appModel.addLLMProfile(kind: kind); apiKey = "" }
                        }
                    } label: {
                        Label(language.text(en: "New Configuration", zh: "新建配置"), systemImage: "plus")
                    }
                    Button(role: .destructive) { appModel.deleteLLMProfile(); apiKey = appModel.llmProfile.apiKey } label: {
                        Label(language.text(en: "Delete", zh: "删除"), systemImage: "trash")
                    }
                    .disabled(appModel.providerProfiles.count <= 1)
                }

                Picker(language.text(en: "Provider", zh: "服务商"), selection: $appModel.llmProfile.providerKind) {
                    ForEach(LLMProviderKind.allCases) { Text($0.displayName).tag($0) }
                }
                .onChange(of: appModel.llmProfile.providerKind) { _, value in appModel.applyProviderPreset(value) }

                Picker(language.text(en: "API Style", zh: "API 格式"), selection: $appModel.llmProfile.apiStyle) {
                    ForEach(LLMAPIStyle.allCases) { Text($0.displayName).tag($0) }
                }
                TextField(language.text(en: "Base URL", zh: "Base URL"), text: Binding(
                    get: { appModel.llmProfile.baseURL.absoluteString },
                    set: { if let url = URL(string: $0) { appModel.llmProfile = appModel.llmProfile.withBaseURL(url) } }
                ))
                TextField(language.text(en: "Model", zh: "模型"), text: $appModel.llmProfile.model)
                SecureField(language.text(en: "API Key", zh: "API Key"), text: $apiKey)
                Button(language.text(en: "Save Configuration", zh: "保存配置")) {
                    appModel.saveLLMProfile(apiKey: apiKey)
                }
                Text(language.text(en: "API keys stay in this Mac's Keychain. Claude, Gemini, GPT, DeepSeek, and compatible relays can use a custom Base URL.", zh: "API Key 仅保存在本机 Keychain。Claude、Gemini、GPT、DeepSeek 和兼容中转站均可填写自定义 Base URL。"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !appModel.status.isEmpty {
                Section { Text(appModel.status).foregroundStyle(.secondary) }
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 560)
        .onAppear { apiKey = appModel.llmProfile.apiKey }
    }
}
