import Foundation
import PaperCore

struct LLMProfileSettingsStore {
    static let standard = LLMProfileSettingsStore()

    var userDefaults: UserDefaults = .standard
    var keychain: KeychainStore = .standard

    private let configurationKey = "PaperPulse.llmProfileConfiguration"
    private let configurationsKey = "PaperPulse.llmProfileConfigurations"
    private let keychainAccountPrefix = "llmProfile"

    func loadProfile(defaultProfile: LLMProfile) -> LLMProfile {
        guard let data = userDefaults.data(forKey: configurationKey),
              let configuration = try? JSONDecoder().decode(LLMProfileConfiguration.self, from: data) else {
            return defaultProfile.withAPIKey(loadLegacyAPIKey(for: defaultProfile) ?? defaultProfile.apiKey)
        }

        let apiKey = loadAPIKey(for: configuration) ?? loadLegacyAPIKey(for: configuration) ?? ""
        return configuration.profile(apiKey: apiKey)
    }

    func loadProfiles(defaultProfiles: [LLMProfile]) -> [LLMProfile] {
        let fileStore = profileFileStore()
        if let configurations = try? fileStore.loadConfigurations(), !configurations.isEmpty {
            return configurations.map { configuration in
                configuration.profile(apiKey: loadAPIKey(for: configuration) ?? "")
            }
        }

        let legacyProfiles = legacyProfiles(defaultProfiles: defaultProfiles)
        if !legacyProfiles.isEmpty {
            try? saveProfiles(legacyProfiles)
        }
        return legacyProfiles
    }

    func save(_ profile: LLMProfile) throws {
        try saveProfiles([profile])
    }

    func saveProfiles(_ profiles: [LLMProfile]) throws {
        let fileStore = profileFileStore()
        let configurations = profiles.map(\.persistedConfiguration)
        let retainedIDs = Set(configurations.map(\.id))
        for existing in try fileStore.loadConfigurations() where !retainedIDs.contains(existing.id) {
            try fileStore.delete(existing)
            try keychain.delete(account: apiKeyAccount(for: existing))
        }
        for configuration in configurations {
            try fileStore.save(configuration)
        }
        for profile in profiles {
            try keychain.save(profile.apiKey, account: apiKeyAccount(for: profile.persistedConfiguration))
        }
        userDefaults.removeObject(forKey: configurationKey)
        userDefaults.removeObject(forKey: configurationsKey)
    }

    func deleteProfile(_ profile: LLMProfile) throws {
        try profileFileStore().delete(profile.persistedConfiguration)
        try keychain.delete(account: apiKeyAccount(for: profile.persistedConfiguration))
    }

    private func legacyProfiles(defaultProfiles: [LLMProfile]) -> [LLMProfile] {
        if let data = userDefaults.data(forKey: configurationsKey),
           let configurations = try? JSONDecoder().decode([LLMProfileConfiguration].self, from: data) {
            return configurations.map { configuration in
                configuration.profile(apiKey: loadAPIKey(for: configuration) ?? loadLegacyAPIKey(for: configuration) ?? "")
            }
        }
        return [loadProfile(defaultProfile: defaultProfiles.first ?? LLMProfile.preset(.gpt))]
    }

    private func profileFileStore() -> LLMProfileFileStore {
        let base = (try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? FileManager.default.temporaryDirectory
        return LLMProfileFileStore(
            directory: base.appendingPathComponent("PaperPulse/Model Configs", isDirectory: true)
        )
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
}
