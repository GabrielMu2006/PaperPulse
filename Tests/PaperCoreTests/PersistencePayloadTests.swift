import Foundation
import XCTest
@testable import PaperCore

final class PersistencePayloadTests: XCTestCase {
    func testPipelineResultBuildsPersistencePayloadForSwiftDataStorage() {
        let feedID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let runID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let summaryID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        let feed = FeedConfig(
            id: feedID,
            name: "World Models",
            categories: ["cs.AI"],
            keywords: ["world model", "agent"],
            authorityPolicy: AuthorityPolicy(dailyLimit: 3)
        )
        let fileURL = URL(fileURLWithPath: "/tmp/PaperPulse/2607.02642.pdf")
        let paper = PaperRecord(
            candidate: .fixture(
                sourceID: "2607.02642v1",
                title: "GigaWorld-1",
                summary: "A roadmap to build world models.",
                authors: ["A. Author", "B. Builder"],
                pdfURL: URL(string: "https://arxiv.org/pdf/2607.02642v1.pdf")!
            ),
            localFile: LocalPaperFile(
                paperID: "arxiv:2607.02642",
                fileURL: fileURL,
                byteCount: 42_000,
                mimeType: "application/pdf",
                downloadedAt: Date(timeIntervalSince1970: 1_783_000_000)
            ),
            createdAt: Date(timeIntervalSince1970: 1_783_000_100)
        )
        let summary = PaperSummary(
            id: summaryID,
            paperID: paper.id,
            shortText: "简介：这是一篇关于世界模型的论文。",
            fullText: nil,
            language: "zh-Hans",
            model: "stub",
            generatedAt: Date(timeIntervalSince1970: 1_783_000_200),
            sourceRange: "pages 1-2"
        )
        let result = PipelineResult(
            run: SearchRun(
                id: runID,
                feedID: feedID,
                startedAt: Date(timeIntervalSince1970: 1_783_000_050),
                completedAt: Date(timeIntervalSince1970: 1_783_000_250),
                selectedCount: 1
            ),
            rankedCandidates: [],
            papers: [paper],
            summaries: [summary],
            failures: []
        )

        let payload = result.persistencePayload(feed: feed)

        XCTAssertEqual(payload.feed.id, feedID)
        XCTAssertEqual(payload.feed.name, "World Models")
        XCTAssertEqual(payload.feed.dailyLimit, 3)
        XCTAssertEqual(payload.run.id, runID)
        XCTAssertEqual(payload.run.feedID, feedID)
        XCTAssertEqual(payload.run.feedName, "World Models")
        XCTAssertEqual(payload.run.selectedCount, 1)
        XCTAssertEqual(payload.papers.count, 1)
        XCTAssertEqual(payload.papers[0].id, paper.id)
        XCTAssertEqual(payload.papers[0].title, "GigaWorld-1")
        XCTAssertEqual(payload.papers[0].pdfPath, fileURL.path)
        XCTAssertEqual(payload.papers[0].absURL, URL(string: "https://arxiv.org/abs/2607.02642v1"))
        XCTAssertEqual(payload.summaries.count, 1)
        XCTAssertEqual(payload.summaries[0].id, summaryID)
        XCTAssertEqual(payload.summaries[0].paperID, paper.id)
        XCTAssertEqual(payload.summaries[0].language, "zh-Hans")
        XCTAssertEqual(payload.summaries[0].sourceRange, "pages 1-2")
    }

    func testPersistedPaperRebuildsPaperRecordForFullSummaryGeneration() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let pdfURL = directory.appendingPathComponent("2607.07459.pdf")
        try Data("%PDF-1.7\nfixture".utf8).write(to: pdfURL)

        let persisted = PersistedPaper(
            id: "arxiv:2607.07459",
            title: "EmbodiedGen V2",
            authors: ["A. Author"],
            abstract: "An agentic simulation-ready 3D world engine.",
            pdfPath: pdfURL.path,
            absURL: URL(string: "https://arxiv.org/abs/2607.07459"),
            createdAt: Date(timeIntervalSince1970: 1_783_000_300)
        )

        let record = persisted.paperRecord(source: .arxiv)

        XCTAssertEqual(record.id, "arxiv:2607.07459")
        XCTAssertEqual(record.candidate.sourceID, "2607.07459")
        XCTAssertEqual(record.candidate.baseID, "2607.07459")
        XCTAssertEqual(record.candidate.title, "EmbodiedGen V2")
        XCTAssertEqual(record.localFile?.fileURL, pdfURL)
        XCTAssertEqual(record.localFile?.mimeType, "application/pdf")
        XCTAssertEqual(record.localFile?.byteCount, 16)
    }

    func testFeedConfigRoundTripsThroughPersistedFeed() {
        let id = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
        let feed = FeedConfig(
            id: id,
            name: "Embodied Agents",
            categories: ["cs.AI", "cs.RO"],
            keywords: ["agent", "robot", "world model"],
            excludedKeywords: ["protein", "finance"],
            authorityPolicy: AuthorityPolicy(dailyLimit: 7),
            enableWebAugmentation: true
        )

        let persisted = feed.persistedFeed
        let rebuilt = persisted.feedConfig()

        XCTAssertEqual(persisted.id, id)
        XCTAssertEqual(persisted.name, "Embodied Agents")
        XCTAssertEqual(persisted.categories, ["cs.AI", "cs.RO"])
        XCTAssertEqual(persisted.keywords, ["agent", "robot", "world model"])
        XCTAssertEqual(persisted.excludedKeywords, ["protein", "finance"])
        XCTAssertEqual(persisted.dailyLimit, 7)
        XCTAssertTrue(persisted.enableWebAugmentation)
        XCTAssertEqual(rebuilt, feed)
    }
}
