import Foundation

public enum PaperSourceKind: String, Codable, Hashable, Sendable {
    case arxiv
    case semanticScholar
    case openAlex
    case crossref
    case unpaywall
    case web
}

public enum ProviderCapability: String, Codable, Hashable, Sendable {
    case shortSummary
    case fullSummary
    case webSearch
    case webExtraction
    case fileExtraction
    case urlContext
}

public enum SummaryLanguage: String, Codable, CaseIterable, Hashable, Identifiable, Sendable {
    case chinese
    case english

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .chinese: "中文"
        case .english: "English"
        }
    }

    public var code: String {
        switch self {
        case .chinese: "zh-Hans"
        case .english: "en"
        }
    }

    public var promptName: String {
        switch self {
        case .chinese: "Chinese"
        case .english: "English"
        }
    }

    public var shortTextInstruction: String {
        switch self {
        case .chinese: "200-400 Chinese characters"
        case .english: "concise English summary in 120-180 words"
        }
    }

    public var fullTextInstruction: String {
        switch self {
        case .chinese: "nullable full Chinese analysis"
        case .english: "nullable full English analysis"
        }
    }
}

public enum AppLanguage: String, Codable, CaseIterable, Hashable, Identifiable, Sendable {
    case chinese
    case english

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .chinese: "中文"
        case .english: "English"
        }
    }

    public func text(en: String, zh: String) -> String {
        switch self {
        case .chinese: zh
        case .english: en
        }
    }
}

public enum LLMProviderKind: String, Codable, CaseIterable, Hashable, Identifiable, Sendable {
    case gpt
    case claude
    case gemini
    case qwen
    case glm
    case kimi
    case deepSeek
    case custom

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .gpt: "GPT / OpenAI"
        case .claude: "Claude / Anthropic"
        case .gemini: "Gemini / Google"
        case .qwen: "Qwen / Bailian"
        case .glm: "GLM / Zhipu"
        case .kimi: "Kimi / Moonshot"
        case .deepSeek: "DeepSeek"
        case .custom: "Custom / Relay"
        }
    }
}

public enum LLMAPIStyle: String, Codable, CaseIterable, Hashable, Identifiable, Sendable {
    case openAIChatCompletions
    case anthropicMessages
    case geminiGenerateContent

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .openAIChatCompletions: "OpenAI-compatible"
        case .anthropicMessages: "Anthropic Messages"
        case .geminiGenerateContent: "Gemini GenerateContent"
        }
    }
}

public struct AuthorityPolicy: Codable, Hashable, Sendable {
    public var preferredInstitutions: [String]
    public var blockedInstitutions: [String]
    public var preferredVenues: [String]
    public var minimumCitationCount: Int?
    public var dailyLimit: Int

    public init(
        preferredInstitutions: [String] = [],
        blockedInstitutions: [String] = [],
        preferredVenues: [String] = [],
        minimumCitationCount: Int? = nil,
        dailyLimit: Int = 8
    ) {
        self.preferredInstitutions = preferredInstitutions
        self.blockedInstitutions = blockedInstitutions
        self.preferredVenues = preferredVenues
        self.minimumCitationCount = minimumCitationCount
        self.dailyLimit = dailyLimit
    }
}

public struct FeedConfig: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var categories: [String]
    public var keywords: [String]
    public var excludedKeywords: [String]
    public var authorityPolicy: AuthorityPolicy
    public var enableWebAugmentation: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        categories: [String] = [],
        keywords: [String] = [],
        excludedKeywords: [String] = [],
        authorityPolicy: AuthorityPolicy = AuthorityPolicy(),
        enableWebAugmentation: Bool = false
    ) {
        self.id = id
        self.name = name
        self.categories = categories
        self.keywords = keywords
        self.excludedKeywords = excludedKeywords
        self.authorityPolicy = authorityPolicy
        self.enableWebAugmentation = enableWebAugmentation
    }
}

public struct SearchQuery: Codable, Hashable, Sendable {
    public var text: String
    public var domains: [String]
    public var recencyDays: Int?

