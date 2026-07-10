import Foundation
import PaperCore

extension PaperEntity {
    var resolvedPDFURL: URL? {
        guard let pdfPath else { return nil }
        let fileManager = FileManager.default

        if pdfPath.hasPrefix("/") {
            let absoluteURL = URL(fileURLWithPath: pdfPath)
            if fileManager.fileExists(atPath: absoluteURL.path) {
                return absoluteURL
            }
            return Self.currentPDFDirectory?
                .appendingPathComponent(absoluteURL.lastPathComponent)
                .existingFileURL
        }

        return Self.currentDocumentsDirectory?
            .appendingPathComponent(pdfPath)
            .existingFileURL
    }

    var persistedPaper: PersistedPaper {
        PersistedPaper(
            id: id,
            title: title,
            authors: authors,
            abstract: abstract,
            pdfPath: resolvedPDFURL?.path,
            pdfSHA256: pdfSHA256,
            absURL: arxivURL,
            createdAt: createdAt,
            candidate: candidateData.flatMap { try? JSONDecoder().decode(PaperCandidate.self, from: $0) }
        )
    }

    private static var currentDocumentsDirectory: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }

    private static var currentPDFDirectory: URL? {
        currentDocumentsDirectory?.appendingPathComponent("PaperPulse/PDFs", isDirectory: true)
    }
}

private extension URL {
    var existingFileURL: URL? {
        FileManager.default.fileExists(atPath: path) ? self : nil
    }
}
