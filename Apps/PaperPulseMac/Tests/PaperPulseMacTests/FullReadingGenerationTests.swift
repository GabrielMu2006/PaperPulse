import PaperCore
import SwiftData
import XCTest
@testable import PaperPulse

@MainActor
final class FullReadingGenerationTests: XCTestCase {
    func testMissingAPIKeyExplainsConfigurationBeforeCheckingForPDF() async throws {
        let container = try MacPersistenceStore.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let model = PaperPulseMacModel()
        model.llmProfile = LLMProfile.preset(.gpt, apiKey: "")
        let paper = PaperRecord(
            candidate: PaperCandidate(source: .arxiv, sourceID: "missing-api", title: "Missing API", summary: ""),
            localFile: nil
        )

        await model.generateFullSummary(for: paper, modelContext: context)

        XCTAssertEqual(model.fullSummaryErrors[paper.id], "未配置 API，无法生成完整解读。请先在设置中配置并保存 API Key。")
        XCTAssertFalse(model.fullSummaryPaperIDs.contains(paper.id))
    }
}
