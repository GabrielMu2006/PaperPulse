import Foundation
import XCTest
@testable import PaperCore

final class ProcessingServiceTests: XCTestCase {
    func testProcessingServiceDownloadsExtractsAndStoresPageText() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let candidate = PaperCandidate.fixture(sourceID: "2607.99999v1")
        let service = PaperProcessingService(
            downloader: StubDownloader(),
            extractor: StubExtractor(text: "First page text")
        )

        let processed = try await service.process(candidate: candidate, outputDirectory: directory)

        XCTAssertEqual(processed.record.id, candidate.stableID)
        XCTAssertEqual(processed.text.pages, [ExtractedPage(pageNumber: 1, text: "First page text")])
        XCTAssertEqual(processed.storedText.relativePath, "ExtractedText/2607.99999.json")
        XCTAssertEqual(processed.storedText.sourceTextHash.count, 64)
        XCTAssertEqual(
            try ExtractedTextStore().load(processed.storedText, from: directory),
            processed.text
        )
    }

    func testSummaryServiceOwnsTrustedMetadataAndPageAnchors() async throws {
        let profileID = UUID(uuidString: "99999999-9999-9999-9999-999999999999")!
        let provider = UntrustedSummaryProvider()
        let profile = LLMProfile(
            id: profileID,
            name: "Summary profile",
            baseURL: URL(string: "https://api.example.com/v1")!,
            model: "trusted-model-name",
            apiKey: "test-key",
            capabilities: [.shortSummary, .fullSummary]
        )
        let service = PaperSummaryService(
            shortProvider: provider,
            fullProvider: provider,
            shortProfile: profile,
            fullProfile: profile,
            now: { Date(timeIntervalSince1970: 1_783_100_000) }
        )
        let record = PaperRecord(candidate: .fixture(sourceID: "summary-paper"), localFile: nil)
        let text = ExtractedPaperText(
            plainText: "First page\n\nSecond page",
            pages: [
                ExtractedPage(pageNumber: 1, text: "First page"),
                ExtractedPage(pageNumber: 2, text: "Second page")
            ]
        )

        let summary = try await service.generateShortSummary(for: record, text: text)

        XCTAssertEqual(summary.paperID, record.id)
        XCTAssertEqual(summary.kind, .short)
        XCTAssertEqual(summary.providerProfileID, profileID)
        XCTAssertEqual(summary.model, "trusted-model-name")
        XCTAssertEqual(summary.generatedAt, Date(timeIntervalSince1970: 1_783_100_000))
        XCTAssertEqual(try XCTUnwrap(summary.sourceTextHash).count, 64)
        XCTAssertEqual(summary.anchors, [
            PageAnchor(pageNumber: 1, startOffset: 0, endOffset: 10),
            PageAnchor(pageNumber: 2, startOffset: 0, endOffset: 11)
        ])
        XCTAssertEqual(summary.shortText, "Provider content only")
    }

    func testFullInterpretationUsesPageChunksAndAddsAnchorsToEverySection() async throws {
        let provider = ChunkRecordingProvider()
        let service = PaperSummaryService(
            shortProvider: provider,
            fullProvider: provider,
            fullProfile: LLMProfile(
                name: "Test",
                baseURL: URL(string: "https://api.example.com/v1")!,
                model: "test-model",
                apiKey: "test-key",
                capabilities: [.shortSummary, .fullSummary]
            ),
            fullChunkCharacterLimit: 12
        )
        let record = PaperRecord(candidate: .fixture(sourceID: "interpretation"), localFile: nil)
        let text = ExtractedPaperText(
            plainText: "page one\n\npage two\n\npage three",
            pages: [
                ExtractedPage(pageNumber: 1, text: "page one"),
                ExtractedPage(pageNumber: 2, text: "page two"),
                ExtractedPage(pageNumber: 3, text: "page three")
            ]
        )

        let summary = try await service.generateFullSummary(for: record, text: text)
        let interpretation = try XCTUnwrap(summary.interpretation)

        XCTAssertEqual(summary.kind, .full)
        XCTAssertEqual(provider.fullCallCount, 4)
        XCTAssertTrue(provider.lastFullInput.contains("Evidence from the paper."))
        XCTAssertEqual(interpretation.sections.count, PaperInterpretation.requiredSectionKinds.count)
        XCTAssertTrue(interpretation.sections.allSatisfy { !$0.anchors.isEmpty })
        XCTAssertEqual(interpretation.pageCount, 3)
    }
}

private struct UntrustedSummaryProvider: LLMProvider {
    var capabilities: Set<ProviderCapability> { [.shortSummary, .fullSummary] }

    func shortSummary(for paper: PaperRecord, text: ExtractedPaperText) async throws -> PaperSummary {
        PaperSummary(
            paperID: "model-invented-id",
            shortText: "Provider content only",
            fullText: nil,
            language: "zh-Hans",
            model: "model-invented-name",
            generatedAt: .distantPast,
            sourceRange: "invented range"
        )
    }

    func fullSummary(for paper: PaperRecord, text: ExtractedPaperText) async throws -> PaperSummary {
        try await shortSummary(for: paper, text: text)
    }
}

private final class ChunkRecordingProvider: LLMProvider, @unchecked Sendable {
    var capabilities: Set<ProviderCapability> { [.shortSummary, .fullSummary] }
    private let lock = NSLock()
    private var calls = 0
    private var latestFullInput = ""

    var fullCallCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return calls
    }

    var lastFullInput: String {
        lock.withLock { latestFullInput }
    }

    func shortSummary(for paper: PaperRecord, text: ExtractedPaperText) async throws -> PaperSummary {
        PaperSummary(shortText: "Short", fullText: nil, language: "", model: "", generatedAt: .distantPast, sourceRange: "")
    }

    func fullSummary(for paper: PaperRecord, text: ExtractedPaperText) async throws -> PaperSummary {
        lock.withLock {
            calls += 1
            latestFullInput = text.plainText
        }
        return PaperSummary(
            shortText: "",
            fullText: "Interpretation text",
            language: "",
            model: "",
            generatedAt: .distantPast,
            sourceRange: "",
            interpretation: PaperInterpretation.fixture
        )
    }
}

private extension PaperInterpretation {
    static var fixture: PaperInterpretation {
        PaperInterpretation(
            sections: PaperInterpretation.requiredSectionKinds.map {
                PaperInterpretationSection(kind: $0, content: "Evidence from the paper.")
            },
            pageCount: 0
        )
    }
}
