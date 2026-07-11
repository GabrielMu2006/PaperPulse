import Foundation
import Observation
import PaperCore
import SwiftData

@MainActor
@Observable
final class PaperPulseMacModel {
    var feeds: [FeedConfig] = [PaperPulseMacModel.defaultFeed]
    var selectedFeedID: UUID?
    var papers: [PaperRecord] = []
    var summaries: [String: PaperSummary] = [:]
    var selectedPaperID: String?
    var llmProfile = LLMProfile.preset(.gpt)
    var providerProfiles: [LLMProfile] = [LLMProfile.preset(.gpt)]
    var appLanguage: AppLanguage = .chinese
    var summaryLanguage: SummaryLanguage = .chinese
    var isRunning = false
    var status = ""
    var errorMessage: String?
    var providerTestMessage: String?
    var fullSummaryPaperIDs: Set<String> = []
    var fullSummaryErrors: [String: String] = [:]
    private(set) var modelContext: ModelContext?

    private var didBootstrap = false

    var activeFeed: FeedConfig? {
        feeds.first { $0.id == selectedFeedID } ?? feeds.first
    }

    func bootstrap(modelContext: ModelContext) {
        self.modelContext = modelContext
        guard !didBootstrap else { return }
        providerProfiles = (try? MacLLMProfileSettingsStore.standard.loadProfiles(defaultProfiles: providerProfiles)) ?? providerProfiles
        let restoredProfileID = UserDefaults.standard.string(forKey: Self.selectedProfileKey).flatMap(UUID.init(uuidString:))
        llmProfile = providerProfiles.first { $0.id == restoredProfileID } ?? providerProfiles[0]
        appLanguage = UserDefaults.standard.string(forKey: Self.appLanguageKey).flatMap(AppLanguage.init(rawValue:)) ?? .chinese
        summaryLanguage = UserDefaults.standard.string(forKey: Self.summaryLanguageKey).flatMap(SummaryLanguage.init(rawValue:)) ?? .chinese

        feeds = (try? MacPersistenceStore.fetchFeeds(in: modelContext)) ?? []
        if feeds.isEmpty {
            feeds = [Self.defaultFeed]
            try? MacPersistenceStore.saveFeed(Self.defaultFeed, in: modelContext)
        }
        selectedFeedID = UserDefaults.standard.string(forKey: Self.selectedFeedKey).flatMap(UUID.init(uuidString:))
        if activeFeed == nil { selectedFeedID = feeds[0].id }
        papers = (try? MacPersistenceStore.fetchPapers(in: modelContext)) ?? []
        summaries = (try? MacPersistenceStore.fetchShortSummaries(in: modelContext)) ?? [:]
        selectedPaperID = papers.first?.id
        didBootstrap = true
    }

    func selectFeed(_ feed: FeedConfig) {
        selectedFeedID = feed.id
        UserDefaults.standard.set(feed.id.uuidString, forKey: Self.selectedFeedKey)
    }

