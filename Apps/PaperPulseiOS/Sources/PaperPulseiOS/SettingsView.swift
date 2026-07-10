import PaperCore
import SwiftUI

struct SettingsView: View {
    @Environment(PaperPulseAppModel.self) private var appModel
    @State private var apiKey = ""
    @State private var notificationStatus = "Not configured"

    var body: some View {
        @Bindable var appModel = appModel
        let language = appModel.appLanguage

        NavigationStack {
            PaperPulseScreen(title: language.text(en: "Settings", zh: "设置")) {
                PaperPulseCard {
                    Text(language.text(en: "LLM Provider", zh: "大模型服务"))
                        .font(.headline)

                    Text(language.text(
                        en: "App Language controls the app interface: tabs, buttons, titles, and hints.",
                        zh: "界面语言：切换 App 的标签、按钮、标题和提示文字。"
                    ))
                    .font(.caption)
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
                    .font(.caption)
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
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .textFieldStyle(.roundedBorder)

                    TextField(language.text(en: "Model", zh: "模型"), text: $appModel.llmProfile.model)
                        .textInputAutocapitalization(.never)
                        .textFieldStyle(.roundedBorder)

                    SecureField(language.text(en: "API Key", zh: "API Key"), text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                    Button(language.text(en: "Save Provider Settings", zh: "保存模型设置")) {
                        appModel.saveLLMProfile(apiKey: apiKey)
                    }
                    Button(language.text(en: "Test API", zh: "测试 API")) {
                        appModel.saveLLMProfile(apiKey: apiKey)
                        Task {
                            await appModel.testLLMProvider(apiKey: apiKey)
                        }
                    }
                    .buttonStyle(.borderedProminent)

                    if let providerTestMessage = appModel.providerTestMessage {
                        Text(providerTestMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let providerSettingsMessage = appModel.providerSettingsMessage {
                        Text(providerSettingsMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text(language.text(
                        en: "For Claude/Gemini/GPT/DeepSeek relay services, choose API Style = OpenAI-compatible, then enter the relay Base URL and provider model name.",
                        zh: "Claude、Gemini、GPT、DeepSeek 或中转站可选择 OpenAI-compatible，然后填写 Base URL 和模型名。"
                    ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                PaperPulseCard {
                    Text(language.text(en: "Notifications", zh: "通知"))
                        .font(.headline)
                    Text(notificationStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button(language.text(en: "Enable Notifications", zh: "开启通知")) {
                        Task {
                            let granted = await NotificationCoordinator.shared.requestAuthorization()
                            notificationStatus = granted ? "Enabled" : "Not enabled"
                        }
                    }
                }

                PaperPulseCard {
                    Text(language.text(en: "Scheduling", zh: "定时"))
                        .font(.headline)
                    Text(language.text(
                        en: "iOS background refresh is best-effort. Enable the optional cloud scheduler later for exact delivery times.",
                        zh: "iOS 后台刷新是尽力执行；如果需要精确定时，后续可启用云端调度。"
                    ))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onAppear {
            apiKey = appModel.llmProfile.apiKey
        }
    }
}
