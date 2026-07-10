import Foundation
import XCTest
@testable import PaperCore

struct StubHTTPClient: HTTPClient {
    var handler: (URLRequest) async throws -> HTTPResponse

    func perform(_ request: URLRequest) async throws -> HTTPResponse {
        try await handler(request)
    }
}

struct StubPaperSource: PaperSource {
    var results: [PaperCandidate]

    func search(feed: FeedConfig, window: DateInterval) async throws -> [PaperCandidate] {
        results
    }
}

actor PaperSourceInvocationRecorder {
    private var values: [DateInterval] = []

    func record(_ window: DateInterval) {
        values.append(window)
    }

    func windows() -> [DateInterval] {
        values
    }
}

struct RecordingPaperSource: PaperSource {
    private let recorder = PaperSourceInvocationRecorder()
    var results: [PaperCandidate]
    var error: Error?

    init(results: [PaperCandidate] = [], error: Error? = nil) {
        self.results = results
        self.error = error
    }

    func search(feed: FeedConfig, window: DateInterval) async throws -> [PaperCandidate] {
        await recorder.record(window)
        if let error {
            throw error
        }
        return results
    }

    func windows() async -> [DateInterval] {
        await recorder.windows()
    }
}

struct StubDownloader: PaperDownloader {
    func download(_ paper: PaperCandidate, to directory: URL) async throws -> LocalPaperFile {
        LocalPaperFile(
            paperID: paper.stableID,
            fileURL: directory.appendingPathComponent("\(paper.baseID ?? paper.sourceID).pdf"),
            byteCount: 1024,
            mimeType: "application/pdf",
            downloadedAt: Date()
        )
    }
}

struct StubExtractor: PDFTextExtractor {
    var text: String

    func extract(from file: LocalPaperFile) async throws -> ExtractedPaperText {
        ExtractedPaperText(plainText: text, pages: [ExtractedPage(pageNumber: 1, text: text)])
    }
}

struct StubLLMProvider: LLMProvider {
    var capabilities: Set<ProviderCapability> { [.shortSummary, .fullSummary] }

    func shortSummary(for paper: PaperRecord, text: ExtractedPaperText) async throws -> PaperSummary {
        PaperSummary(
            paperID: paper.id,
            shortText: "简介：\(paper.candidate.title)",
            fullText: nil,
            language: "zh-Hans",
            model: "stub",
            generatedAt: Date(timeIntervalSince1970: 0),
            sourceRange: "pages 1"
        )
    }

    func fullSummary(for paper: PaperRecord, text: ExtractedPaperText) async throws -> PaperSummary {
        PaperSummary(
            paperID: paper.id,
            shortText: "简介：\(paper.candidate.title)",
            fullText: "完整简介：\(text.plainText)",
            language: "zh-Hans",
            model: "stub",
            generatedAt: Date(timeIntervalSince1970: 0),
            sourceRange: "pages 1"
        )
    }
}

extension PaperCandidate {
    static func fixture(
        sourceID: String = "fixture",
        doi: String? = nil,
        title: String = "Fixture Paper",
        summary: String = "Fixture summary.",
        authors: [String] = ["A. Researcher"],
        institutions: [String] = [],
        categories: [String] = ["cs.AI"],
        citationCount: Int? = nil,
        pdfURL: URL? = URL(string: "https://arxiv.org/pdf/fixture.pdf")
    ) -> PaperCandidate {
        PaperCandidate(
            source: .arxiv,
            sourceID: sourceID,
            baseID: sourceID.split(separator: "v").first.map(String.init),
            doi: doi,
            title: title,
            summary: summary,
            authors: authors,
            institutions: institutions,
            categories: categories,
            publishedAt: Date(timeIntervalSince1970: 1_782_864_000),
            updatedAt: Date(timeIntervalSince1970: 1_782_864_000),
            absURL: URL(string: "https://arxiv.org/abs/\(sourceID)"),
            pdfURL: pdfURL,
            venue: nil,
            citationCount: citationCount,
            openAccessPDFURL: pdfURL,
            openAccessEvidence: pdfURL.map {
                OpenAccessEvidence(status: .verified, source: .arxiv, url: $0)
            }
        )
    }
}

func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    _ verify: (Error) -> Void,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        _ = try await expression()
        XCTFail("Expected error", file: file, line: line)
    } catch {
        verify(error)
    }
}