    func saveFeed(_ feed: FeedConfig, modelContext: ModelContext) {
        do {
            try MacPersistenceStore.saveFeed(feed, in: modelContext)
            if let index = feeds.firstIndex(where: { $0.id == feed.id }) { feeds[index] = feed } else { feeds.append(feed) }
            selectFeed(feed)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteFeed(_ feed: FeedConfig, modelContext: ModelContext) {
        guard feeds.count > 1 else { return }
        do {
            try MacPersistenceStore.deleteFeed(id: feed.id, in: modelContext)
            feeds.removeAll { $0.id == feed.id }
            selectFeed(feeds[0])
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func run(feed: FeedConfig, modelContext: ModelContext? = nil) async {
        guard !isRunning else { return }
        isRunning = true
        errorMessage = nil
        defer { isRunning = false }

        do {
            let registry = ProviderRegistry(profiles: providerProfiles)
            let shortProfile = registry.profile(for: .shortSummary, feed: feed) ?? llmProfile
            let reranker = registry.profile(for: .rerank, feed: feed).flatMap { LLMProviderFactory.makeReranker(profile: $0) }
            let pipeline = PaperPipeline(
                sources: academicSources(for: feed),
                augmentors: [],
                ranker: PaperRanker(),
                reranker: reranker,
                downloader: URLSessionPaperDownloader(),
                extractor: PDFKitTextExtractor(),
                llmProvider: configuredProvider(profile: shortProfile),
                summaryLanguage: summaryLanguage,
                shortSummaryProfile: shortProfile
            )
            let result = try await pipeline.run(feed: feed, now: Date(), outputDirectory: try Self.paperDirectory())
            papers = result.papers
            summaries = Dictionary(uniqueKeysWithValues: result.summaries.compactMap { summary in
                summary.paperID.map { ($0, summary) }
            })
            selectedPaperID = papers.first?.id
            if let modelContext {
                try MacPersistenceStore.saveFeed(feed, in: modelContext)
                for paper in result.papers { try MacPersistenceStore.savePaper(paper, in: modelContext) }
                for summary in result.summaries { try MacPersistenceStore.saveSummary(summary, in: modelContext) }
            }
            status = appLanguage.text(en: "Selected \(papers.count) papers", zh: "已选取 \(papers.count) 篇论文")
        } catch {
            errorMessage = error.localizedDescription
            status = appLanguage.text(en: "Run failed", zh: "运行失败")
        }
    }

    func addLLMProfile(kind: LLMProviderKind) {
        let profile = LLMProfile.preset(kind)
        providerProfiles.append(profile)
        selectLLMProfile(profile.id)
        saveLLMProfile()
    }

    func selectLLMProfile(_ id: UUID) {
        guard let profile = providerProfiles.first(where: { $0.id == id }) else { return }
        llmProfile = profile
        UserDefaults.standard.set(id.uuidString, forKey: Self.selectedProfileKey)
    }

    func applyProviderPreset(_ kind: LLMProviderKind) {
        var updated = LLMProfile.preset(kind).withAPIKey(llmProfile.apiKey)
        updated.id = llmProfile.id
        llmProfile = updated
    }

    func saveLLMProfile(apiKey: String? = nil) {
        var profile = apiKey.map { llmProfile.withAPIKey($0) } ?? llmProfile
        profile.name = profile.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? profile.providerKind.displayName : profile.model
        if let index = providerProfiles.firstIndex(where: { $0.id == profile.id }) { providerProfiles[index] = profile } else { providerProfiles.append(profile) }
        do {
            try MacLLMProfileSettingsStore.standard.saveProfiles(providerProfiles)
            selectLLMProfile(profile.id)
            status = appLanguage.text(en: "Provider settings saved.", zh: "模型设置已保存。")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func testLLMProvider(apiKey: String? = nil) async {
        if let apiKey { llmProfile = llmProfile.withAPIKey(apiKey) }
        guard !llmProfile.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            providerTestMessage = appLanguage.text(en: "Enter and save an API key first.", zh: "请先输入并保存 API Key。")
            return
        }

        providerTestMessage = appLanguage.text(en: "Testing API...", zh: "正在测试 API...")
        do {
            let health = try await LLMProviderFactory
                .makeProvider(profile: llmProfile, summaryLanguage: summaryLanguage)
                .healthCheck()
            providerTestMessage = appLanguage.text(
                en: "API test succeeded: \(health.model)",
                zh: "API 测试成功：\(health.model)"
            )
        } catch {
            providerTestMessage = appLanguage.text(
                en: "API test failed: \(error.localizedDescription)",
                zh: "API 测试失败：\(error.localizedDescription)"
            )
        }
    }

    func deleteLLMProfile() {
        guard providerProfiles.count > 1 else { return }
        do {
            try MacLLMProfileSettingsStore.standard.deleteProfile(llmProfile)
            providerProfiles.removeAll { $0.id == llmProfile.id }
            selectLLMProfile(providerProfiles[0].id)
            status = appLanguage.text(en: "Profile deleted.", zh: "模型配置已删除。")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func saveAppLanguage(_ language: AppLanguage) {
        appLanguage = language
        UserDefaults.standard.set(language.rawValue, forKey: Self.appLanguageKey)
    }

    func saveSummaryLanguage(_ language: SummaryLanguage) {
        summaryLanguage = language
        UserDefaults.standard.set(language.rawValue, forKey: Self.summaryLanguageKey)
    }

    func generateFullSummary(for paper: PaperRecord, modelContext: ModelContext) async {
        guard !fullSummaryPaperIDs.contains(paper.id) else { return }
        guard let localFile = paper.localFile else {
            fullSummaryErrors[paper.id] = appLanguage.text(en: "A downloaded PDF is required.", zh: "需要先下载 PDF。")
            return
        }
        fullSummaryPaperIDs.insert(paper.id)
        fullSummaryErrors[paper.id] = nil
        defer { fullSummaryPaperIDs.remove(paper.id) }

        do {
            let text = try await PDFKitTextExtractor().extract(from: localFile)
            let provider = configuredProvider(profile: llmProfile)
            let summary = try await PaperSummaryService(
                shortProvider: provider,
                fullProvider: provider,
                fullProfile: llmProfile,
                language: summaryLanguage
            ).generateFullSummary(for: paper, text: text)
            _ = try MacPersistenceStore.saveFullSummary(summary, for: paper, in: modelContext)
        } catch let error as HTTPError {
            fullSummaryErrors[paper.id] = error.userMessage(language: appLanguage)
        } catch {
            let detail = error.localizedDescription
            fullSummaryErrors[paper.id] = appLanguage.text(
                en: "The full reading could not be generated: \(detail)",
                zh: "完整解读生成失败：\(detail)"
            )
        }
    }

    private func configuredProvider(profile: LLMProfile) -> any LLMProvider {
        profile.apiKey.isEmpty ? LocalRuleSummaryProvider(language: summaryLanguage) : LLMProviderFactory.makeProvider(profile: profile, summaryLanguage: summaryLanguage)
    }

    private func academicSources(for feed: FeedConfig) -> [any PaperSource] {
        feed.enabledSources.compactMap {
            switch $0 {
            case .arxiv: ArxivSource()
            case .openAlex: OpenAlexSource()
            case .crossref: CrossrefSource()
            case .semanticScholar, .unpaywall, .web: nil
            }
        }
    }

    private static func paperDirectory() throws -> URL {
        let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let directory = base.appendingPathComponent("PaperPulse/macOS/PDFs", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static let defaultFeed = FeedConfig(
        id: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
        name: "LLM Agents",
        categories: ["cs.AI", "cs.CL", "cs.LG", "cs.RO", "stat.ML"],
        keywords: ["agent", "tool use", "world model", "planning", "embodied"],
        authorityPolicy: AuthorityPolicy(dailyLimit: 5)
    )

    private static let appLanguageKey = "PaperPulse.macOS.appLanguage"
    private static let summaryLanguageKey = "PaperPulse.macOS.summaryLanguage"
    private static let selectedFeedKey = "PaperPulse.macOS.selectedFeed"
    private static let selectedProfileKey = "PaperPulse.macOS.selectedProfile"
}