    public init(text: String, domains: [String] = [], recencyDays: Int? = nil) {
        self.text = text
        self.domains = domains
        self.recencyDays = recencyDays
    }
}

public struct WebSearchResult: Codable, Hashable, Sendable {
    public var title: String
    public var url: URL
    public var snippet: String
    public var publishedAt: Date?
    public var sourceName: String?

    public init(title: String, url: URL, snippet: String, publishedAt: Date? = nil, sourceName: String? = nil) {
        self.title = title
        self.url = url
        self.snippet = snippet
        self.publishedAt = publishedAt
        self.sourceName = sourceName
    }
}

public struct PaperCandidate: Codable, Hashable, Identifiable, Sendable {
    public var source: PaperSourceKind
    public var sourceID: String
    public var baseID: String?
    public var doi: String?
    public var title: String
    public var summary: String
    public var authors: [String]
    public var institutions: [String]
    public var categories: [String]
    public var publishedAt: Date?
    public var updatedAt: Date?
    public var absURL: URL?
    public var pdfURL: URL?
    public var venue: String?
    public var citationCount: Int?
    public var openAccessPDFURL: URL?

    public var id: String { stableID }

    public var stableID: String {
        if let doi, !doi.isEmpty {
            return "doi:\(doi.lowercased())"
        }
        if let baseID, !baseID.isEmpty {
            return "\(source.rawValue):\(baseID.lowercased())"
        }
        return "\(source.rawValue):\(sourceID.lowercased())"
    }

    public init(
        source: PaperSourceKind,
        sourceID: String,
        baseID: String? = nil,
        doi: String? = nil,
        title: String,
        summary: String,
        authors: [String] = [],
        institutions: [String] = [],
        categories: [String] = [],
        publishedAt: Date? = nil,
        updatedAt: Date? = nil,
        absURL: URL? = nil,
        pdfURL: URL? = nil,
        venue: String? = nil,
        citationCount: Int? = nil,
        openAccessPDFURL: URL? = nil
    ) {
        self.source = source
        self.sourceID = sourceID
        self.baseID = baseID
        self.doi = doi
        self.title = title.cleanedWhitespace
        self.summary = summary.cleanedWhitespace
        self.authors = authors.map(\.cleanedWhitespace).filter { !$0.isEmpty }
        self.institutions = institutions.map(\.cleanedWhitespace).filter { !$0.isEmpty }
        self.categories = categories
        self.publishedAt = publishedAt
        self.updatedAt = updatedAt
        self.absURL = absURL
        self.pdfURL = pdfURL
        self.venue = venue?.cleanedWhitespace
        self.citationCount = citationCount
        self.openAccessPDFURL = openAccessPDFURL
    }
}

public struct RankedPaper: Codable, Hashable, Sendable {
    public var candidate: PaperCandidate
    public var score: Int
    public var reasons: [String]

    public init(candidate: PaperCandidate, score: Int, reasons: [String]) {
        self.candidate = candidate
        self.score = score
        self.reasons = reasons
    }
}

public struct LocalPaperFile: Codable, Hashable, Sendable {
    public var paperID: String
    public var fileURL: URL
    public var byteCount: Int
    public var mimeType: String
    public var downloadedAt: Date

    public init(paperID: String, fileURL: URL, byteCount: Int, mimeType: String, downloadedAt: Date) {
        self.paperID = paperID
        self.fileURL = fileURL
        self.byteCount = byteCount
        self.mimeType = mimeType
        self.downloadedAt = downloadedAt
    }
}

public struct ExtractedPage: Codable, Hashable, Sendable {
    public var pageNumber: Int
    public var text: String

    public init(pageNumber: Int, text: String) {
        self.pageNumber = pageNumber
        self.text = text
    }
}

public struct ExtractedPaperText: Codable, Hashable, Sendable {
    public var plainText: String
    public var pages: [ExtractedPage]

    public init(plainText: String, pages: [ExtractedPage]) {
        self.plainText = plainText
        self.pages = pages
    }
}

public struct PaperRecord: Codable, Hashable, Identifiable, Sendable {
    public var candidate: PaperCandidate
    public var localFile: LocalPaperFile?
    public var createdAt: Date

