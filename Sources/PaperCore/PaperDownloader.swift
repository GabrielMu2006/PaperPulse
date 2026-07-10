import Foundation

public enum PaperDownloadError: Error, Equatable {
    case missingPDFURL
    case unverifiedOpenAccess
    case insecureURL(URL)
    case nonHTTPStatus(Int)
    case invalidMimeType(String?)
    case fileTooSmall(Int)
    case fileTooLarge(Int)
    case invalidPDFSignature
    case fileSystem(String)
}

public struct PDFURLResolver {
    public init() {}

    public func resolve(_ paper: PaperCandidate) -> URL? {
        guard paper.openAccessEvidence?.status == .verified else { return nil }
        return paper.openAccessEvidence?.url ?? paper.openAccessPDFURL
    }
}

public struct URLSessionPaperDownloader: PaperDownloader {
    private let httpClient: (any HTTPClient)?
    private let session: URLSession?
    private let resolver: PDFURLResolver
    private let minimumBytes: Int
    private let maximumBytes: Int

    public init(
        session: URLSession = .shared,
        resolver: PDFURLResolver = PDFURLResolver(),
        minimumBytes: Int = 10_000,
        maximumBytes: Int = 100 * 1_024 * 1_024
    ) {
        self.httpClient = nil
        self.session = session
        self.resolver = resolver
        self.minimumBytes = max(0, minimumBytes)
        self.maximumBytes = max(maximumBytes, self.minimumBytes)
    }

    public init(
        httpClient: any HTTPClient,
        resolver: PDFURLResolver = PDFURLResolver(),
        minimumBytes: Int = 10_000,
        maximumBytes: Int = 100 * 1_024 * 1_024
    ) {
        self.httpClient = httpClient
        self.session = nil
        self.resolver = resolver
        self.minimumBytes = max(0, minimumBytes)
        self.maximumBytes = max(maximumBytes, self.minimumBytes)
    }

