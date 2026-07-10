import Foundation
import Observation
import PaperCore
import SwiftData

@MainActor
@Observable
final class PaperPulseAppModel {
    var feeds: [FeedConfig] = [PaperPulseAppModel.defaultFeed]
    var selectedFeedID: UUID?
    var todayPapers: [PaperRecord] = []
    var summaries: [String: PaperSummary] = [:]
    var lastRun: PipelineResult?
    var llmProfile = LLMProfile.preset(.gpt)
    var providerProfiles: [LLMProfile] = [LLMProfile.preset(.gpt)]
    var appLanguage: AppLanguage = .chinese
    var summaryLanguage: SummaryLanguage = .chinese
    var isRunning = false
    var errorMessage: String?
    var fullSummaryPaperIDs: Set<String> = []
    var providerSettingsMessage: String?
    var providerTestMessage: String?

    private var didBootstrapProviderProfile = false

    var activeFeed: FeedConfig? {
        if let selectedFeedID,
           let feed = feeds.first(where: { $0.id == selectedFeedID }) {
            return feed
        }
        return feeds.first
    }

    func bootstrapFeeds(modelContext: ModelContext) {
        do {
            let persistedFeeds = try PaperPulsePersistenceStore.fetchFeeds(in: modelContext)
            if persistedFeeds.isEmpty {
                feeds = [Self.defaultFeed]
                selectedFeedID = Self.defaultFeed.id
                try PaperPulsePersistenceStore.saveFeed(Self.defaultFeed, in: modelContext)
                persistSelectedFeedID(Self.defaultFeed.id)
                return
            }

            let loadedFeeds = persistedFeeds.map { $0.feedConfig() }
            feeds = Self.removingDuplicateDefaultFeeds(from: loadedFeeds)
            selectedFeedID = resolvedSelectedFeedID(from: loadedFeeds)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func bootstrapProviderProfile() {
        guard !didBootstrapProviderProfile else { return }
        providerProfiles = LLMProfileSettingsStore.standard.loadProfiles(defaultProfiles: providerProfiles)
        llmProfile = providerProfiles.first ?? llmProfile
        appLanguage = restoredAppLanguage()
        summaryLanguage = restoredSummaryLanguage()
        didBootstrapProviderProfile = true
    }

    func saveFeed(_ feed: FeedConfig, modelContext: ModelContext) {
        do {
            try PaperPulsePersistenceStore.saveFeed(feed, in: modelContext)
            if let index = feeds.firstIndex(where: { $0.id == feed.id }) {
                feeds[index] = feed
            } else {
                feeds.append(feed)
            }
            selectFeed(feed)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func selectFeed(_ feed: FeedConfig) {
        selectedFeedID = feed.id
        persistSelectedFeedID(feed.id)
    }

    func run(feed: FeedConfig, modelContext: ModelContext? = nil) async {
        guard !isRunning else { return }
        isRunning = true
        errorMessage = nil
        defer { isRunning = false }

        let job = modelContext.map {
            let job = ProcessingJobEntity(
                feedID: feed.id,
                stageRawValue: PipelineStage.discovering.rawValue
            )
            $0.insert(job)
            try? $0.save()
            return job
        }

        do {
            let directory = try Self.paperDirectory()
            let registry = ProviderRegistry(profiles: providerProfiles)
            let shortProfile = registry.profile(for: .shortSummary, feed: feed) ?? llmProfile
            let reranker = registry.profile(for: .rerank, feed: feed)
                .flatMap { LLMProviderFactory.makeReranker(profile: $0) }
            let pipeline = PaperPipeline(
                sources: [ArxivSource(), OpenAlexSource(), CrossrefSource()],
                augmentors: [],
                ranker: PaperRanker(),
                reranker: reranker,
                downloader: URLSessionPaperDownloader(),
                extractor: PDFKitTextExtractor(),
                llmProvider: configuredLLMProvider(profile: shortProfile),
                summaryLanguage: summaryLanguage,
                shortSummaryProfile: shortProfile
            )
            let result = try await pipeline.run(feed: feed, now: Date(), outputDirectory: directory)
            todayPapers = result.papers
            summaries = Dictionary(uniqueKeysWithValues: result.summaries.compactMap { summary in
                guard let paperID = summary.paperID else { return nil }
                return (paperID, summary)
            })
            lastRun = result
            if let modelContext {
                try PaperPulsePersistenceStore.save(result.persistencePayload(feed: feed), in: modelContext)
            }
            if let job {
                job.stageRawValue = PipelineStage.completed.rawValue
                job.completedUnitCount = result.papers.count
                job.totalUnitCount = result.rankedCandidates.count
                job.updatedAt = Date()
                try? modelContext?.save()
            }
            NotificationCoordinator.shared.notifyRunComplete(selectedCount: result.papers.count)
        } catch {
            if let job {
                job.stageRawValue = PipelineStage.failed.rawValue
                job.failureReason = error.localizedDescription
                job.updatedAt = Date()
                try? modelContext?.save()
            }
            errorMessage = error.localizedDescription
        }
    }

    func applyProviderPreset(_ kind: LLMProviderKind) {
        let apiKey = llmProfile.apiKey
        var updated = LLMProfile.preset(kind).withAPIKey(apiKey)
        updated.id = llmProfile.id
        llmProfile = updated
    }

    func selectLLMProfile(id: UUID) {
        guard let profile = providerProfiles.first(where: { $0.id == id }) else { return }
        llmProfile = profile
    }

    func addLLMProfile(kind: LLMProviderKind) {
        let profile = LLMProfile.preset(kind)
        providerProfiles.append(profile)
        llmProfile = profile
    }

    func saveLLMProfile(apiKey: String? = nil) {
        let profile = apiKey.map { llmProfile.withAPIKey($0) } ?? llmProfile
        do {
            if let index = providerProfiles.firstIndex(where: { $0.id == profile.id }) {
                providerProfiles[index] = profile
            } else {
                providerProfiles.append(profile)
            }
            try LLMProfileSettingsStore.standard.saveProfiles(providerProfiles)
            llmProfile = profile
            providerSettingsMessage = appLanguage.text(en: "Provider settings saved.", zh: "模型设置已保存。")
        } catch {
            providerSettingsMessage = error.localizedDescription
        }
    }

    func saveSummaryLanguage(_ language: SummaryLanguage) {
        summaryLanguage = language
        UserDefaults.standard.set(language.rawValue, forKey: Self.summaryLanguageDefaultsKey)
    }

    func saveAppLanguage(_ language: AppLanguage) {
        appLanguage = language
        UserDefaults.standard.set(language.rawValue, forKey: Self.appLanguageDefaultsKey)
    }

    func testLLMProvider(apiKey: String? = nil) async {
        if let apiKey {
            llmProfile = llmProfile.withAPIKey(apiKey)
        }
        guard !llmProfile.apiKey.isEmpty else {
            providerTestMessage = appLanguage.text(en: "Enter and save an API key first.", zh: "请先输入并保存 API Key。")
            return
        }

        providerTestMessage = appLanguage.text(en: "Testing API...", zh: "正在测试 API...")
        do {
            let candidate = PaperCandidate(
                source: .web,
                sourceID: "provider-test",
                title: "Provider Smoke Test",
                summary: "A short test paper for checking whether the configured model can return structured JSON.",
                authors: ["PaperPulse"],
                categories: ["cs.AI"]
            )
            let record = PaperRecord(candidate: candidate, localFile: nil)
            let text = ExtractedPaperText(
                plainText: "This is a short provider smoke test. Return the requested JSON summary only.",
                pages: [ExtractedPage(pageNumber: 1, text: "Provider smoke test.")]
            )
            let summary = try await LLMProviderFactory
                .makeProvider(profile: llmProfile, summaryLanguage: summaryLanguage)
                .shortSummary(for: record, text: text)
            providerTestMessage = appLanguage.text(
                en: "API test succeeded: \(String(summary.shortText.prefix(80)))",
                zh: "API 测试成功：\(String(summary.shortText.prefix(80)))"
            )
        } catch {
            providerTestMessage = appLanguage.text(
                en: "API test failed: \(error.localizedDescription)",
                zh: "API 测试失败：\(error.localizedDescription)"
            )
        }
    }

    func generateFullSummary(for paper: PaperEntity, modelContext: ModelContext) async {
        guard !fullSummaryPaperIDs.contains(paper.id) else { return }
        fullSummaryPaperIDs.insert(paper.id)
        errorMessage = nil
        defer { fullSummaryPaperIDs.remove(paper.id) }

        do {
            guard paper.pdfPath != nil else {
                throw PaperPulseAppError.missingPDF
            }

            let record = paper.persistedPaper.paperRecord(source: .arxiv)
            guard let localFile = record.localFile else {
                throw PaperPulseAppError.missingPDF
            }

            let text = try await PDFKitTextExtractor().extract(from: localFile)
            let registry = ProviderRegistry(profiles: providerProfiles)
            let fullProfile = activeFeed.flatMap { registry.profile(for: .fullSummary, feed: $0) } ?? llmProfile
            let provider = configuredLLMProvider(profile: fullProfile)
            let generated = try await PaperSummaryService(
                shortProvider: provider,
                fullProvider: provider,
                fullProfile: fullProfile,
                language: summaryLanguage
            ).generateFullSummary(for: record, text: text)
            try saveFullSummary(generated, fallbackPaperID: paper.id, in: modelContext)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func configuredLLMProvider(profile: LLMProfile) -> any LLMProvider {
        guard !profile.apiKey.isEmpty else {
            return LocalRuleSummaryProvider(language: summaryLanguage)
        }
        return LLMProviderFactory.makeProvider(profile: profile, summaryLanguage: summaryLanguage)
    }

    private static func paperDirectory() throws -> URL {
        let base = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base.appendingPathComponent("PaperPulse/PDFs", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func saveFullSummary(_ summary: PaperSummary, fallbackPaperID: String, in modelContext: ModelContext) throws {
        let paperID = summary.paperID ?? fallbackPaperID
        let descriptor = FetchDescriptor<SummaryEntity>(
            predicate: #Predicate { $0.paperID == paperID }
        )
        let existing = try modelContext.fetch(descriptor).first
        if let existing {
            existing.shortText = summary.shortText
            existing.fullText = summary.fullText
            existing.language = summary.language
            existing.model = summary.model
            existing.generatedAt = summary.generatedAt
            existing.sourceRange = summary.sourceRange
            existing.kindRawValue = summary.kind.rawValue
            existing.providerProfileID = summary.providerProfileID
            existing.sourceTextHash = summary.sourceTextHash
            existing.anchorsData = try JSONEncoder().encode(summary.anchors)
        } else {
            modelContext.insert(
                SummaryEntity(
                    id: summary.id,
                    paperID: paperID,
                    shortText: summary.shortText,
                    fullText: summary.fullText,
                    language: summary.language,
                model: summary.model,
                generatedAt: summary.generatedAt,
                sourceRange: summary.sourceRange,
                kindRawValue: summary.kind.rawValue,
                providerProfileID: summary.providerProfileID,
                sourceTextHash: summary.sourceTextHash,
                anchorsData: try JSONEncoder().encode(summary.anchors)
                )
            )
        }
        try modelContext.save()
    }

    static let defaultFeed = FeedConfig(
        id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
        name: "LLM Agents",
        categories: ["cs.AI", "cs.CL", "cs.LG", "cs.RO", "stat.ML"],
        keywords: ["agent", "tool use", "world model", "planning", "embodied"],
        excludedKeywords: ["protein"],
        authorityPolicy: AuthorityPolicy(dailyLimit: 5),
        enableWebAugmentation: false
    )

    private func persistSelectedFeedID(_ id: UUID) {
        UserDefaults.standard.set(id.uuidString, forKey: Self.selectedFeedDefaultsKey)
    }

    private func restoredSelectedFeedID() -> UUID? {
        UserDefaults.standard.string(forKey: Self.selectedFeedDefaultsKey).flatMap(UUID.init(uuidString:))
    }

    private func restoredAppLanguage() -> AppLanguage {
        UserDefaults.standard.string(forKey: Self.appLanguageDefaultsKey)
            .flatMap(AppLanguage.init(rawValue:)) ?? .chinese
    }

    private func restoredSummaryLanguage() -> SummaryLanguage {
        UserDefaults.standard.string(forKey: Self.summaryLanguageDefaultsKey)
            .flatMap(SummaryLanguage.init(rawValue:)) ?? .chinese
    }

    private func resolvedSelectedFeedID(from loadedFeeds: [FeedConfig]) -> UUID? {
        guard let restoredID = restoredSelectedFeedID() else {
            return feeds.first?.id
        }

        if feeds.contains(where: { $0.id == restoredID }) {
            return restoredID
        }

        guard let restoredFeed = loadedFeeds.first(where: { $0.id == restoredID }) else {
            return feeds.first?.id
        }

        if Self.isDefaultSeedVariant(restoredFeed) {
            return feeds.first(where: Self.isDefaultSeedVariant)?.id ?? feeds.first?.id
        }

        return feeds.first(where: { Self.hasSameEditableFields($0, restoredFeed) })?.id ?? feeds.first?.id
    }

    private static func removingDuplicateDefaultFeeds(from feeds: [FeedConfig]) -> [FeedConfig] {
        var hasDefaultFeed = false
        return feeds.filter { feed in
            guard isDefaultSeedVariant(feed) else {
                return true
            }

            defer { hasDefaultFeed = true }
            return !hasDefaultFeed
        }
    }

    private static func isDefaultSeedVariant(_ feed: FeedConfig) -> Bool {
        feed.name == Self.defaultFeed.name &&
            feed.categories == Self.defaultFeed.categories &&
            feed.keywords == Self.defaultFeed.keywords &&
            feed.authorityPolicy.dailyLimit == Self.defaultFeed.authorityPolicy.dailyLimit &&
            feed.enableWebAugmentation == Self.defaultFeed.enableWebAugmentation
    }

    private static func hasSameEditableFields(_ lhs: FeedConfig, _ rhs: FeedConfig) -> Bool {
        lhs.name == rhs.name &&
            lhs.categories == rhs.categories &&
            lhs.keywords == rhs.keywords &&
            lhs.excludedKeywords == rhs.excludedKeywords &&
            lhs.authorityPolicy.dailyLimit == rhs.authorityPolicy.dailyLimit &&
            lhs.enableWebAugmentation == rhs.enableWebAugmentation
    }

    private static let selectedFeedDefaultsKey = "PaperPulse.selectedFeedID"
    private static let appLanguageDefaultsKey = "PaperPulse.appLanguage"
    private static let summaryLanguageDefaultsKey = "PaperPulse.summaryLanguage"
}

private enum PaperPulseAppError: LocalizedError {
    case missingPDF

    var errorDescription: String? {
        switch self {
        case .missingPDF:
            "This paper does not have a local PDF yet."
        }
    }
}