    public var id: String { candidate.stableID }

    public init(candidate: PaperCandidate, localFile: LocalPaperFile?, createdAt: Date = Date()) {
        self.candidate = candidate
        self.localFile = localFile
        self.createdAt = createdAt
    }
}

public struct PaperSummary: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var paperID: String?
    public var shortText: String
    public var fullText: String?
    public var language: String
    public var model: String
    public var generatedAt: Date
    public var sourceRange: String

    public init(
        id: UUID = UUID(),
        paperID: String? = nil,
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

public struct LLMProfile: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var providerKind: LLMProviderKind
    public var apiStyle: LLMAPIStyle
    public var baseURL: URL
    public var model: String
    public var apiKey: String
    public var capabilities: Set<ProviderCapability>

    public init(
        id: UUID = UUID(),
        name: String,
        providerKind: LLMProviderKind = .custom,
        apiStyle: LLMAPIStyle = .openAIChatCompletions,
        baseURL: URL,
        model: String,
        apiKey: String,
        capabilities: Set<ProviderCapability>
    ) {
        self.id = id
        self.name = name
        self.providerKind = providerKind
        self.apiStyle = apiStyle
        self.baseURL = baseURL
        self.model = model
        self.apiKey = apiKey
        self.capabilities = capabilities
    }
}

public struct LLMProfileConfiguration: Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var providerKind: LLMProviderKind
    public var apiStyle: LLMAPIStyle
    public var baseURL: URL
    public var model: String
    public var capabilities: Set<ProviderCapability>

    public init(
        id: UUID,
        name: String,
        providerKind: LLMProviderKind,
        apiStyle: LLMAPIStyle,
        baseURL: URL,
        model: String,
        capabilities: Set<ProviderCapability>
    ) {
        self.id = id
        self.name = name
        self.providerKind = providerKind
        self.apiStyle = apiStyle
        self.baseURL = baseURL
        self.model = model
        self.capabilities = capabilities
    }

    public init(profile: LLMProfile) {
        self.init(
            id: profile.id,
            name: profile.name,
            providerKind: profile.providerKind,
            apiStyle: profile.apiStyle,
            baseURL: profile.baseURL,
            model: profile.model,
            capabilities: profile.capabilities
        )
    }

    public func profile(apiKey: String = "") -> LLMProfile {
        LLMProfile(
            id: id,
            name: name,
            providerKind: providerKind,
            apiStyle: apiStyle,
            baseURL: baseURL,
            model: model,
            apiKey: apiKey,
            capabilities: capabilities
        )
    }
}

public extension LLMProfile {
    var persistedConfiguration: LLMProfileConfiguration {
        LLMProfileConfiguration(profile: self)
    }

