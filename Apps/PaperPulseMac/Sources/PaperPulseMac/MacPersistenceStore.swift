import Foundation
import PaperCore
import SwiftData

@Model
final class MacFeedEntity {
    @Attribute(.unique) var id: UUID
    var configurationData: Data
    var createdAt: Date

    init(id: UUID, configurationData: Data, createdAt: Date = Date()) {
        self.id = id
        self.configurationData = configurationData
        self.createdAt = createdAt
    }
}

@Model
final class MacPaperEntity {
    @Attribute(.unique) var id: String
    var title: String
    var authors: [String]
    var abstract: String
    var pdfPath: String?
    var pdfSHA256: String?
    var absURL: URL?
    var candidateData: Data
    var createdAt: Date
    var isFavorite: Bool
    var isRead: Bool

    init(
        id: String,
        title: String,
        authors: [String],
        abstract: String,
        pdfPath: String?,
        pdfSHA256: String?,
        absURL: URL?,
        candidateData: Data,
        createdAt: Date,
        isFavorite: Bool = false,
        isRead: Bool = false
    ) {
        self.id = id
        self.title = title
        self.authors = authors
        self.abstract = abstract
        self.pdfPath = pdfPath
        self.pdfSHA256 = pdfSHA256
        self.absURL = absURL
        self.candidateData = candidateData
        self.createdAt = createdAt
        self.isFavorite = isFavorite
        self.isRead = isRead
    }
}

@Model
final class MacSummaryEntity {
    @Attribute(.unique) var id: UUID
    var paperID: String
    var shortText: String
    var fullText: String?
    var language: String
    var model: String
    var generatedAt: Date
    var sourceRange: String
    var kindRawValue: String
    var providerProfileID: UUID?
    var sourceTextHash: String?
    var anchorsData: Data
    var interpretationData: Data?

    init(summary: PaperSummary) throws {
        id = summary.id
        paperID = summary.paperID ?? ""
        shortText = summary.shortText
        fullText = summary.fullText
        language = summary.language
        model = summary.model
        generatedAt = summary.generatedAt
        sourceRange = summary.sourceRange
        kindRawValue = summary.kind.rawValue
        providerProfileID = summary.providerProfileID
        sourceTextHash = summary.sourceTextHash
        anchorsData = try JSONEncoder().encode(summary.anchors)
        interpretationData = try summary.interpretation.map { try JSONEncoder().encode($0) }
    }

    func update(from summary: PaperSummary) throws {
        paperID = summary.paperID ?? paperID
        shortText = summary.shortText
        fullText = summary.fullText
        language = summary.language
        model = summary.model
        generatedAt = summary.generatedAt
        sourceRange = summary.sourceRange
        kindRawValue = summary.kind.rawValue
        providerProfileID = summary.providerProfileID
        sourceTextHash = summary.sourceTextHash
        anchorsData = try JSONEncoder().encode(summary.anchors)
        interpretationData = try summary.interpretation.map { try JSONEncoder().encode($0) }
    }
}

@MainActor
enum MacPersistenceStore {
    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema([MacFeedEntity.self, MacPaperEntity.self, MacSummaryEntity.self])
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        } else {
            let storeURL = try FileManager.default
                .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent("PaperPulse-macOS.store")
            configuration = ModelConfiguration(schema: schema, url: storeURL)
        }
        return try ModelContainer(for: schema, configurations: configuration)
    }

    static func saveFeed(_ feed: FeedConfig, in context: ModelContext) throws {
        let data = try JSONEncoder().encode(feed)
        let descriptor = FetchDescriptor<MacFeedEntity>(predicate: #Predicate { $0.id == feed.id })
        if let existing = try context.fetch(descriptor).first {
            existing.configurationData = data
        } else {
            context.insert(MacFeedEntity(id: feed.id, configurationData: data))
        }
        try context.save()
    }

    static func fetchFeeds(in context: ModelContext) throws -> [FeedConfig] {
        try context.fetch(FetchDescriptor<MacFeedEntity>(sortBy: [SortDescriptor(\.createdAt)]))
            .compactMap { try? JSONDecoder().decode(FeedConfig.self, from: $0.configurationData) }
    }

    static func savePaper(_ record: PaperRecord, in context: ModelContext) throws {
        let candidate = record.candidate
        let data = try JSONEncoder().encode(candidate)
        let descriptor = FetchDescriptor<MacPaperEntity>(predicate: #Predicate { $0.id == record.id })
        if let existing = try context.fetch(descriptor).first {
            existing.title = candidate.title
            existing.authors = candidate.authors
            existing.abstract = candidate.summary
            existing.pdfPath = record.localFile?.fileURL.path
            existing.pdfSHA256 = record.localFile?.sha256
            existing.absURL = candidate.absURL
            existing.candidateData = data
            existing.createdAt = record.createdAt
        } else {
            context.insert(MacPaperEntity(
                id: record.id,
                title: candidate.title,
                authors: candidate.authors,
                abstract: candidate.summary,
                pdfPath: record.localFile?.fileURL.path,
                pdfSHA256: record.localFile?.sha256,
                absURL: candidate.absURL,
                candidateData: data,
                createdAt: record.createdAt
            ))
        }
        try context.save()
    }

    static func saveSummary(_ summary: PaperSummary, in context: ModelContext) throws {
        let descriptor = FetchDescriptor<MacSummaryEntity>(predicate: #Predicate { $0.id == summary.id })
        if let existing = try context.fetch(descriptor).first {
            try existing.update(from: summary)
        } else {
            context.insert(try MacSummaryEntity(summary: summary))
        }
        try context.save()
    }

    static func paper(id: String, in context: ModelContext) throws -> MacPaperEntity? {
        try context.fetch(FetchDescriptor<MacPaperEntity>(predicate: #Predicate { $0.id == id })).first
    }

    static func shortSummary(for paperID: String, in context: ModelContext) throws -> MacSummaryEntity? {
        let shortKind = SummaryKind.short.rawValue
        return try context.fetch(FetchDescriptor<MacSummaryEntity>(predicate: #Predicate {
            $0.paperID == paperID && $0.kindRawValue == shortKind
        })).first
    }
}
