import Foundation
import PaperCore
import SwiftData

@Model
final class FeedEntity {
    @Attribute(.unique) var id: UUID
    var name: String
    var categories: [String]
    var keywords: [String]
    var excludedKeywords: [String]?
    var dailyLimit: Int
    var enableWebAugmentation: Bool?
    var configurationData: Data?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        categories: [String],
        keywords: [String],
        excludedKeywords: [String] = [],
        dailyLimit: Int,
        enableWebAugmentation: Bool = false,
        configurationData: Data? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.categories = categories
        self.keywords = keywords
        self.excludedKeywords = excludedKeywords
        self.dailyLimit = dailyLimit
        self.enableWebAugmentation = enableWebAugmentation
        self.configurationData = configurationData
        self.createdAt = createdAt
    }
}

@Model
final class PaperEntity {
    @Attribute(.unique) var id: String
    var title: String
    var authors: [String]
    var abstract: String
    var pdfPath: String?
    var pdfSHA256: String?
    var arxivURL: URL?
    var candidateData: Data?
    var extractedTextRelativePath: String?
    var extractedTextHash: String?
    var processingStageRawValue: String?
    var processingFailureReason: String?
    var createdAt: Date
    var isFavorite: Bool
    var isRead: Bool

    init(
        id: String,
        title: String,
        authors: [String],
        abstract: String,
        pdfPath: String?,
        pdfSHA256: String? = nil,
        arxivURL: URL?,
        candidateData: Data? = nil,
        extractedTextRelativePath: String? = nil,
        extractedTextHash: String? = nil,
        processingStageRawValue: String? = nil,
        processingFailureReason: String? = nil,
        createdAt: Date = Date(),
        isFavorite: Bool = false,
        isRead: Bool = false
    ) {
        self.id = id
        self.title = title
        self.authors = authors
        self.abstract = abstract
        self.pdfPath = pdfPath
        self.pdfSHA256 = pdfSHA256
        self.arxivURL = arxivURL
        self.candidateData = candidateData
        self.extractedTextRelativePath = extractedTextRelativePath
        self.extractedTextHash = extractedTextHash
        self.processingStageRawValue = processingStageRawValue
        self.processingFailureReason = processingFailureReason
        self.createdAt = createdAt
        self.isFavorite = isFavorite
        self.isRead = isRead
    }
}

@Model
final class SummaryEntity {
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
    var anchorsData: Data?
    var interpretationData: Data?

    init(
        id: UUID = UUID(),
        paperID: String,
        shortText: String,
        fullText: String?,
        language: String = "zh-Hans",
        model: String,
        generatedAt: Date,
        sourceRange: String = "",
        kindRawValue: String = SummaryKind.short.rawValue,
        providerProfileID: UUID? = nil,
        sourceTextHash: String? = nil,
        anchorsData: Data? = nil,
        interpretationData: Data? = nil
    ) {
        self.id = id
        self.paperID = paperID
        self.shortText = shortText
        self.fullText = fullText
        self.language = language
        self.model = model
        self.generatedAt = generatedAt
        self.sourceRange = sourceRange
        self.kindRawValue = kindRawValue
        self.providerProfileID = providerProfileID
        self.sourceTextHash = sourceTextHash
        self.anchorsData = anchorsData
        self.interpretationData = interpretationData
    }
}

@Model
final class RunEntity {
    @Attribute(.unique) var id: UUID
    var feedID: UUID?
    var feedName: String
    var startedAt: Date
    var completedAt: Date?
    var selectedCount: Int

    init(
        id: UUID = UUID(),
        feedID: UUID? = nil,
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

@Model
final class ProcessingJobEntity {
    @Attribute(.unique) var id: UUID
    var feedID: UUID?
    var paperID: String?
    var stageRawValue: String
    var completedUnitCount: Int
    var totalUnitCount: Int
    var failureReason: String?
    var backgroundDownloadTaskIdentifier: Int?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        feedID: UUID? = nil,
        paperID: String? = nil,
        stageRawValue: String,
        completedUnitCount: Int = 0,
        totalUnitCount: Int = 0,
        failureReason: String? = nil,
        backgroundDownloadTaskIdentifier: Int? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.feedID = feedID
        self.paperID = paperID
        self.stageRawValue = stageRawValue
        self.completedUnitCount = completedUnitCount
        self.totalUnitCount = totalUnitCount
        self.failureReason = failureReason
        self.backgroundDownloadTaskIdentifier = backgroundDownloadTaskIdentifier
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
