import Foundation

#if canImport(PDFKit)
import PDFKit

public struct PDFKitTextExtractor: PDFTextExtractor {
    public init() {}

    public func extract(from file: LocalPaperFile) async throws -> ExtractedPaperText {
        guard let document = PDFDocument(url: file.fileURL) else {
            throw PDFExtractionError.unreadablePDF
        }

        var pages: [ExtractedPage] = []
        for index in 0..<document.pageCount {
            let text = document.page(at: index)?.string ?? ""
            pages.append(ExtractedPage(pageNumber: index + 1, text: text))
        }

        return ExtractedPaperText(
            plainText: pages.map(\.text).joined(separator: "\n\n").cleanedWhitespace,
            pages: pages
        )
    }
}
#else
public struct PDFKitTextExtractor: PDFTextExtractor {
    public init() {}

    public func extract(from file: LocalPaperFile) async throws -> ExtractedPaperText {
        throw PDFExtractionError.pdfKitUnavailable
    }
}
#endif

public enum PDFExtractionError: Error, Equatable {
    case unreadablePDF
    case pdfKitUnavailable
}

public struct CloudPDFExtractionProvider {
    public enum Backend: String, Codable, Sendable {
        case kimiFileExtract
        case geminiURLContext
        case anthropicWebFetch
    }

    public var backend: Backend
    public var profile: LLMProfile

    public init(backend: Backend, profile: LLMProfile) {
        self.backend = backend
        self.profile = profile
    }
}
