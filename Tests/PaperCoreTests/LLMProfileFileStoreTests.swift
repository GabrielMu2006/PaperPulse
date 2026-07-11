import Foundation
import XCTest
@testable import PaperCore

final class LLMProfileFileStoreTests: XCTestCase {
    func testStoreWritesOneConfigurationFilePerModelWithoutAPIKeys() throws {
        let directory = try makeDirectory()
        let first = LLMProfile.preset(.deepSeek, apiKey: "deepseek-secret").withModel("deepseek-v4-flash")
        let second = LLMProfile.preset(.gpt, apiKey: "openai-secret").withModel("gpt-5.5")
        let store = LLMProfileFileStore(directory: directory)

        try store.save(first.persistedConfiguration)
        try store.save(second.persistedConfiguration)

        let filenames = try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted()
        XCTAssertEqual(filenames.count, 2)
        XCTAssertTrue(filenames.contains { $0.hasPrefix("deepseek-v4-flash-") })
        XCTAssertTrue(filenames.contains { $0.hasPrefix("gpt-5.5-") })
        let payload = try filenames.map { try String(contentsOf: directory.appendingPathComponent($0)) }.joined(separator: "\n")
        XCTAssertFalse(payload.contains("deepseek-secret"))
        XCTAssertFalse(payload.contains("openai-secret"))
        XCTAssertEqual(try store.loadConfigurations().map(\.model), ["deepseek-v4-flash", "gpt-5.5"])
    }

    func testSaveReplacesOldFilenameWhenProfileModelChangesAndDeleteRemovesIt() throws {
        let directory = try makeDirectory()
        let id = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let store = LLMProfileFileStore(directory: directory)
        let original = LLMProfile(
            id: id,
            name: "old-model",
            baseURL: URL(string: "https://api.example.com/v1")!,
            model: "old-model",
            apiKey: "",
            capabilities: [.shortSummary]
        )
        var renamed = original
        renamed.model = "new-model"
        renamed.name = "new-model"

        try store.save(original.persistedConfiguration)
        try store.save(renamed.persistedConfiguration)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path), ["new-model-\(id.uuidString.lowercased()).json"])

        try store.delete(renamed.persistedConfiguration)
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty)
    }

    private func makeDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
