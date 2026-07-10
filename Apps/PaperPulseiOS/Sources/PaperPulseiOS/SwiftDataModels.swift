import Foundation
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
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        categories: [String],
        keywords: [String],
        excludedKeywords: [String] = [],
        dailyLimit: Int,
        enableWebAugmentation: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.categories = categories
        self.keywords = keywords
        self.excludedKeywords = excludedKeywords
        self.dailyLimit = dailyLimit
        self.enableWebAugmentation = enableWebAugmentation
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
    var arxivURL: URL?
    var createdAt: Date
    var isFavorite: Bool
    var isRead: Bool

    init(
        id: String,
        title: String,
        authors: [String],
        abstract: String,
        pdfPath: String?,
        arxivURL: URL?,
        createdAt: Date = Date(),
        isFavorite: Bool = false,
        isRead: Bool = false
    ) {
        self.id = id
        self.title = title
        self.authors = authors
        self.abstract = abstract
        self.pdfPath = pdfPath
        self.arxivURL = arxivURL
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

    init(
        id: UUID = UUID(),
        paperID: String,
        shortText: String,
        fullText: String?,
        language: String = "zh-Hans",
        model: String,
        generatedAt: Date,
        sourceRange: String = ""
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
