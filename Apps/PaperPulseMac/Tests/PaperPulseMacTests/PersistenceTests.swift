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
}
