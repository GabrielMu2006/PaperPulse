import Foundation

public struct PipelinePersistencePayload: Codable, Hashable, Sendable {
    public var feed: PersistedFeed
    public var run: PersistedRun
    public var papers: [PersistedPaper]
    public var summaries: [PersistedSummary]
    public var failures: [PipelineFailure]

    public init(
        feed: PersistedFeed,
        run: PersistedRun,
        papers: [PersistedPaper],
        summaries: [PersistedSummary],
        failures: [PipelineFailure]
    ) {
        self.feed = feed
        self.run = run
        self.papers = papers
        self.summaries = summaries
        self.failures = failures
    }
}

public struct PersistedFeed: Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var categories: [String]
    public var keywords: [String]
    public var excludedKeywords: [String]
    public var dailyLimit: Int
    public var enableWebAugmentation: Bool

    public init(
        id: UUID,
        name: String,
        categories: [String],
        keywords: [String],
        excludedKeywords: [String] = [],
        dailyLimit: Int,
        enableWebAugmentation: Bool = false
    ) {
        self.id = id
        self.name = name
        self.categories = categories
        self.keywords = keywords
        self.excludedKeywords = excludedKeywords
        self.dailyLimit = dailyLimit
        self.enableWebAugmentation = enableWebAugmentation
    }
}

public struct PersistedRun: Codable, Hashable, Sendable {
    public var id: UUID
    public var feedID: UUID
    public var feedName: String
    public var startedAt: Date
    public var completedAt: Date?
    public var selectedCount: Int

    public init(
        id: UUID,
        feedID: UUID,
        feedName: String,
        startedAt: Date,
        completedAt: Date?,
        selectedCount: Int
    ) {
        self.id = id
        self.feedID = feedID
        self.feedName = feedName
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.selectedCount = selectedCount
    }
}

public struct PersistedPaper: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var authors: [String]
    public var abstract: String
    public var pdfPath: String?
    public var pdfSHA256: String?
    public var absURL: URL?
    public var createdAt: Date

    public init(
        id: String,
        title: String,
        authors: [String],
        abstract: String,
        pdfPath: String?,
        pdfSHA256: String? = nil,
        absURL: URL?,
        createdAt: Date
    ) {
        self.id = id
        self.title = title
        self.authors = authors
        self.abstract = abstract
        self.pdfPath = pdfPath
        self.pdfSHA256 = pdfSHA256
        self.absURL = absURL
        self.createdAt = createdAt
    }
}

public struct PersistedSummary: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var paperID: String
    public var shortText: String
    public var fullText: String?
    public var language: String
    public var model: String
    public var generatedAt: Date
    public var sourceRange: String

    public init(
        id: UUID,
        paperID: String,
        shortText: String,
        fullText: String?,
        language: String,
        model: String,
        generatedAt: Date,
        sourceRange: String
    ) {
        self.id = id
        self.paperID = paperID
        self.shortText = shortText
        self.fullText = fullText
        self.language = language
        self.model = model
        self.generatedAt = generatedAt
        self.sourceRange = sourceRange
    }
}

public extension PersistedPaper {
    func paperRecord(source: PaperSourceKind) -> PaperRecord {
        let sourceID = id.sourceSpecificIdentifier
        let localFile = pdfPath.map { path in
            let url = URL(fileURLWithPath: path)
            return LocalPaperFile(
                paperID: id,
                fileURL: url,
                byteCount: url.fileByteCount,
                mimeType: "application/pdf",
                downloadedAt: createdAt,
                sha256: pdfSHA256 ?? ""
            )
        }

        return PaperRecord(
            candidate: PaperCandidate(
                source: source,
                sourceID: sourceID,
                baseID: sourceID,
                title: title,
                summary: abstract,
                authors: authors,
                absURL: absURL
            ),
            localFile: localFile,
            createdAt: createdAt
        )
    }
}

public extension FeedConfig {
    var persistedFeed: PersistedFeed {
        PersistedFeed(
            id: id,
            name: name,
            categories: categories,
            keywords: keywords,
            excludedKeywords: excludedKeywords,
            dailyLimit: authorityPolicy.dailyLimit,
            enableWebAugmentation: enableWebAugmentation
        )
    }
}

public extension PersistedFeed {
    func feedConfig() -> FeedConfig {
        FeedConfig(
            id: id,
            name: name,
            categories: categories,
            keywords: keywords,
            excludedKeywords: excludedKeywords,
            authorityPolicy: AuthorityPolicy(dailyLimit: dailyLimit),
            enableWebAugmentation: enableWebAugmentation
        )
    }
}

public extension PipelineResult {
    func persistencePayload(feed: FeedConfig) -> PipelinePersistencePayload {
        PipelinePersistencePayload(
            feed: feed.persistedFeed,
            run: PersistedRun(
                id: run.id,
                feedID: run.feedID,
                feedName: feed.name,
                startedAt: run.startedAt,
                completedAt: run.completedAt,
                selectedCount: run.selectedCount
            ),
            papers: papers.map { paper in
                PersistedPaper(
                    id: paper.id,
                    title: paper.candidate.title,
                    authors: paper.candidate.authors,
                    abstract: paper.candidate.summary,
                    pdfPath: paper.localFile?.fileURL.path,
                    pdfSHA256: paper.localFile?.sha256.nilIfEmpty,
                    absURL: paper.candidate.absURL,
                    createdAt: paper.createdAt
                )
            },
            summaries: summaries.compactMap { summary in
                guard let paperID = summary.paperID else { return nil }
                return PersistedSummary(
                    id: summary.id,
                    paperID: paperID,
                    shortText: summary.shortText,
                    fullText: summary.fullText,
                    language: summary.language,
                    model: summary.model,
                    generatedAt: summary.generatedAt,
                    sourceRange: summary.sourceRange
                )
            },
            failures: failures
        )
    }
}

private extension String {
    var sourceSpecificIdentifier: String {
        split(separator: ":", maxSplits: 1).last.map(String.init) ?? self
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

private extension URL {
    var fileByteCount: Int {
        guard isFileURL,
              let attributes = try? FileManager.default.attributesOfItem(atPath: path),
              let size = attributes[.size] as? NSNumber else {
            return 0
        }
        return size.intValue
    }
}
