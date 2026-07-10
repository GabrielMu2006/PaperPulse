import Foundation

public struct LocalRuleSummaryProvider: LLMProvider {
    private let language: SummaryLanguage

    public var capabilities: Set<ProviderCapability> { [.shortSummary, .fullSummary] }

    public init(language: SummaryLanguage = .chinese) {
        self.language = language
    }

    public func shortSummary(for paper: PaperRecord, text: ExtractedPaperText) async throws -> PaperSummary {
        switch language {
        case .chinese:
            return PaperSummary(
                paperID: paper.id,
                shortText: "简介：\(paper.candidate.title) 主要围绕 \(topicHint(for: paper.candidate)) 展开。该简介由本地保底规则生成，建议配置 LLM API 后生成完整解读。",
                fullText: nil,
                language: language.code,
                model: "local-rule",
                generatedAt: Date(),
                sourceRange: text.pages.isEmpty ? "metadata only" : "pages 1-\(min(text.pages.count, 3))"
            )
        case .english:
            return PaperSummary(
                paperID: paper.id,
                shortText: "Summary: \(paper.candidate.title) focuses on \(englishTopicHint(for: paper.candidate)). This local fallback uses metadata and extracted text only; configure an LLM API for a deeper reading.",
                fullText: nil,
                language: language.code,
                model: "local-rule",
                generatedAt: Date(),
                sourceRange: text.pages.isEmpty ? "metadata only" : "pages 1-\(min(text.pages.count, 3))"
            )
        }
    }

    public func fullSummary(for paper: PaperRecord, text: ExtractedPaperText) async throws -> PaperSummary {
        let excerpt = String(text.plainText.prefix(1_500))
        switch language {
        case .chinese:
            return PaperSummary(
                paperID: paper.id,
                shortText: "简介：\(paper.candidate.title)",
                fullText: """
                完整简介（本地保底版）：
                题目：\(paper.candidate.title)
                作者：\(paper.candidate.authors.joined(separator: ", "))
                主题：\(topicHint(for: paper.candidate))

                可用文本片段：
                \(excerpt)

                注意：这是无云端 LLM 时的本地保底整理，不会推断未出现在元数据或 PDF 文本中的机构、实验结论或引用。
                """,
                language: language.code,
                model: "local-rule",
                generatedAt: Date(),
                sourceRange: text.pages.isEmpty ? "metadata only" : "pages 1-\(text.pages.count)"
            )
        case .english:
            return PaperSummary(
                paperID: paper.id,
                shortText: "Summary: \(paper.candidate.title)",
                fullText: """
                Full summary (local fallback):
                Title: \(paper.candidate.title)
                Authors: \(paper.candidate.authors.joined(separator: ", "))
                Topic: \(englishTopicHint(for: paper.candidate))

                Available text excerpt:
                \(excerpt)

                Note: This is a local fallback used when no cloud LLM is configured. It does not infer institutions, experimental results, citations, or limitations that are not present in metadata or extracted PDF text.
                """,
                language: language.code,
                model: "local-rule",
                generatedAt: Date(),
                sourceRange: text.pages.isEmpty ? "metadata only" : "pages 1-\(text.pages.count)"
            )
        }
    }

    private func topicHint(for paper: PaperCandidate) -> String {
        let text = "\(paper.title) \(paper.summary)".lowercased()
        if text.contains("world model") { return "世界模型与智能体规划" }
        if text.contains("tool") { return "工具调用智能体" }
        if text.contains("robot") || text.contains("embodied") { return "具身智能与机器人" }
        if text.contains("multi-agent") { return "多智能体协作" }
        if text.contains("benchmark") { return "智能体评测基准" }
        return "科研论文主题"
    }

    private func englishTopicHint(for paper: PaperCandidate) -> String {
        let text = "\(paper.title) \(paper.summary)".lowercased()
        if text.contains("world model") { return "world models and agent planning" }
        if text.contains("tool") { return "tool-using agents" }
        if text.contains("robot") || text.contains("embodied") { return "embodied intelligence and robotics" }
        if text.contains("multi-agent") { return "multi-agent collaboration" }
        if text.contains("benchmark") { return "agent evaluation benchmarks" }
        return "the paper's research topic"
    }
}
