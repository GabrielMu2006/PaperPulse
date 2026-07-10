import Foundation
import PaperCore

struct LLMProfileSettingsStore {
    static let standard = LLMProfileSettingsStore()

    var userDefaults: UserDefaults = .standard
    var keychain: KeychainStore = .standard

    private let configurationKey = "PaperPulse.llmProfileConfiguration"
    private let keychainAccountPrefix = "llmProfile"

    func loadProfile(defaultProfile: LLMProfile) -> LLMProfile {
        guard let data = userDefaults.data(forKey: configurationKey),
              let configuration = try? JSONDecoder().decode(LLMProfileConfiguration.self, from: data) else {
            return defaultProfile.withAPIKey(loadLegacyAPIKey(for: defaultProfile) ?? defaultProfile.apiKey)
        }

        let apiKey = loadAPIKey(for: configuration) ?? loadLegacyAPIKey(for: configuration) ?? ""
        return configuration.profile(apiKey: apiKey)
    }

    func save(_ profile: LLMProfile) throws {
        let configuration = profile.persistedConfiguration
        let data = try JSONEncoder().encode(configuration)
        userDefaults.set(data, forKey: configurationKey)
        try keychain.save(profile.apiKey, account: apiKeyAccount(for: configuration))
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
