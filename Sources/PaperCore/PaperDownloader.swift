import Foundation

public enum PaperDownloadError: Error, Equatable {
    case missingPDFURL
    case nonHTTPStatus(Int)
    case invalidMimeType(String?)
    case fileTooSmall(Int)
    case invalidPDFSignature
    case fileSystem(String)
}

public struct PDFURLResolver {
    public init() {}

    public func resolve(_ paper: PaperCandidate) -> URL? {
        paper.openAccessPDFURL ?? paper.pdfURL
    }
}

public struct URLSessionPaperDownloader: PaperDownloader {
    private let httpClient: HTTPClient
    private let resolver: PDFURLResolver
    private let minimumBytes: Int

    public init(
        httpClient: HTTPClient = URLSessionHTTPClient(),
        resolver: PDFURLResolver = PDFURLResolver(),
        minimumBytes: Int = 10_000
    ) {
        self.httpClient = httpClient
        self.resolver = resolver
        self.minimumBytes = minimumBytes
    }

    public func download(_ paper: PaperCandidate, to directory: URL) async throws -> LocalPaperFile {
        guard let url = resolver.resolve(paper) else {
            throw PaperDownloadError.missingPDFURL
        }

        var request = URLRequest(url: url)
        request.setValue("PaperPulse/1.0", forHTTPHeaderField: "User-Agent")

        let response = try await httpClient.perform(request)
        guard (200..<300).contains(response.statusCode) else {
            throw PaperDownloadError.nonHTTPStatus(response.statusCode)
        }

        if let mimeType = response.mimeType?.lowercased(), !mimeType.contains("pdf") {
            throw PaperDownloadError.invalidMimeType(response.mimeType)
        }

        guard response.data.count >= minimumBytes else {
            throw PaperDownloadError.fileTooSmall(response.data.count)
        }

        guard response.data.starts(with: Data("%PDF".utf8)) else {
            throw PaperDownloadError.invalidPDFSignature
        }

        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let destination = directory.appendingPathComponent(Self.filename(for: paper))
            if FileManager.default.fileExists(atPath: destination.path),
               let attributes = try? FileManager.default.attributesOfItem(atPath: destination.path),
               let size = attributes[.size] as? NSNumber,
               size.intValue > minimumBytes {
                return LocalPaperFile(
                    paperID: paper.stableID,
                    fileURL: destination,
                    byteCount: size.intValue,
                    mimeType: "application/pdf",
                    downloadedAt: Date()
                )
            }
            try response.data.write(to: destination, options: [.atomic])
            return LocalPaperFile(
                paperID: paper.stableID,
                fileURL: destination,
                byteCount: response.data.count,
                mimeType: "application/pdf",
                downloadedAt: Date()
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
