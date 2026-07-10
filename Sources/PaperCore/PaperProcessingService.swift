import Foundation

public enum ExtractedTextStorageError: Error, Equatable {
    case invalidRelativePath
    case fileSystem(String)
}

public struct StoredExtractedPaperText: Codable, Hashable, Sendable {
    public var paperID: String
    public var relativePath: String
    public var sourceTextHash: String
    public var pageCount: Int

    public init(paperID: String, relativePath: String, sourceTextHash: String, pageCount: Int) {
        self.paperID = paperID
        self.relativePath = relativePath
        self.sourceTextHash = sourceTextHash
        self.pageCount = pageCount
    }
}

public struct ProcessedPaperResult: Sendable {
    public var record: PaperRecord
    public var text: ExtractedPaperText
    public var storedText: StoredExtractedPaperText

    public init(record: PaperRecord, text: ExtractedPaperText, storedText: StoredExtractedPaperText) {
        self.record = record
        self.text = text
        self.storedText = storedText
    }
}

public struct ExtractedTextStore {
    public init() {}

    public func store(
        _ text: ExtractedPaperText,
        for paper: PaperRecord,
        in rootDirectory: URL
    ) throws -> StoredExtractedPaperText {
        let relativePath = "ExtractedText/\(safeStem(for: paper.candidate)).json"
        let fileURL = rootDirectory.appendingPathComponent(relativePath).resolvingSymlinksInPath()
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try JSONEncoder().encode(text).write(to: fileURL, options: [.atomic])
            return StoredExtractedPaperText(
                paperID: paper.id,
                relativePath: relativePath,
                sourceTextHash: PaperContentHash.sha256Hex(Data(text.plainText.utf8)),
                pageCount: text.pages.count
            )
        } catch let error as ExtractedTextStorageError {
            throw error
        } catch {
            throw ExtractedTextStorageError.fileSystem(error.localizedDescription)
        }
    }

    public func load(_ stored: StoredExtractedPaperText, from rootDirectory: URL) throws -> ExtractedPaperText {
        let root = rootDirectory.resolvingSymlinksInPath().standardizedFileURL
        let fileURL = root.appendingPathComponent(stored.relativePath).standardizedFileURL
        let allowedDirectory = root.appendingPathComponent("ExtractedText").path + "/"
        guard fileURL.path.hasPrefix(allowedDirectory) else {
            throw ExtractedTextStorageError.invalidRelativePath
        }
        do {
            return try JSONDecoder().decode(ExtractedPaperText.self, from: Data(contentsOf: fileURL))
        } catch let error as ExtractedTextStorageError {
            throw error
        } catch {
            throw ExtractedTextStorageError.fileSystem(error.localizedDescription)
        }
    }

    private func safeStem(for paper: PaperCandidate) -> String {
        let raw = paper.baseID ?? paper.sourceID
        let mapped = raw.map { character -> Character in
            if character.isLetter || character.isNumber || character == "." {
                return character
            }
            return "-"
        }
        let stem = String(mapped).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return stem.isEmpty ? paper.stableID.slugComponent : stem
    }
}

public struct PaperProcessingService {
    private let downloader: any PaperDownloader
    private let extractor: any PDFTextExtractor
    private let textStore: ExtractedTextStore

    public init(
        downloader: any PaperDownloader,
        extractor: any PDFTextExtractor,
        textStore: ExtractedTextStore = ExtractedTextStore()
    ) {
        self.downloader = downloader
        self.extractor = extractor
        self.textStore = textStore
    }

    public func process(candidate: PaperCandidate, outputDirectory: URL) async throws -> ProcessedPaperResult {
        let localFile = try await downloader.download(candidate, to: outputDirectory)
        let record = PaperRecord(candidate: candidate, localFile: localFile)
        let text = try await extractor.extract(from: localFile)
        let storedText = try textStore.store(text, for: record, in: outputDirectory)
        return ProcessedPaperResult(record: record, text: text, storedText: storedText)
    }
}

public struct PaperSummaryService {
    private let shortProvider: any LLMProvider
    private let fullProvider: any LLMProvider
    private let shortProfile: LLMProfile?
    private let fullProfile: LLMProfile?
    private let language: SummaryLanguage
    private let now: @Sendable () -> Date

    public init(
        shortProvider: any LLMProvider,
        fullProvider: any LLMProvider,
        shortProfile: LLMProfile? = nil,
        fullProfile: LLMProfile? = nil,
        language: SummaryLanguage = .chinese,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.shortProvider = shortProvider
        self.fullProvider = fullProvider
        self.shortProfile = shortProfile
        self.fullProfile = fullProfile
        self.language = language
        self.now = now
    }

    public func generateShortSummary(for paper: PaperRecord, text: ExtractedPaperText) async throws -> PaperSummary {
        let summary = try await shortProvider.shortSummary(for: paper, text: text)
        return trustedMetadata(summary, kind: .short, paper: paper, text: text, profile: shortProfile)
    }

    public func generateFullSummary(for paper: PaperRecord, text: ExtractedPaperText) async throws -> PaperSummary {
        let summary = try await fullProvider.fullSummary(for: paper, text: text)
        return trustedMetadata(summary, kind: .full, paper: paper, text: text, profile: fullProfile)
    }

    private func trustedMetadata(
        _ summary: PaperSummary,
        kind: SummaryKind,
        paper: PaperRecord,
        text: ExtractedPaperText,
        profile: LLMProfile?
    ) -> PaperSummary {
        var result = summary
        result.paperID = paper.id
        result.kind = kind
        result.language = language.code
        result.providerProfileID = profile?.id
        if let profile {
            result.model = profile.model
        }
        result.generatedAt = now()
        result.sourceTextHash = PaperContentHash.sha256Hex(Data(text.plainText.utf8))
        result.anchors = text.pages.compactMap { page in
            guard !page.text.isEmpty else { return nil }
            return PageAnchor(pageNumber: page.pageNumber, startOffset: 0, endOffset: page.text.utf16.count)
        }
        result.sourceRange = sourceRange(for: result.anchors)
        return result
    }

    private func sourceRange(for anchors: [PageAnchor]) -> String {
        guard let first = anchors.first?.pageNumber, let last = anchors.last?.pageNumber else {
            return "metadata only"
        }
        return first == last ? "page \(first)" : "pages \(first)-\(last)"
    }
}
