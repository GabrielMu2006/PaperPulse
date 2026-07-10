import Foundation
import PaperCore
import SwiftData

@MainActor
enum PaperPulsePersistenceStore {
    static func saveFeed(_ feed: FeedConfig, in context: ModelContext) throws {
        try upsertFeed(feed.persistedFeed, in: context)
        try context.save()
    }

    static func fetchFeeds(in context: ModelContext) throws -> [PersistedFeed] {
        let descriptor = FetchDescriptor<FeedEntity>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        return try context.fetch(descriptor).map(\.persistedFeed)
    }

    static func save(_ payload: PipelinePersistencePayload, in context: ModelContext) throws {
        try upsertFeed(payload.feed, in: context)
        try upsertRun(payload.run, in: context)

        for paper in payload.papers {
            try upsertPaper(paper, in: context)
        }

        for summary in payload.summaries {
            try upsertSummary(summary, in: context)
        }

        try context.save()
    }

    private static func upsertFeed(_ feed: PersistedFeed, in context: ModelContext) throws {
        if let existing = try fetchFeed(id: feed.id, in: context) {
            existing.name = feed.name
            existing.categories = feed.categories
            existing.keywords = feed.keywords
            existing.excludedKeywords = feed.excludedKeywords
            existing.dailyLimit = feed.dailyLimit
            existing.enableWebAugmentation = feed.enableWebAugmentation
            return
        }

        context.insert(
            FeedEntity(
                id: feed.id,
                name: feed.name,
                categories: feed.categories,
                keywords: feed.keywords,
                excludedKeywords: feed.excludedKeywords,
                dailyLimit: feed.dailyLimit,
                enableWebAugmentation: feed.enableWebAugmentation
            )
        )
    }

    private static func upsertRun(_ run: PersistedRun, in context: ModelContext) throws {
        if let existing = try fetchRun(id: run.id, in: context) {
            existing.feedID = run.feedID
            existing.feedName = run.feedName
            existing.startedAt = run.startedAt
            existing.completedAt = run.completedAt
            existing.selectedCount = run.selectedCount
            return
        }

        context.insert(
            RunEntity(
                id: run.id,
                feedID: run.feedID,
                feedName: run.feedName,
                startedAt: run.startedAt,
                completedAt: run.completedAt,
                selectedCount: run.selectedCount
            )
        )
    }

    private static func upsertPaper(_ paper: PersistedPaper, in context: ModelContext) throws {
        let pdfPath = normalizedPDFPath(paper.pdfPath)
        if let existing = try fetchPaper(id: paper.id, in: context) {
            existing.title = paper.title
            existing.authors = paper.authors
            existing.abstract = paper.abstract
            existing.pdfPath = pdfPath
            existing.arxivURL = paper.absURL
            existing.createdAt = paper.createdAt
            return
        }

        context.insert(
            PaperEntity(
                id: paper.id,
                title: paper.title,
                authors: paper.authors,
                abstract: paper.abstract,
                pdfPath: pdfPath,
                arxivURL: paper.absURL,
                createdAt: paper.createdAt
            )
        )
    }

    private static func upsertSummary(_ summary: PersistedSummary, in context: ModelContext) throws {
        if let existing = try fetchSummary(id: summary.id, in: context) {
            existing.paperID = summary.paperID
            existing.shortText = summary.shortText
            existing.fullText = summary.fullText
            existing.language = summary.language
            existing.model = summary.model
            existing.generatedAt = summary.generatedAt
            existing.sourceRange = summary.sourceRange
            return
        }

        context.insert(
            SummaryEntity(
                id: summary.id,
                paperID: summary.paperID,
                shortText: summary.shortText,
                fullText: summary.fullText,
                language: summary.language,
                model: summary.model,
                generatedAt: summary.generatedAt,
                sourceRange: summary.sourceRange
            )
        )
    }

    private static func fetchFeed(id: UUID, in context: ModelContext) throws -> FeedEntity? {
        let descriptor = FetchDescriptor<FeedEntity>(
            predicate: #Predicate { $0.id == id }
        )
        return try context.fetch(descriptor).first
    }

    private static func fetchRun(id: UUID, in context: ModelContext) throws -> RunEntity? {
        let descriptor = FetchDescriptor<RunEntity>(
            predicate: #Predicate { $0.id == id }
        )
        return try context.fetch(descriptor).first
    }

    private static func fetchPaper(id: String, in context: ModelContext) throws -> PaperEntity? {
        let descriptor = FetchDescriptor<PaperEntity>(
            predicate: #Predicate { $0.id == id }
        )
        return try context.fetch(descriptor).first
    }

    private static func fetchSummary(id: UUID, in context: ModelContext) throws -> SummaryEntity? {
        let descriptor = FetchDescriptor<SummaryEntity>(
            predicate: #Predicate { $0.id == id }
        )
        return try context.fetch(descriptor).first
    }

    private static func normalizedPDFPath(_ path: String?) -> String? {
        guard let path else { return nil }
        let url = URL(fileURLWithPath: path)
        guard url.isFileURL else { return path }
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return path
        }

        let documentsPath = documents.standardizedFileURL.path
        let standardizedPath = url.standardizedFileURL.path
        if standardizedPath.hasPrefix(documentsPath) {
            return String(standardizedPath.dropFirst(documentsPath.count + 1))
        }
        return path
    }
}

private extension FeedEntity {
    var persistedFeed: PersistedFeed {
        PersistedFeed(
            id: id,
            name: name,
            categories: categories,
            keywords: keywords,
            excludedKeywords: excludedKeywords ?? [],
            dailyLimit: dailyLimit,
            enableWebAugmentation: enableWebAugmentation ?? false
        )
    }
}
