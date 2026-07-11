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
    case rerank
    case webSearch
    case webExtraction
    case fileExtraction
    case urlContext
}

public struct ProviderHealth: Codable, Hashable, Sendable {
    public var providerProfileID: UUID?
    public var model: String
    public var checkedAt: Date

    public init(providerProfileID: UUID?, model: String, checkedAt: Date = Date()) {
        self.providerProfileID = providerProfileID
        self.model = model
        self.checkedAt = checkedAt
    }
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

public struct FeedSchedule: Codable, Hashable, Sendable {
    public var hour: Int
    public var minute: Int
    public var weekdays: Set<Int>

    public init(hour: Int, minute: Int = 0, weekdays: Set<Int> = []) {
        self.hour = hour
        self.minute = minute
        self.weekdays = weekdays
    }
}

public struct FeedConfig: Codable, Hashable, Identifiable, Sendable {
    public static let defaultEnabledSources: [PaperSourceKind] = [.arxiv, .openAlex, .crossref]

    public var id: UUID
    public var name: String
    public var categories: [String]
    public var keywords: [String]
    public var excludedKeywords: [String]
    public var authorityPolicy: AuthorityPolicy
    public var enableWebAugmentation: Bool
    public var enabledSources: [PaperSourceKind]
    public var lookbackDays: Int
    public var schedule: FeedSchedule?
    public var searchProviderProfileID: UUID?
    public var rerankProviderProfileID: UUID?
    public var shortSummaryProviderProfileID: UUID?
    public var fullSummaryProviderProfileID: UUID?
    public var extractionProviderProfileID: UUID?

    public init(
        id: UUID = UUID(),
        name: String,
        categories: [String] = [],
        keywords: [String] = [],
        excludedKeywords: [String] = [],
        authorityPolicy: AuthorityPolicy = AuthorityPolicy(),
        enableWebAugmentation: Bool = false,
        enabledSources: [PaperSourceKind] = FeedConfig.defaultEnabledSources,
        lookbackDays: Int = 7,
        schedule: FeedSchedule? = nil,
        searchProviderProfileID: UUID? = nil,
        rerankProviderProfileID: UUID? = nil,
        shortSummaryProviderProfileID: UUID? = nil,
        fullSummaryProviderProfileID: UUID? = nil,
        extractionProviderProfileID: UUID? = nil
    ) {
        self.id = id
        self.name = name
        self.categories = categories
        self.keywords = keywords
        self.excludedKeywords = excludedKeywords
        self.authorityPolicy = authorityPolicy
        self.enableWebAugmentation = enableWebAugmentation
        self.enabledSources = enabledSources
        self.lookbackDays = lookbackDays
        self.schedule = schedule
        self.searchProviderProfileID = searchProviderProfileID
        self.rerankProviderProfileID = rerankProviderProfileID
        self.shortSummaryProviderProfileID = shortSummaryProviderProfileID
        self.fullSummaryProviderProfileID = fullSummaryProviderProfileID
        self.extractionProviderProfileID = extractionProviderProfileID
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, categories, keywords, excludedKeywords, authorityPolicy, enableWebAugmentation
        case enabledSources, lookbackDays, schedule
        case searchProviderProfileID, rerankProviderProfileID, shortSummaryProviderProfileID
        case fullSummaryProviderProfileID, extractionProviderProfileID
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID(),
            name: try container.decode(String.self, forKey: .name),
            categories: try container.decodeIfPresent([String].self, forKey: .categories) ?? [],
            keywords: try container.decodeIfPresent([String].self, forKey: .keywords) ?? [],
            excludedKeywords: try container.decodeIfPresent([String].self, forKey: .excludedKeywords) ?? [],
            authorityPolicy: try container.decodeIfPresent(AuthorityPolicy.self, forKey: .authorityPolicy) ?? AuthorityPolicy(),
            enableWebAugmentation: try container.decodeIfPresent(Bool.self, forKey: .enableWebAugmentation) ?? false,
            enabledSources: Self.migratedEnabledSources(
                try container.decodeIfPresent([PaperSourceKind].self, forKey: .enabledSources) ?? Self.defaultEnabledSources
            ),
            lookbackDays: try container.decodeIfPresent(Int.self, forKey: .lookbackDays) ?? 7,
            schedule: try container.decodeIfPresent(FeedSchedule.self, forKey: .schedule),
            searchProviderProfileID: try container.decodeIfPresent(UUID.self, forKey: .searchProviderProfileID),
            rerankProviderProfileID: try container.decodeIfPresent(UUID.self, forKey: .rerankProviderProfileID),
            shortSummaryProviderProfileID: try container.decodeIfPresent(UUID.self, forKey: .shortSummaryProviderProfileID),
            fullSummaryProviderProfileID: try container.decodeIfPresent(UUID.self, forKey: .fullSummaryProviderProfileID),
            extractionProviderProfileID: try container.decodeIfPresent(UUID.self, forKey: .extractionProviderProfileID)
        )
    }

