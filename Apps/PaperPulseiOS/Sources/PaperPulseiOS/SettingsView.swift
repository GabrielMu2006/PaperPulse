import PaperCore
import SwiftUI

struct SettingsView: View {
    @Environment(PaperPulseAppModel.self) private var appModel
    @State private var apiKey = ""
    @State private var notificationStatus = ""
    @State private var showDeleteConfirmation = false

    var body: some View {
        @Bindable var appModel = appModel
        let language = appModel.appLanguage

        NavigationStack {
            PaperPulseScreen(title: language.text(en: "Settings", zh: "设置")) {
                profileLibrary(language: language)
                profileEditor(language: language, appModel: $appModel)
                preferences(language: language, appModel: $appModel)
                notificationSettings(language: language)
                schedulingNotice(language: language)
            }
        }
        .onAppear { apiKey = appModel.llmProfile.apiKey }
        .onChange(of: appModel.llmProfile.id) { _, _ in
            apiKey = appModel.llmProfile.apiKey
        }
        .confirmationDialog(
            language.text(en: "Delete this model configuration?", zh: "删除这个模型配置？"),
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(language.text(en: "Delete", zh: "删除"), role: .destructive) {
                appModel.deleteLLMProfile()
            }
            Button(language.text(en: "Cancel", zh: "取消"), role: .cancel) {}
        } message: {
            Text(language.text(
                en: "The local configuration file and its Keychain API key will be removed.",
                zh: "将删除本地配置文件和对应的 Keychain API Key。"
            ))
        }
    }

    private func profileLibrary(language: AppLanguage) -> some View {
        PaperPulseCard {
            Text(language.text(en: "Model Configurations", zh: "模型配置"))
                .font(.headline)

            HStack {
                Text(language.text(en: "Current", zh: "当前配置"))
                Spacer()
                Picker("", selection: Binding(
                    get: { appModel.llmProfile.id },
                    set: { appModel.selectLLMProfile(id: $0) }
                )) {
                    ForEach(appModel.providerProfiles) { profile in
                        Text(profile.name).tag(profile.id)
                    }
                }
                .labelsHidden()
            }

            HStack(spacing: 16) {
                Menu {
                    ForEach(LLMProviderKind.allCases) { kind in
                        Button(kind.displayName) { appModel.addLLMProfile(kind: kind) }
                    }
                } label: {
                    Label(language.text(en: "New", zh: "新建"), systemImage: "plus")
                }

                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label(language.text(en: "Delete", zh: "删除"), systemImage: "trash")
                }
                .disabled(appModel.providerProfiles.count <= 1)
            }

            Text(language.text(
                en: "Each model configuration is saved as its own local file. API keys stay in Keychain.",
                zh: "每个模型配置各自保存为本地文件；API Key 只保存在 Keychain。"
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private func profileEditor(language: AppLanguage, appModel: Bindable<PaperPulseAppModel>) -> some View {
        PaperPulseCard {
            Text(language.text(en: "Edit Current Configuration", zh: "编辑当前配置"))
                .font(.headline)

            Picker(language.text(en: "Provider", zh: "服务商"), selection: appModel.llmProfile.providerKind) {
                ForEach(LLMProviderKind.allCases) { kind in
                    Text(kind.displayName).tag(kind)
                }
            }
            .onChange(of: self.appModel.llmProfile.providerKind) { _, newValue in
                self.appModel.applyProviderPreset(newValue)
                apiKey = self.appModel.llmProfile.apiKey
            }

            Picker(language.text(en: "API Style", zh: "API 格式"), selection: appModel.llmProfile.apiStyle) {
                ForEach(LLMAPIStyle.allCases) { style in
                    Text(style.displayName).tag(style)
                }
            }

            TextField(language.text(en: "Base URL", zh: "Base URL"), text: Binding(
                get: { self.appModel.llmProfile.baseURL.absoluteString },
                set: { value in
                    if let url = URL(string: value) {
                        self.appModel.llmProfile = self.appModel.llmProfile.withBaseURL(url)
                    }
                }
            ))
            .textInputAutocapitalization(.never)
            .keyboardType(.URL)
            .textFieldStyle(.roundedBorder)

            TextField(language.text(en: "Model Name", zh: "模型名称"), text: appModel.llmProfile.model)
                .textInputAutocapitalization(.never)
                .textFieldStyle(.roundedBorder)

            SecureField(language.text(en: "API Key", zh: "API Key"), text: $apiKey)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button(language.text(en: "Save", zh: "保存")) {
                    self.appModel.saveLLMProfile(apiKey: apiKey)
                }
                .buttonStyle(.bordered)

                Button(language.text(en: "Test API", zh: "测试 API")) {
                    self.appModel.saveLLMProfile(apiKey: apiKey)
                    Task { await self.appModel.testLLMProvider(apiKey: apiKey) }
                }
                .buttonStyle(.borderedProminent)
            }

            if let providerTestMessage = self.appModel.providerTestMessage {
                Text(providerTestMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let providerSettingsMessage = self.appModel.providerSettingsMessage {
                Text(providerSettingsMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func preferences(language: AppLanguage, appModel: Bindable<PaperPulseAppModel>) -> some View {
        PaperPulseCard {
            Text(language.text(en: "Preferences", zh: "偏好设置"))
                .font(.headline)

            Picker(language.text(en: "App Language", zh: "界面语言"), selection: appModel.appLanguage) {
                ForEach(AppLanguage.allCases) { appLanguage in
                    Text(appLanguage.displayName).tag(appLanguage)
                }
            }
            .onChange(of: self.appModel.appLanguage) { _, newValue in
                self.appModel.saveAppLanguage(newValue)
            }

            Picker(language.text(en: "Summary Language", zh: "简介语言"), selection: appModel.summaryLanguage) {
                ForEach(SummaryLanguage.allCases) { outputLanguage in
                    Text(outputLanguage.displayName).tag(outputLanguage)
                }
            }
            .onChange(of: self.appModel.summaryLanguage) { _, newValue in
                self.appModel.saveSummaryLanguage(newValue)
            }
        }
    }

    private func notificationSettings(language: AppLanguage) -> some View {
        PaperPulseCard {
            Text(language.text(en: "Notifications", zh: "通知"))
                .font(.headline)
            if !notificationStatus.isEmpty {
                Text(notificationStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Button(language.text(en: "Enable Notifications", zh: "开启通知")) {
                Task {
                    let granted = await NotificationCoordinator.shared.requestAuthorization()
                    notificationStatus = granted
                        ? language.text(en: "Enabled", zh: "已开启")
                        : language.text(en: "Not enabled", zh: "未开启")
                }
            }
        }
    }

    private func schedulingNotice(language: AppLanguage) -> some View {
        PaperPulseCard {
            Text(language.text(en: "Scheduling", zh: "定时"))
                .font(.headline)
            Text(language.text(
                en: "iOS background refresh is best-effort. Exact delivery times need the optional cloud scheduler.",
                zh: "iOS 后台刷新是尽力执行；精确定时需要后续可选的云端调度。"
            ))
            .foregroundStyle(.secondary)
        }
    }
}
