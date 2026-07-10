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
        guard let data = userDefaults.data(forKey: configurationsKey),
              let configurations = try? JSONDecoder().decode([LLMProfileConfiguration].self, from: data) else {
            return [loadProfile(defaultProfile: defaultProfiles.first ?? LLMProfile.preset(.gpt))]
        }
        return configurations.map { configuration in
            configuration.profile(apiKey: loadAPIKey(for: configuration) ?? "")
        }
    }

    func save(_ profile: LLMProfile) throws {
        try saveProfiles([profile])
    }

    func saveProfiles(_ profiles: [LLMProfile]) throws {
        let configurations = profiles.map(\.persistedConfiguration)
        userDefaults.set(try JSONEncoder().encode(configurations), forKey: configurationsKey)
        for profile in profiles {
            try keychain.save(profile.apiKey, account: apiKeyAccount(for: profile.persistedConfiguration))
        }

        if let first = profiles.first {
            let configuration = first.persistedConfiguration
            userDefaults.set(try JSONEncoder().encode(configuration), forKey: configurationKey)
        }
    }

    func deleteAPIKey(for profile: LLMProfile) throws {
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
}