    private static func migratedEnabledSources(_ sources: [PaperSourceKind]) -> [PaperSourceKind] {
        let migrated = sources.filter { $0 != .semanticScholar }
        return migrated.isEmpty ? Self.defaultEnabledSources : migrated
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

public struct PaperProvenance: Codable, Hashable, Sendable {
    public var source: PaperSourceKind
    public var sourceID: String
    public var sourceURL: URL?
    public var retrievedAt: Date?

    public init(source: PaperSourceKind, sourceID: String, sourceURL: URL? = nil, retrievedAt: Date? = nil) {
        self.source = source
        self.sourceID = sourceID
        self.sourceURL = sourceURL
        self.retrievedAt = retrievedAt
    }
}

public enum OpenAccessStatus: String, Codable, Hashable, Sendable {
    case verified
    case unverified
    case unavailable
}

public struct OpenAccessEvidence: Codable, Hashable, Sendable {
    public var status: OpenAccessStatus
    public var source: PaperSourceKind
    public var url: URL?
    public var license: String?
    public var verifiedAt: Date?

    public init(
        status: OpenAccessStatus,
        source: PaperSourceKind,
        url: URL? = nil,
        license: String? = nil,
        verifiedAt: Date? = nil
    ) {
        self.status = status
        self.source = source
        self.url = url
        self.license = license
        self.verifiedAt = verifiedAt
    }
}

public struct PaperIdentity: Codable, Hashable, Sendable {
    public var doi: String?
    public var arxivID: String?
    public var normalizedTitleHash: String?

    public init(doi: String? = nil, arxivID: String? = nil, normalizedTitleHash: String? = nil) {
        self.doi = doi
        self.arxivID = arxivID
        self.normalizedTitleHash = normalizedTitleHash
    }
}

public enum AuthorityDecision: String, Codable, Hashable, Sendable {
    case accepted
    case rejected
    case needsReview
}

public struct AuthorityEvaluation: Codable, Hashable, Sendable {
    public var decision: AuthorityDecision
    public var score: Int
    public var reasons: [String]

    public init(decision: AuthorityDecision, score: Int, reasons: [String] = []) {
        self.decision = decision
        self.score = score
        self.reasons = reasons
    }
}

public enum PipelineStage: String, Codable, Hashable, Sendable {
    case discovering
    case merging
    case ranking
    case downloading
    case extracting
    case summarizing
    case completed
    case failed
}

public struct PipelineProgress: Codable, Hashable, Sendable {
    public var stage: PipelineStage
    public var completedUnitCount: Int
    public var totalUnitCount: Int
    public var currentPaperID: String?
    public var message: String?

    public init(
        stage: PipelineStage,
        completedUnitCount: Int = 0,
        totalUnitCount: Int = 0,
        currentPaperID: String? = nil,
        message: String? = nil
    ) {
        self.stage = stage
        self.completedUnitCount = completedUnitCount
        self.totalUnitCount = totalUnitCount
        self.currentPaperID = currentPaperID
        self.message = message
    }
}

public enum ProviderRole: String, Codable, Hashable, Sendable {
    case search
    case rerank
    case shortSummary
    case fullSummary
    case extraction
}

public enum SummaryKind: String, Codable, Hashable, Sendable {
    case short
    case full
}

public struct PageAnchor: Codable, Hashable, Sendable {
    public var pageNumber: Int
    public var startOffset: Int
    public var endOffset: Int

    public init(pageNumber: Int, startOffset: Int, endOffset: Int) {
        self.pageNumber = pageNumber
        self.startOffset = startOffset
        self.endOffset = endOffset
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
    public var provenance: [PaperProvenance]
    public var openAccessEvidence: OpenAccessEvidence?

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
        openAccessPDFURL: URL? = nil,
        provenance: [PaperProvenance] = [],
        openAccessEvidence: OpenAccessEvidence? = nil
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
        self.provenance = provenance
        self.openAccessEvidence = openAccessEvidence
    }

    private enum CodingKeys: String, CodingKey {
        case source, sourceID, baseID, doi, title, summary, authors, institutions, categories
        case publishedAt, updatedAt, absURL, pdfURL, venue, citationCount, openAccessPDFURL
        case provenance, openAccessEvidence
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            source: try container.decode(PaperSourceKind.self, forKey: .source),
            sourceID: try container.decode(String.self, forKey: .sourceID),
            baseID: try container.decodeIfPresent(String.self, forKey: .baseID),
            doi: try container.decodeIfPresent(String.self, forKey: .doi),
            title: try container.decode(String.self, forKey: .title),
            summary: try container.decode(String.self, forKey: .summary),
            authors: try container.decodeIfPresent([String].self, forKey: .authors) ?? [],
            institutions: try container.decodeIfPresent([String].self, forKey: .institutions) ?? [],
            categories: try container.decodeIfPresent([String].self, forKey: .categories) ?? [],
            publishedAt: try container.decodeIfPresent(Date.self, forKey: .publishedAt),
            updatedAt: try container.decodeIfPresent(Date.self, forKey: .updatedAt),
            absURL: try container.decodeIfPresent(URL.self, forKey: .absURL),
            pdfURL: try container.decodeIfPresent(URL.self, forKey: .pdfURL),
            venue: try container.decodeIfPresent(String.self, forKey: .venue),
            citationCount: try container.decodeIfPresent(Int.self, forKey: .citationCount),
            openAccessPDFURL: try container.decodeIfPresent(URL.self, forKey: .openAccessPDFURL),
            provenance: try container.decodeIfPresent([PaperProvenance].self, forKey: .provenance) ?? [],
            openAccessEvidence: try container.decodeIfPresent(OpenAccessEvidence.self, forKey: .openAccessEvidence)
        )
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
    public var sha256: String

    public init(
        paperID: String,
        fileURL: URL,
        byteCount: Int,
        mimeType: String,
        downloadedAt: Date,
        sha256: String = ""
    ) {
        self.paperID = paperID
        self.fileURL = fileURL
        self.byteCount = byteCount
        self.mimeType = mimeType
        self.downloadedAt = downloadedAt
        self.sha256 = sha256
    }

    private enum CodingKeys: String, CodingKey {
        case paperID, fileURL, byteCount, mimeType, downloadedAt, sha256
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            paperID: try container.decode(String.self, forKey: .paperID),
            fileURL: try container.decode(URL.self, forKey: .fileURL),
            byteCount: try container.decode(Int.self, forKey: .byteCount),
            mimeType: try container.decode(String.self, forKey: .mimeType),
            downloadedAt: try container.decode(Date.self, forKey: .downloadedAt),
            sha256: try container.decodeIfPresent(String.self, forKey: .sha256) ?? ""
        )
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
    public var kind: SummaryKind
    public var providerProfileID: UUID?
    public var sourceTextHash: String?
    public var anchors: [PageAnchor]
    public var interpretation: PaperInterpretation?

    public init(
        id: UUID = UUID(),
        paperID: String? = nil,
        shortText: String,
        fullText: String?,
        language: String,
        model: String,
        generatedAt: Date,
        sourceRange: String,
        kind: SummaryKind = .short,
        providerProfileID: UUID? = nil,
        sourceTextHash: String? = nil,
        anchors: [PageAnchor] = [],
        interpretation: PaperInterpretation? = nil
    ) {
        self.id = id
        self.paperID = paperID
        self.shortText = shortText
        self.fullText = fullText
        self.language = language
        self.model = model
        self.generatedAt = generatedAt
        self.sourceRange = sourceRange
        self.kind = kind
        self.providerProfileID = providerProfileID
        self.sourceTextHash = sourceTextHash
        self.anchors = anchors
        self.interpretation = interpretation
    }

    private enum CodingKeys: String, CodingKey {
        case id, paperID, shortText, fullText, language, model, generatedAt, sourceRange
        case kind, providerProfileID, sourceTextHash, anchors, interpretation
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID(),
            paperID: try container.decodeIfPresent(String.self, forKey: .paperID),
            shortText: try container.decode(String.self, forKey: .shortText),
            fullText: try container.decodeIfPresent(String.self, forKey: .fullText),
            language: try container.decode(String.self, forKey: .language),
            model: try container.decode(String.self, forKey: .model),
            generatedAt: try container.decode(Date.self, forKey: .generatedAt),
            sourceRange: try container.decode(String.self, forKey: .sourceRange),
            kind: try container.decodeIfPresent(SummaryKind.self, forKey: .kind) ?? .short,
            providerProfileID: try container.decodeIfPresent(UUID.self, forKey: .providerProfileID),
            sourceTextHash: try container.decodeIfPresent(String.self, forKey: .sourceTextHash),
            anchors: try container.decodeIfPresent([PageAnchor].self, forKey: .anchors) ?? [],
            interpretation: try container.decodeIfPresent(PaperInterpretation.self, forKey: .interpretation)
        )
    }
}

public enum PaperInterpretationSectionKind: String, Codable, CaseIterable, Hashable, Sendable {
    case researchQuestion
    case paperStructure
    case method
    case experimentDesign
    case results
    case keyArguments
    case limitations
    case readerFit
    case extensionQuestions
}

public struct PaperInterpretationSection: Codable, Hashable, Sendable, Identifiable {
    public var kind: PaperInterpretationSectionKind
    public var content: String
    public var anchors: [PageAnchor]

