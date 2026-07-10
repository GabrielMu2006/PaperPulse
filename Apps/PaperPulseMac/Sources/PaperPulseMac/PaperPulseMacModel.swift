import Foundation
import Observation
import PaperCore

@MainActor
@Observable
final class PaperPulseMacModel {
    var feed = FeedConfig(
        name: "LLM Agents",
        categories: ["cs.AI", "cs.CL", "cs.LG", "cs.RO", "stat.ML"],
        keywords: ["agent", "tool use", "world model", "planning", "embodied"],
        authorityPolicy: AuthorityPolicy(dailyLimit: 8)
    )
    var papers: [PaperRecord] = []
    var summaries: [String: PaperSummary] = [:]
    var selectedPaperID: String?
    var llmProfile = LLMProfile.preset(.gpt)
    var appLanguage: AppLanguage = .chinese
    var summaryLanguage: SummaryLanguage = .chinese
    var isRunning = false
    var status = "Ready"

    private var didBootstrapProviderProfile = false

    func bootstrapProviderProfile() {
        guard !didBootstrapProviderProfile else { return }
        llmProfile = MacLLMProfileSettingsStore.standard.loadProfile(defaultProfile: llmProfile)
        appLanguage = restoredAppLanguage()
        summaryLanguage = restoredSummaryLanguage()
        didBootstrapProviderProfile = true
    }

    func runDefaultFeed() async {
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }

        do {
            let directory = try Self.paperDirectory()
            let pipeline = PaperPipeline(
                sources: [ArxivSource(), OpenAlexSource(), CrossrefSource()],
                augmentors: [],
                ranker: PaperRanker(),
                downloader: URLSessionPaperDownloader(),
                extractor: PDFKitTextExtractor(),
                llmProvider: configuredLLMProvider()
            )
            let result = try await pipeline.run(feed: feed, now: Date(), outputDirectory: directory)
            papers = result.papers
            summaries = Dictionary(uniqueKeysWithValues: result.summaries.compactMap { summary in
                guard let id = summary.paperID else { return nil }
                return (id, summary)
            })
            selectedPaperID = papers.first?.id
            status = "Selected \(papers.count) papers"
        } catch {
            status = error.localizedDescription
        }
    }

    func applyProviderPreset(_ kind: LLMProviderKind) {
        let apiKey = llmProfile.apiKey
        llmProfile = LLMProfile.preset(kind).withAPIKey(apiKey)
    }

    func saveLLMProfile(apiKey: String? = nil) {
        let profile = apiKey.map { llmProfile.withAPIKey($0) } ?? llmProfile
        do {
            try MacLLMProfileSettingsStore.standard.save(profile)
            llmProfile = profile
            status = appLanguage.text(en: "Provider settings saved.", zh: "模型设置已保存。")
        } catch {
            status = error.localizedDescription
        }
    }

    func saveAppLanguage(_ language: AppLanguage) {
        appLanguage = language
        UserDefaults.standard.set(language.rawValue, forKey: Self.appLanguageDefaultsKey)
    }

    func saveSummaryLanguage(_ language: SummaryLanguage) {
        summaryLanguage = language
        UserDefaults.standard.set(language.rawValue, forKey: Self.summaryLanguageDefaultsKey)
    }

    private func configuredLLMProvider() -> any LLMProvider {
        guard !llmProfile.apiKey.isEmpty else {
            return LocalRuleSummaryProvider(language: summaryLanguage)
        }
        return LLMProviderFactory.makeProvider(profile: llmProfile, summaryLanguage: summaryLanguage)
    }

    private func restoredSummaryLanguage() -> SummaryLanguage {
        UserDefaults.standard.string(forKey: Self.summaryLanguageDefaultsKey)
            .flatMap(SummaryLanguage.init(rawValue:)) ?? .chinese
    }

    private func restoredAppLanguage() -> AppLanguage {
        UserDefaults.standard.string(forKey: Self.appLanguageDefaultsKey)
            .flatMap(AppLanguage.init(rawValue:)) ?? .chinese
    }

    private static let appLanguageDefaultsKey = "PaperPulse.appLanguage"
    private static let summaryLanguageDefaultsKey = "PaperPulse.summaryLanguage"

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
}
