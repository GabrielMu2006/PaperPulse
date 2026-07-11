import PaperCore
import SwiftData
import XCTest
@testable import PaperPulse

@MainActor
final class PersistenceTests: XCTestCase {
    func testIndependentMacStoreRoundTripsPaperSummaryAndReadingState() throws {
        let container = try MacPersistenceStore.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let feed = FeedConfig(name: "Desktop Agents", keywords: ["agent"])
        let candidate = PaperCandidate(
            source: .arxiv,
            sourceID: "mac-round-trip",
            title: "Desktop Paper",
            summary: "A desktop test paper."
        )
        let paper = PaperRecord(candidate: candidate, localFile: nil)
        let summary = PaperSummary(
            paperID: paper.id,
            shortText: "短简介",
            fullText: nil,
            language: "zh-Hans",
            model: "local",
            generatedAt: Date(),
            sourceRange: "page 1"
        )

        try MacPersistenceStore.saveFeed(feed, in: context)
        try MacPersistenceStore.savePaper(paper, in: context)
        try MacPersistenceStore.saveSummary(summary, in: context)
        let entity = try XCTUnwrap(MacPersistenceStore.paper(id: paper.id, in: context))
        entity.isFavorite = true
        entity.isRead = true
        try context.save()

        XCTAssertEqual(try MacPersistenceStore.fetchFeeds(in: context).first?.id, feed.id)
        XCTAssertEqual(entity.title, "Desktop Paper")
        XCTAssertTrue(entity.isFavorite)
        XCTAssertTrue(entity.isRead)
        XCTAssertEqual(try MacPersistenceStore.shortSummary(for: paper.id, in: context)?.shortText, "短简介")
    }

    func testFullInterpretationRoundTripsWithSectionAnchors() throws {
        let container = try MacPersistenceStore.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let paper = PaperRecord(candidate: PaperCandidate(source: .arxiv, sourceID: "reading", title: "Reading", summary: ""), localFile: nil)
        let section = PaperInterpretationSection(
            kind: .method,
            content: "使用分块汇总。",
            anchors: [PageAnchor(pageNumber: 3, startOffset: 0, endOffset: 12)]
        )
        let fullSummary = PaperSummary(
            paperID: paper.id,
            shortText: "完整解读",
            fullText: "方法\n使用分块汇总。",
            language: "zh-Hans",
            model: "local",
            generatedAt: Date(),
            sourceRange: "page 3",
            kind: .full,
            anchors: section.anchors,
            interpretation: PaperInterpretation(sections: [section], pageCount: 8)
        )

        try MacPersistenceStore.saveSummary(fullSummary, in: context)

        let restored = try XCTUnwrap(MacPersistenceStore.fullSummary(for: paper.id, in: context))
        XCTAssertEqual(restored.kind, .full)
        XCTAssertEqual(restored.interpretation?.sections.first?.content, "使用分块汇总。")
        XCTAssertEqual(restored.interpretation?.sections.first?.anchors.first?.pageNumber, 3)
    }
}
