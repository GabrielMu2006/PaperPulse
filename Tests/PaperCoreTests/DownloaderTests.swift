import XCTest
@testable import PaperCore

final class DownloaderTests: XCTestCase {
    func testDownloaderRejectsNonPDFResponses() async throws {
        let client = StubHTTPClient { _ in
            HTTPResponse(
                data: Data("html".utf8),
                statusCode: 200,
                mimeType: "text/html",
                finalURL: URL(string: "https://example.com/paper")!
            )
        }
        let downloader = URLSessionPaperDownloader(httpClient: client, minimumBytes: 1)
        let paper = PaperCandidate.fixture(
            sourceID: "2607.00003v1",
            title: "Not a PDF",
            pdfURL: URL(string: "https://example.com/paper")!
        )

        await XCTAssertThrowsErrorAsync(
            try await downloader.download(paper, to: FileManager.default.temporaryDirectory)
        ) { error in
            XCTAssertEqual(error as? PaperDownloadError, .invalidMimeType("text/html"))
        }
    }

    func testDownloaderWritesPDFWithSafeFilename() async throws {
        let bytes = Data("%PDF-1.7\nbody".utf8)
        let client = StubHTTPClient { _ in
            HTTPResponse(
                data: bytes,
                statusCode: 200,
                mimeType: "application/pdf",
                finalURL: URL(string: "https://arxiv.org/pdf/2607.00004v1.pdf")!
            )
        }
        let downloader = URLSessionPaperDownloader(httpClient: client, minimumBytes: 4)
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let paper = PaperCandidate.fixture(
            sourceID: "2607.00004v1",
            title: "World/Model: Agents?",
            pdfURL: URL(string: "https://arxiv.org/pdf/2607.00004v1.pdf")!
        )

        let file = try await downloader.download(paper, to: directory)

        XCTAssertTrue(FileManager.default.fileExists(atPath: file.fileURL.path))
        XCTAssertEqual(file.fileURL.lastPathComponent, "2607.00004_world-model-agents.pdf")
        XCTAssertEqual(try Data(contentsOf: file.fileURL), bytes)
    }
}
