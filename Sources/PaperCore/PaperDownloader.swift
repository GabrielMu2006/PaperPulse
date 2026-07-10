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
    private let httpClient: HTTPClient
    private let resolver: PDFURLResolver
    private let minimumBytes: Int
    private let maximumBytes: Int

    public init(
        httpClient: HTTPClient = URLSessionHTTPClient(),
        resolver: PDFURLResolver = PDFURLResolver(),
        minimumBytes: Int = 10_000,
        maximumBytes: Int = 100 * 1_024 * 1_024
    ) {
        self.httpClient = httpClient
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

        let response = try await httpClient.perform(request)
        guard (200..<300).contains(response.statusCode) else {
            throw PaperDownloadError.nonHTTPStatus(response.statusCode)
        }
        guard response.finalURL.scheme?.lowercased() == "https" else {
            throw PaperDownloadError.insecureURL(response.finalURL)
        }

        if let mimeType = response.mimeType?.lowercased(), !mimeType.contains("pdf") {
            throw PaperDownloadError.invalidMimeType(response.mimeType)
        }

        guard response.data.count <= maximumBytes else {
            throw PaperDownloadError.fileTooLarge(response.data.count)
        }

        guard response.data.count >= minimumBytes else {
            throw PaperDownloadError.fileTooSmall(response.data.count)
        }

        guard response.data.starts(with: Data("%PDF".utf8)) else {
            throw PaperDownloadError.invalidPDFSignature
        }

        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let sha256 = Self.sha256(for: response.data)
            if let duplicate = try existingFile(withSHA256: sha256, in: directory) {
                let canonicalURL = duplicate.resolvingSymlinksInPath()
                return LocalPaperFile(
                    paperID: paper.stableID,
                    fileURL: canonicalURL,
                    byteCount: try Data(contentsOf: canonicalURL).count,
                    mimeType: "application/pdf",
                    downloadedAt: Date(),
                    sha256: sha256
                )
            }
            let destination = directory
                .appendingPathComponent(Self.filename(for: paper))
                .resolvingSymlinksInPath()
            try response.data.write(to: destination, options: [.atomic])
            return LocalPaperFile(
                paperID: paper.stableID,
                fileURL: destination,
                byteCount: response.data.count,
                mimeType: "application/pdf",
                downloadedAt: Date(),
                sha256: sha256
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
            if Self.sha256(for: try Data(contentsOf: file)) == sha256 {
                return file
            }
        }
        return nil
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
