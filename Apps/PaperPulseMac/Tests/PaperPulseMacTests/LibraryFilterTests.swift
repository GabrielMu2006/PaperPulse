import PaperCore
import XCTest
@testable import PaperPulse

final class LibraryFilterTests: XCTestCase {
    func testFiltersByFavoriteAndSearchableMetadata() throws {
        let memory = MacPaperEntity(
            id: "memory",
            title: "Proactive Memory for Agents",
            authors: ["Ada Lovelace"],
            abstract: "A planning paper.",
            pdfPath: nil,
            pdfSHA256: nil,
            absURL: nil,
            candidateData: Data(),
            createdAt: Date(),
            isFavorite: true
        )
        let vision = MacPaperEntity(
            id: "vision",
            title: "Vision Benchmark",
            authors: ["Grace Hopper"],
            abstract: "A vision paper.",
            pdfPath: nil,
            pdfSHA256: nil,
            absURL: nil,
            candidateData: Data(),
            createdAt: Date(),
            isFavorite: false
        )

        XCTAssertEqual(
            MacLibraryFilter.visible([memory, vision], query: "lovelace", scope: .all).map(\.id),
            ["memory"]
        )
        XCTAssertEqual(
            MacLibraryFilter.visible([memory, vision], query: "", scope: .favorites).map(\.id),
            ["memory"]
        )
        XCTAssertTrue(MacLibraryFilter.visible([memory, vision], query: "robot", scope: .all).isEmpty)
    }
}