    public var id: PaperInterpretationSectionKind { kind }

    public init(kind: PaperInterpretationSectionKind, content: String, anchors: [PageAnchor] = []) {
        self.kind = kind
        self.content = content.cleanedWhitespace
        self.anchors = anchors
    }

    private enum CodingKeys: String, CodingKey {
        case kind, content, anchors
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            kind: try container.decode(PaperInterpretationSectionKind.self, forKey: .kind),
            content: try container.decode(String.self, forKey: .content),
            anchors: try container.decodeIfPresent([PageAnchor].self, forKey: .anchors) ?? []
        )
    }
}

public struct PaperInterpretation: Codable, Hashable, Sendable {
    public static let requiredSectionKinds = PaperInterpretationSectionKind.allCases

    public var sections: [PaperInterpretationSection]
    public var pageCount: Int

    public init(sections: [PaperInterpretationSection], pageCount: Int) {
        self.sections = sections
        self.pageCount = pageCount
    }

    private enum CodingKeys: String, CodingKey {
        case sections, pageCount
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            sections: try container.decodeIfPresent([PaperInterpretationSection].self, forKey: .sections) ?? [],
            pageCount: try container.decodeIfPresent(Int.self, forKey: .pageCount) ?? 0
        )
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
                capabilities: [.shortSummary, .fullSummary, .rerank, .webSearch]
            )
        case .claude:
            LLMProfile(
                name: kind.displayName,
                providerKind: kind,
                apiStyle: .anthropicMessages,
                baseURL: URL(string: "https://api.anthropic.com/v1")!,
                model: "claude-sonnet-4.5",
                apiKey: apiKey,
                capabilities: [.shortSummary, .fullSummary, .rerank, .webSearch, .webExtraction]
            )
        case .gemini:
            LLMProfile(
                name: kind.displayName,
                providerKind: kind,
                apiStyle: .geminiGenerateContent,
                baseURL: URL(string: "https://generativelanguage.googleapis.com/v1beta")!,
                model: "gemini-2.5-pro",
                apiKey: apiKey,
                capabilities: [.shortSummary, .fullSummary, .rerank, .webSearch, .urlContext]
            )
        case .qwen:
            LLMProfile(
                name: kind.displayName,
                providerKind: kind,
                apiStyle: .openAIChatCompletions,
                baseURL: URL(string: "https://dashscope.aliyuncs.com/compatible-mode/v1")!,
                model: "qwen-plus",
                apiKey: apiKey,
                capabilities: [.shortSummary, .fullSummary, .rerank, .webSearch, .webExtraction]
            )
        case .glm:
            LLMProfile(
                name: kind.displayName,
                providerKind: kind,
                apiStyle: .openAIChatCompletions,
                baseURL: URL(string: "https://open.bigmodel.cn/api/paas/v4")!,
                model: "glm-4.7",
                apiKey: apiKey,
                capabilities: [.shortSummary, .fullSummary, .rerank, .webSearch]
            )
        case .kimi:
            LLMProfile(
                name: kind.displayName,
                providerKind: kind,
                apiStyle: .openAIChatCompletions,
                baseURL: URL(string: "https://api.moonshot.cn/v1")!,
                model: "kimi-k2.6",
                apiKey: apiKey,
                capabilities: [.shortSummary, .fullSummary, .rerank, .webSearch, .fileExtraction]
            )
        case .deepSeek:
            LLMProfile(
                name: kind.displayName,
                providerKind: kind,
                apiStyle: .openAIChatCompletions,
                baseURL: URL(string: "https://api.deepseek.com")!,
                model: "deepseek-v4-flash",
                apiKey: apiKey,
                capabilities: [.shortSummary, .fullSummary, .rerank]
            )
        case .custom:
            LLMProfile(
                name: kind.displayName,
                providerKind: kind,
                apiStyle: .openAIChatCompletions,
                baseURL: URL(string: "https://api.example.com/v1")!,
                model: "custom-model",
                apiKey: apiKey,
                capabilities: [.shortSummary, .fullSummary, .rerank]
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

    func supports(_ role: ProviderRole) -> Bool {
        switch role {
        case .search:
            capabilities.contains(.webSearch)
        case .rerank:
            capabilities.contains(.rerank)
        case .shortSummary:
            capabilities.contains(.shortSummary)
        case .fullSummary:
            capabilities.contains(.fullSummary)
        case .extraction:
            !capabilities.intersection([.fileExtraction, .urlContext, .webExtraction]).isEmpty
        }
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

public enum PipelineFailurePhase: String, Codable, Hashable, Sendable {
    case discovery
    case enrichment
    case ranking
    case processing
    case summarizing
}

public struct PipelineFailure: Codable, Hashable, Sendable {
    public var paperID: String?
    public var message: String
    public var source: PaperSourceKind?
    public var phase: PipelineFailurePhase?
    public var isRetryable: Bool

    public init(
        paperID: String?,
        message: String,
        source: PaperSourceKind? = nil,
        phase: PipelineFailurePhase? = nil,
        isRetryable: Bool = false
    ) {
        self.paperID = paperID
        self.message = message
        self.source = source
        self.phase = phase
        self.isRetryable = isRetryable
    }

    public static func sourceUnavailable(_ source: PaperSourceKind, error: Error) -> PipelineFailure {
        PipelineFailure(
            paperID: nil,
            message: technicalMessage(for: error),
            source: source,
            phase: .discovery,
            isRetryable: retryable(error)
        )
    }

    public func userMessage(language: AppLanguage) -> String {
        let sourceName = source.map(Self.displayName) ?? "Source"
        switch phase {
        case .discovery:
            return language.text(
                en: "\(sourceName) is temporarily unavailable and was skipped.",
                zh: "\(sourceName) 暂时不可用，已跳过。"
            )
        case .enrichment:
            return language.text(en: "Metadata could not be completed.", zh: "论文元数据暂未补全。")
        case .ranking:
            return language.text(en: "Ranking fell back to the default rules.", zh: "排序已回退到默认规则。")
        case .processing:
            return language.text(en: "This paper could not be processed.", zh: "这篇论文暂时无法处理。")
        case .summarizing:
            return language.text(en: "The summary can be retried later.", zh: "简介生成失败，可稍后重试。")
        case .none:
            return language.text(en: "One step could not be completed.", zh: "有一个步骤未能完成。")
        }
    }

    private static func technicalMessage(for error: Error) -> String {
        if let http = error as? HTTPError { return http.technicalDescription }
        return String(describing: error)
    }

    private static func retryable(_ error: Error) -> Bool {
        guard let http = error as? HTTPError else { return false }
        return switch http {
        case .cancelled: false
        case .nonSuccessStatus(let status): status == 429 || status >= 500
        case .timeout, .transport: true
        }
    }

    private static func displayName(_ source: PaperSourceKind) -> String {
        switch source {
        case .arxiv: "arXiv"
        case .openAlex: "OpenAlex"
        case .crossref: "Crossref"
        case .unpaywall: "Unpaywall"
        case .web: "Web"
        case .semanticScholar: "Semantic Scholar"
        }
    }
}

public struct DiscoveryResult: Codable, Hashable, Sendable {
    public var candidates: [PaperCandidate]
    public var failures: [PipelineFailure]

    public init(candidates: [PaperCandidate], failures: [PipelineFailure]) {
        self.candidates = candidates
        self.failures = failures
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