    static func preset(_ kind: LLMProviderKind, apiKey: String = "") -> LLMProfile {
        switch kind {
        case .gpt:
            LLMProfile(
                name: kind.displayName,
                providerKind: kind,
                apiStyle: .openAIChatCompletions,
                baseURL: URL(string: "https://api.openai.com/v1")!,
                model: "gpt-5.5",
                apiKey: apiKey,
                capabilities: [.shortSummary, .fullSummary, .webSearch]
            )
        case .claude:
            LLMProfile(
                name: kind.displayName,
                providerKind: kind,
                apiStyle: .anthropicMessages,
                baseURL: URL(string: "https://api.anthropic.com/v1")!,
                model: "claude-sonnet-4.5",
                apiKey: apiKey,
                capabilities: [.shortSummary, .fullSummary, .webSearch, .webExtraction]
            )
        case .gemini:
            LLMProfile(
                name: kind.displayName,
                providerKind: kind,
                apiStyle: .geminiGenerateContent,
                baseURL: URL(string: "https://generativelanguage.googleapis.com/v1beta")!,
                model: "gemini-2.5-pro",
                apiKey: apiKey,
                capabilities: [.shortSummary, .fullSummary, .webSearch, .urlContext]
            )
        case .qwen:
            LLMProfile(
                name: kind.displayName,
                providerKind: kind,
                apiStyle: .openAIChatCompletions,
                baseURL: URL(string: "https://dashscope.aliyuncs.com/compatible-mode/v1")!,
                model: "qwen-plus",
                apiKey: apiKey,
                capabilities: [.shortSummary, .fullSummary, .webSearch, .webExtraction]
            )
        case .glm:
            LLMProfile(
                name: kind.displayName,
                providerKind: kind,
                apiStyle: .openAIChatCompletions,
                baseURL: URL(string: "https://open.bigmodel.cn/api/paas/v4")!,
                model: "glm-4.7",
                apiKey: apiKey,
                capabilities: [.shortSummary, .fullSummary, .webSearch]
            )
        case .kimi:
            LLMProfile(
                name: kind.displayName,
                providerKind: kind,
                apiStyle: .openAIChatCompletions,
                baseURL: URL(string: "https://api.moonshot.cn/v1")!,
                model: "kimi-k2.6",
                apiKey: apiKey,
                capabilities: [.shortSummary, .fullSummary, .webSearch, .fileExtraction]
            )
        case .deepSeek:
            LLMProfile(
                name: kind.displayName,
                providerKind: kind,
                apiStyle: .openAIChatCompletions,
                baseURL: URL(string: "https://api.deepseek.com")!,
                model: "deepseek-v4-flash",
                apiKey: apiKey,
                capabilities: [.shortSummary, .fullSummary]
            )
        case .custom:
            LLMProfile(
                name: kind.displayName,
                providerKind: kind,
                apiStyle: .openAIChatCompletions,
                baseURL: URL(string: "https://api.example.com/v1")!,
                model: "custom-model",
                apiKey: apiKey,
                capabilities: [.shortSummary, .fullSummary]
            )
        }
    }

    func withBaseURL(_ baseURL: URL, apiStyle: LLMAPIStyle? = nil) -> LLMProfile {
        var copy = self
        copy.baseURL = baseURL
        if let apiStyle {
            copy.apiStyle = apiStyle
        }
        return copy
    }

    func withModel(_ model: String) -> LLMProfile {
        var copy = self
        copy.model = model
        return copy
    }

    func withAPIKey(_ apiKey: String) -> LLMProfile {
        var copy = self
        copy.apiKey = apiKey
        return copy
    }
}

public struct SearchRun: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var feedID: UUID
    public var startedAt: Date
    public var completedAt: Date?
    public var selectedCount: Int

    public init(id: UUID = UUID(), feedID: UUID, startedAt: Date, completedAt: Date? = nil, selectedCount: Int = 0) {
        self.id = id
        self.feedID = feedID
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.selectedCount = selectedCount
    }
}

public struct PipelineFailure: Codable, Hashable, Sendable {
    public var paperID: String?
    public var message: String

    public init(paperID: String?, message: String) {
        self.paperID = paperID
        self.message = message
    }
}

public struct PipelineResult: Codable, Hashable, Sendable {
    public var run: SearchRun
    public var rankedCandidates: [RankedPaper]
    public var papers: [PaperRecord]
    public var summaries: [PaperSummary]
    public var failures: [PipelineFailure]

    public init(
        run: SearchRun,
        rankedCandidates: [RankedPaper],
        papers: [PaperRecord],
        summaries: [PaperSummary],
        failures: [PipelineFailure]
    ) {
        self.run = run
        self.rankedCandidates = rankedCandidates
        self.papers = papers
        self.summaries = summaries
        self.failures = failures
    }
}

extension String {
    var cleanedWhitespace: String {
        split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    var slugComponent: String {
        let lower = lowercased()
        let mapped = lower.map { character -> Character in
            if character.isLetter || character.isNumber {
                return character
            }
            return "-"
        }
        let collapsed = String(mapped)
            .split(separator: "-")
            .prefix(8)
            .joined(separator: "-")
        return collapsed.isEmpty ? "paper" : collapsed
    }
}

public extension PaperCandidate {
    static func arxivBaseID(from sourceID: String) -> String {
        sourceID.replacingOccurrences(of: #"v\d+$"#, with: "", options: .regularExpression)
    }
}
