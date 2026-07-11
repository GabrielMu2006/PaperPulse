import PaperCore
import XCTest
@testable import PaperPulse

final class ProfileStoreTests: XCTestCase {
    func testMacProfilesPersistIndependentlyAndDeleteOnlyMatchingKey() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let defaults = UserDefaults(suiteName: "PaperPulseMacTests.\(UUID().uuidString)")!
        let keychain = MacKeychainStore(service: "PaperPulseMacTests.\(UUID().uuidString)")
        let store = MacLLMProfileSettingsStore(userDefaults: defaults, keychain: keychain, directory: directory)
        let deepSeek = LLMProfile.preset(.deepSeek, apiKey: "deepseek-key")
        let gpt = LLMProfile.preset(.gpt, apiKey: "gpt-key")

        try store.saveProfiles([deepSeek, gpt])
        XCTAssertEqual(try store.loadProfiles(defaultProfiles: []).map(\.id), [deepSeek.id, gpt.id])
        XCTAssertEqual(try keychain.load(account: "llmProfile.\(deepSeek.id.uuidString)"), "deepseek-key")
        XCTAssertEqual(try keychain.load(account: "llmProfile.\(gpt.id.uuidString)"), "gpt-key")

        try store.deleteProfile(deepSeek)
        XCTAssertEqual(try store.loadProfiles(defaultProfiles: []).map(\.id), [gpt.id])
        XCTAssertNil(try keychain.load(account: "llmProfile.\(deepSeek.id.uuidString)"))
        XCTAssertEqual(try keychain.load(account: "llmProfile.\(gpt.id.uuidString)"), "gpt-key")
    }
}