    public func download(_ paper: PaperCandidate, to directory: URL) async throws -> LocalPaperFile {
        guard paper.openAccessEvidence?.status == .verified else {
            throw PaperDownloadError.unverifiedOpenAccess
        }
        guard let url = resolver.resolve(paper) else {
            throw PaperDownloadError.missingPDFURL
        }
        guard url.scheme?.lowercased() == "https" else {
            throw PaperDownloadError.insecureURL(url)
        }

        var request = URLRequest(url: url)
        request.setValue("PaperPulse/1.0", forHTTPHeaderField: "User-Agent")

        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            if let httpClient {
                let response = try await httpClient.perform(request)
                return try persist(
                    data: response.data,
                    statusCode: response.statusCode,
                    mimeType: response.mimeType,
                    finalURL: response.finalURL,
                    paper: paper,
                    directory: directory
                )
            }
            guard let session else {
                throw PaperDownloadError.fileSystem("No download transport is configured.")
            }
            let (temporaryURL, response) = try await session.download(for: request)
            defer { try? FileManager.default.removeItem(at: temporaryURL) }
            guard let httpResponse = response as? HTTPURLResponse else {
                throw PaperDownloadError.fileSystem("The download response was not HTTP.")
            }
            return try persist(
                temporaryFile: temporaryURL,
                statusCode: httpResponse.statusCode,
                mimeType: httpResponse.mimeType,
                finalURL: httpResponse.url ?? url,
                expectedByteCount: response.expectedContentLength,
                paper: paper,
                directory: directory
            )
        } catch let error as PaperDownloadError {
            throw error
        } catch {
            throw PaperDownloadError.fileSystem(error.localizedDescription)
        }
    }

    public static func filename(for paper: PaperCandidate) -> String {
        let base = (paper.baseID ?? paper.sourceID)
            .replacingOccurrences(of: #"v\d+$"#, with: "", options: .regularExpression)
            .identifierFilenameComponent
        return "\(base)_\(paper.title.slugComponent).pdf"
    }

    public static func sha256(for data: Data) -> String {
        PaperContentHash.sha256Hex(data)
    }

    private func persist(
        data: Data,
        statusCode: Int,
        mimeType: String?,
        finalURL: URL,
        paper: PaperCandidate,
        directory: URL
    ) throws -> LocalPaperFile {
        let stagingFile = directory.appendingPathComponent(".\(UUID().uuidString).download")
        defer { try? FileManager.default.removeItem(at: stagingFile) }
        try data.write(to: stagingFile, options: [.atomic])
        return try persist(
            temporaryFile: stagingFile,
            statusCode: statusCode,
            mimeType: mimeType,
            finalURL: finalURL,
            expectedByteCount: Int64(data.count),
            paper: paper,
            directory: directory
        )
    }

    private func persist(
        temporaryFile: URL,
        statusCode: Int,
        mimeType: String?,
        finalURL: URL,
        expectedByteCount: Int64,
        paper: PaperCandidate,
        directory: URL
    ) throws -> LocalPaperFile {
        guard (200..<300).contains(statusCode) else {
            throw PaperDownloadError.nonHTTPStatus(statusCode)
        }
        guard finalURL.scheme?.lowercased() == "https" else {
            throw PaperDownloadError.insecureURL(finalURL)
        }
        if let mimeType = mimeType?.lowercased(), !mimeType.contains("pdf") {
            throw PaperDownloadError.invalidMimeType(mimeType)
        }
        if expectedByteCount > Int64(maximumBytes) {
            throw PaperDownloadError.fileTooLarge(Int(expectedByteCount))
        }

        let fileSize = try temporaryFile.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard fileSize <= maximumBytes else {
            throw PaperDownloadError.fileTooLarge(fileSize)
        }
        guard fileSize >= minimumBytes else {
            throw PaperDownloadError.fileTooSmall(fileSize)
        }
        let signature = try readSignature(from: temporaryFile)
        guard signature == Data("%PDF".utf8) else {
            throw PaperDownloadError.invalidPDFSignature
        }

        let sha256 = try PaperContentHash.sha256Hex(ofFile: temporaryFile)
        if let duplicate = try existingFile(withSHA256: sha256, in: directory) {
            let canonicalURL = duplicate.resolvingSymlinksInPath()
            return LocalPaperFile(
                paperID: paper.stableID,
                fileURL: canonicalURL,
                byteCount: try canonicalURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0,
                mimeType: "application/pdf",
                downloadedAt: Date(),
                sha256: sha256
            )
        }

        let destination = availableDestination(for: paper, sha256: sha256, in: directory)
        try FileManager.default.copyItem(at: temporaryFile, to: destination)
        return LocalPaperFile(
            paperID: paper.stableID,
            fileURL: destination,
            byteCount: fileSize,
            mimeType: "application/pdf",
            downloadedAt: Date(),
            sha256: sha256
        )
    }

    private func existingFile(withSHA256 sha256: String, in directory: URL) throws -> URL? {
        let files = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        for file in files.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            guard file.pathExtension.lowercased() == "pdf",
                  (try file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile ?? false) else {
                continue
            }
            if try PaperContentHash.sha256Hex(ofFile: file) == sha256 {
                return file
            }
        }
        return nil
    }

    private func availableDestination(for paper: PaperCandidate, sha256: String, in directory: URL) -> URL {
        let preferred = directory.appendingPathComponent(Self.filename(for: paper)).resolvingSymlinksInPath()
        guard !FileManager.default.fileExists(atPath: preferred.path) else {
            return directory
                .appendingPathComponent("\(preferred.deletingPathExtension().lastPathComponent)-\(sha256.prefix(12)).pdf")
                .resolvingSymlinksInPath()
        }
        return preferred
    }

    private func readSignature(from fileURL: URL) throws -> Data {
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }
        return try handle.read(upToCount: 4) ?? Data()
    }
}

private extension String {
    var identifierFilenameComponent: String {
        let mapped = lowercased().map { character -> Character in
            if character.isLetter || character.isNumber || character == "." {
                return character
            }
            return "-"
        }
        let collapsed = String(mapped)
            .split(separator: "-")
            .joined(separator: "-")
        return collapsed.isEmpty ? "paper" : collapsed
    }
}
