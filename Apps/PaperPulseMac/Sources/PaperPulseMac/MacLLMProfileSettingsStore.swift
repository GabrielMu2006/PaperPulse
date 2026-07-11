import Foundation
import PaperCore

struct MacLLMProfileSettingsStore {
    static let standard = MacLLMProfileSettingsStore()

    var userDefaults: UserDefaults
    var keychain: MacKeychainStore
    var directory: URL?

    private let configurationKey = "PaperPulse.llmProfileConfiguration"
    private let keychainAccountPrefix = "llmProfile"

    init(
        userDefaults: UserDefaults = .standard,
        keychain: MacKeychainStore = .standard,
        directory: URL? = nil
    ) {
        self.userDefaults = userDefaults
        self.keychain = keychain
        self.directory = directory
    }

    func loadProfile(defaultProfile: LLMProfile) -> LLMProfile {
        guard let data = userDefaults.data(forKey: configurationKey),
              let configuration = try? JSONDecoder().decode(LLMProfileConfiguration.self, from: data) else {
            return defaultProfile.withAPIKey(loadLegacyAPIKey(for: defaultProfile) ?? defaultProfile.apiKey)
        }

        let apiKey = loadAPIKey(for: configuration) ?? loadLegacyAPIKey(for: configuration) ?? ""
        return configuration.profile(apiKey: apiKey)
    }

    func save(_ profile: LLMProfile) throws {
        try saveProfiles([profile])
    }

    func loadProfiles(defaultProfiles: [LLMProfile]) throws -> [LLMProfile] {
        let configurations = try profileFileStore().loadConfigurations()
        if !configurations.isEmpty {
            return configurations.map { $0.profile(apiKey: loadAPIKey(for: $0) ?? "") }
        }

        let legacy = loadProfile(defaultProfile: defaultProfiles.first ?? LLMProfile.preset(.gpt))
        let profiles = defaultProfiles.isEmpty ? [] : [legacy]
        if !profiles.isEmpty { try saveProfiles(profiles) }
        return profiles
    }

    func saveProfiles(_ profiles: [LLMProfile]) throws {
        let fileStore = profileFileStore()
        let configurations = profiles.map(\.persistedConfiguration)
        let retainedIDs = Set(configurations.map(\.id))
        for existing in try fileStore.loadConfigurations() where !retainedIDs.contains(existing.id) {
            try fileStore.delete(existing)
            try keychain.delete(account: apiKeyAccount(for: existing))
        }
        for profile in profiles {
            try fileStore.save(profile.persistedConfiguration)
            try keychain.save(profile.apiKey, account: apiKeyAccount(for: profile.persistedConfiguration))
        }
        userDefaults.removeObject(forKey: configurationKey)
    }

    func deleteProfile(_ profile: LLMProfile) throws {
        try profileFileStore().delete(profile.persistedConfiguration)
        try keychain.delete(account: apiKeyAccount(for: profile.persistedConfiguration))
    }

    private func loadAPIKey(for configuration: LLMProfileConfiguration) -> String? {
        try? keychain.load(account: apiKeyAccount(for: configuration))
    }

    private func loadLegacyAPIKey(for profile: LLMProfile) -> String? {
        try? keychain.load(account: profile.name)
    }

    private func loadLegacyAPIKey(for configuration: LLMProfileConfiguration) -> String? {
        try? keychain.load(account: configuration.name)
    }

    private func apiKeyAccount(for configuration: LLMProfileConfiguration) -> String {
        "\(keychainAccountPrefix).\(configuration.id.uuidString)"
    }

    private func profileFileStore() -> LLMProfileFileStore {
        let base = directory ?? ((try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? FileManager.default.temporaryDirectory.appendingPathComponent("PaperPulse"))
        return LLMProfileFileStore(directory: base
            .appendingPathComponent("PaperPulse", isDirectory: true)
            .appendingPathComponent("macOS", isDirectory: true)
            .appendingPathComponent("Model Configs", isDirectory: true))
    }
}
