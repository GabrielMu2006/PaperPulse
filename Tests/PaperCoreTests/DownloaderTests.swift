import XCTest
@testable import PaperCore

final class DownloaderTests: XCTestCase {
    func testDownloaderRejectsUnverifiedOrMissingOpenAccessEvidence() async throws {
        let downloader = URLSessionPaperDownloader(httpClient: StubHTTPClient { _ in
            XCTFail("A paper without verified OA evidence must not be requested")
            return HTTPResponse(data: Data(), statusCode: 200, mimeType: nil, finalURL: URL(string: "https://example.com")!)
        }, minimumBytes: 1)
        let paper = PaperCandidate(
            source: .crossref,
            sourceID: "10.1000/example",
            doi: "10.1000/example",
            title: "Unverified Link",
            summary: "",
            pdfURL: URL(string: "https://publisher.example/paper.pdf")
        )

        await XCTAssertThrowsErrorAsync(
            try await downloader.download(paper, to: FileManager.default.temporaryDirectory)
        ) { error in
            XCTAssertEqual(error as? PaperDownloadError, .unverifiedOpenAccess)
        }
    }

    func testDownloaderRejectsNonHTTPSOpenAccessURL() async throws {
        let downloader = URLSessionPaperDownloader(httpClient: StubHTTPClient { _ in
            XCTFail("An insecure URL must not be requested")
            return HTTPResponse(data: Data(), statusCode: 200, mimeType: nil, finalURL: URL(string: "http://example.com")!)
        }, minimumBytes: 1)
        let insecureURL = URL(string: "http://repository.example/paper.pdf")!
        let paper = PaperCandidate.fixture(pdfURL: insecureURL)

        await XCTAssertThrowsErrorAsync(
            try await downloader.download(paper, to: FileManager.default.temporaryDirectory)
        ) { error in
            XCTAssertEqual(error as? PaperDownloadError, .insecureURL(insecureURL))
        }
    }

    func testDownloaderRejectsPDFOverConfiguredMaximumSize() async throws {
        let bytes = Data("%PDF-1.7\\nthis body is intentionally too large".utf8)
        let client = StubHTTPClient { request in
            HTTPResponse(data: bytes, statusCode: 200, mimeType: "application/pdf", finalURL: try XCTUnwrap(request.url))
        }
        let downloader = URLSessionPaperDownloader(httpClient: client, minimumBytes: 4, maximumBytes: 12)

        await XCTAssertThrowsErrorAsync(
            try await downloader.download(.fixture(), to: FileManager.default.temporaryDirectory)
        ) { error in
            XCTAssertEqual(error as? PaperDownloadError, .fileTooLarge(bytes.count))
        }
    }

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
        XCTAssertEqual(file.sha256.count, 64)
    }

    func testDownloaderReusesExistingFileWithSameSHA256() async throws {
        let bytes = Data("%PDF-1.7\\nshared body".utf8)
        let client = StubHTTPClient { request in
            HTTPResponse(data: bytes, statusCode: 200, mimeType: "application/pdf", finalURL: try XCTUnwrap(request.url))
        }
        let downloader = URLSessionPaperDownloader(httpClient: client, minimumBytes: 4)
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let first = try await downloader.download(
            .fixture(sourceID: "first", title: "First Paper"),
            to: directory
        )
        let second = try await downloader.download(
            .fixture(sourceID: "second", title: "Second Paper"),
            to: directory
        )

        XCTAssertEqual(first.fileURL, second.fileURL)
        XCTAssertEqual(first.sha256, second.sha256)
    }
}
