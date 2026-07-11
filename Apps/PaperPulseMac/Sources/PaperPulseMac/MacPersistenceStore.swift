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
    var isRead: Bool = false

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
final class MacFeedPaperEntity {
    @Attribute(.unique) var id: String
    var feedID: UUID
    var paperID: String
    var pushedAt: Date

    init(feedID: UUID, paperID: String, pushedAt: Date = Date()) {
        self.id = "\(feedID.uuidString)|\(paperID)"
        self.feedID = feedID
        self.paperID = paperID
        self.pushedAt = pushedAt
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
    var markdownPath: String?

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
        markdownPath = nil
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
        let schema = Schema([MacFeedEntity.self, MacPaperEntity.self, MacFeedPaperEntity.self, MacSummaryEntity.self])
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

    static func savePaper(_ record: PaperRecord, in context: ModelContext, feedID: UUID? = nil) throws {
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
        if let feedID {
            try linkPaper(id: record.id, to: feedID, in: context)
        }
        try context.save()
    }

    static func linkPaper(id paperID: String, to feedID: UUID, in context: ModelContext) throws {
        let linkID = "\(feedID.uuidString)|\(paperID)"
        let descriptor = FetchDescriptor<MacFeedPaperEntity>(predicate: #Predicate { $0.id == linkID })
        if try context.fetch(descriptor).first == nil {
            context.insert(MacFeedPaperEntity(feedID: feedID, paperID: paperID))
        }
    }

    static func paperIDs(for feedID: UUID, in context: ModelContext) throws -> Set<String> {
        try context.fetch(FetchDescriptor<MacFeedPaperEntity>(predicate: #Predicate { $0.feedID == feedID }))
            .reduce(into: []) { $0.insert($1.paperID) }
    }

    static func unclassifiedPaperIDs(in context: ModelContext) throws -> Set<String> {
        let linked = Set(try context.fetch(FetchDescriptor<MacFeedPaperEntity>()).map(\.paperID))
        return Set(try context.fetch(FetchDescriptor<MacPaperEntity>()).map(\.id)).subtracting(linked)
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

    static func saveFullSummary(
        _ summary: PaperSummary,
        for paper: PaperRecord,
        in context: ModelContext,
        directory: URL? = nil
    ) throws -> URL {
        let fileURL = try writeMarkdown(summary: summary, paper: paper, directory: directory ?? interpretationDirectory())
        try saveSummary(summary, in: context)
        let descriptor = FetchDescriptor<MacSummaryEntity>(predicate: #Predicate { $0.id == summary.id })
        guard let entity = try context.fetch(descriptor).first else {
            throw CocoaError(.fileNoSuchFile)
        }
        entity.markdownPath = fileURL.path
        try context.save()
        return fileURL
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

    static func fetchPapers(in context: ModelContext) throws -> [PaperRecord] {
        try context.fetch(FetchDescriptor<MacPaperEntity>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]))
            .compactMap(record(from:))
    }

    static func record(from entity: MacPaperEntity) -> PaperRecord? {
        guard let candidate = try? JSONDecoder().decode(PaperCandidate.self, from: entity.candidateData) else { return nil }
        let file = entity.pdfPath.map { path in
            let url = URL(fileURLWithPath: path)
            let byteCount = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            return LocalPaperFile(
                paperID: entity.id,
                fileURL: url,
                byteCount: byteCount,
                mimeType: "application/pdf",
                downloadedAt: entity.createdAt,
                sha256: entity.pdfSHA256 ?? ""
            )
        }
        return PaperRecord(candidate: candidate, localFile: file, createdAt: entity.createdAt)
    }

    static func fetchShortSummaries(in context: ModelContext) throws -> [String: PaperSummary] {
        let shortKind = SummaryKind.short.rawValue
        return try context.fetch(FetchDescriptor<MacSummaryEntity>(predicate: #Predicate { $0.kindRawValue == shortKind }))
            .reduce(into: [:]) { result, entity in
                let anchors = (try? JSONDecoder().decode([PageAnchor].self, from: entity.anchorsData)) ?? []
                result[entity.paperID] = PaperSummary(
                    id: entity.id,
                    paperID: entity.paperID,
                    shortText: entity.shortText,
                    fullText: entity.fullText,
                    language: entity.language,
                    model: entity.model,
                    generatedAt: entity.generatedAt,
                    sourceRange: entity.sourceRange,
                    kind: .short,
                    providerProfileID: entity.providerProfileID,
                    sourceTextHash: entity.sourceTextHash,
                    anchors: anchors
                )
            }
    }

    static func fullSummary(for paperID: String, in context: ModelContext) throws -> PaperSummary? {
        let fullKind = SummaryKind.full.rawValue
        guard let entity = try context.fetch(FetchDescriptor<MacSummaryEntity>(predicate: #Predicate {
            $0.paperID == paperID && $0.kindRawValue == fullKind
        })).sorted(by: { $0.generatedAt > $1.generatedAt }).first else { return nil }
        let anchors = (try? JSONDecoder().decode([PageAnchor].self, from: entity.anchorsData)) ?? []
        let interpretation = entity.interpretationData.flatMap { try? JSONDecoder().decode(PaperInterpretation.self, from: $0) }
        return PaperSummary(
            id: entity.id,
            paperID: entity.paperID,
            shortText: entity.shortText,
            fullText: entity.fullText,
            language: entity.language,
            model: entity.model,
            generatedAt: entity.generatedAt,
            sourceRange: entity.sourceRange,
            kind: .full,
            providerProfileID: entity.providerProfileID,
            sourceTextHash: entity.sourceTextHash,
            anchors: anchors,
            interpretation: interpretation
        )
    }

    static func fullSummaryFileURL(for paperID: String, in context: ModelContext) throws -> URL? {
        let fullKind = SummaryKind.full.rawValue
        return try context.fetch(FetchDescriptor<MacSummaryEntity>(predicate: #Predicate {
            $0.paperID == paperID && $0.kindRawValue == fullKind
        })).sorted(by: { $0.generatedAt > $1.generatedAt }).first.flatMap { entity in
            entity.markdownPath.map(URL.init(fileURLWithPath:))
        }
    }

    static func deleteFullSummary(for paperID: String, in context: ModelContext) throws {
        let fullKind = SummaryKind.full.rawValue
        let descriptor = FetchDescriptor<MacSummaryEntity>(predicate: #Predicate {
            $0.paperID == paperID && $0.kindRawValue == fullKind
        })
        for entity in try context.fetch(descriptor) {
            if let path = entity.markdownPath {
                try? FileManager.default.removeItem(at: URL(fileURLWithPath: path))
            }
            context.delete(entity)
        }
        try context.save()
    }

    static func deleteFeed(id: UUID, in context: ModelContext) throws {
        let descriptor = FetchDescriptor<MacFeedEntity>(predicate: #Predicate { $0.id == id })
        for entity in try context.fetch(descriptor) { context.delete(entity) }
        let linkDescriptor = FetchDescriptor<MacFeedPaperEntity>(predicate: #Predicate { $0.feedID == id })
        for link in try context.fetch(linkDescriptor) { context.delete(link) }
        try context.save()
    }

    @discardableResult
    static func clearUnclassifiedPapers(in context: ModelContext) throws -> Int {
        let unclassified = try unclassifiedPaperIDs(in: context)
        guard !unclassified.isEmpty else { return 0 }

        let papers = try context.fetch(FetchDescriptor<MacPaperEntity>())
        let summaries = try context.fetch(FetchDescriptor<MacSummaryEntity>())
        for paper in papers where unclassified.contains(paper.id) {
            if let path = paper.pdfPath { try? FileManager.default.removeItem(at: URL(fileURLWithPath: path)) }
            for summary in summaries where summary.paperID == paper.id {
                if let path = summary.markdownPath { try? FileManager.default.removeItem(at: URL(fileURLWithPath: path)) }
                context.delete(summary)
            }
            context.delete(paper)
        }
        try context.save()
        return unclassified.count
    }

    private static func interpretationDirectory() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return base
            .appendingPathComponent("PaperPulse", isDirectory: true)
            .appendingPathComponent("macOS", isDirectory: true)
            .appendingPathComponent("Interpretations", isDirectory: true)
    }

    private static func writeMarkdown(summary: PaperSummary, paper: PaperRecord, directory: URL) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let filename = paper.id.replacingOccurrences(of: "[^A-Za-z0-9._-]", with: "-", options: .regularExpression)
        let fileURL = directory.appendingPathComponent("\(filename).md")
        try renderedMarkdown(summary: summary, paper: paper).write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    private static func renderedMarkdown(summary: PaperSummary, paper: PaperRecord) -> String {
        var lines = [
            "# \(paper.candidate.title)",
            "",
            "- 模型：\(summary.model)",
            "- 生成时间：\(summary.generatedAt.formatted(date: .numeric, time: .shortened))",
            "- 文本范围：\(summary.sourceRange)",
            ""
        ]
        if let interpretation = summary.interpretation {
            for section in interpretation.sections {
                lines.append("## \(markdownTitle(for: section.kind))")
                lines.append("")
                lines.append(section.content)
                let pages = section.anchors.map(\.pageNumber).sorted()
                if let first = pages.first, let last = pages.last {
                    lines.append("")
                    lines.append(first == last ? "证据页码：第 \(first) 页" : "证据页码：第 \(first)-\(last) 页")
                }
                lines.append("")
            }
        } else {
            lines.append(summary.fullText ?? summary.shortText)
        }
        return lines.joined(separator: "\n")
    }

    private static func markdownTitle(for kind: PaperInterpretationSectionKind) -> String {
        switch kind {
        case .researchQuestion: "研究问题与背景"
        case .paperStructure: "论文结构概览"
        case .method: "方法"
        case .experimentDesign: "数据与实验设计"
        case .results: "主要结果"
        case .keyArguments: "关键论证"
        case .limitations: "局限与风险"
        case .readerFit: "适合读者"
        case .extensionQuestions: "可延伸问题"
        }
    }
}
