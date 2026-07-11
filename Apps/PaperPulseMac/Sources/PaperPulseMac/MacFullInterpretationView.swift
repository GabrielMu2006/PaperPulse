import PaperCore
import SwiftData
import SwiftUI

struct MacFullInterpretationView: View {
    @Environment(PaperPulseMacModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext
    var paper: PaperRecord
    @State private var summary: PaperSummary?

    var body: some View {
        let language = appModel.appLanguage
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(paper.candidate.title).font(.title2.weight(.semibold))
                if let summary {
                    Text("\(summary.model) · \(summary.generatedAt.formatted(date: .abbreviated, time: .shortened)) · \(summary.sourceRange)")
                        .font(.caption).foregroundStyle(.secondary)
                    if let interpretation = summary.interpretation {
                        ForEach(interpretation.sections) { section in
                            GroupBox(section.kind.macTitle(language: language)) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(section.content).frame(maxWidth: .infinity, alignment: .leading)
                                    Text(section.anchors.macPageRange(language: language)).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    } else {
                        Text(summary.fullText ?? summary.shortText)
                    }
                } else if appModel.fullSummaryPaperIDs.contains(paper.id) {
                    ProgressView(language.text(en: "Preparing PDF and generating full reading...", zh: "正在提取 PDF 并生成完整解读..."))
                } else if let error = appModel.fullSummaryErrors[paper.id] {
                    ContentUnavailableView(language.text(en: "Full Reading Unavailable", zh: "完整解读未生成"), systemImage: "exclamationmark.triangle", description: Text(error))
                    Button(language.text(en: "Retry", zh: "重新生成")) { generate() }.buttonStyle(.borderedProminent)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 620, minHeight: 600)
        .toolbar {
            Button { generate() } label: { Label(language.text(en: "Regenerate", zh: "重新生成"), systemImage: "arrow.clockwise") }
                .disabled(appModel.fullSummaryPaperIDs.contains(paper.id))
        }
        .task { summary = try? MacPersistenceStore.fullSummary(for: paper.id, in: modelContext) }
    }

    private func generate() {
        Task {
            await appModel.generateFullSummary(for: paper, modelContext: modelContext)
            summary = try? MacPersistenceStore.fullSummary(for: paper.id, in: modelContext)
        }
    }
}

private extension PaperInterpretationSectionKind {
    func macTitle(language: AppLanguage) -> String {
        switch self {
        case .researchQuestion: language.text(en: "Research Question & Background", zh: "研究问题与背景")
        case .paperStructure: language.text(en: "Paper Structure", zh: "论文结构概览")
        case .method: language.text(en: "Method", zh: "方法")
        case .experimentDesign: language.text(en: "Data & Experimental Design", zh: "数据与实验设计")
        case .results: language.text(en: "Main Results", zh: "主要结果")
        case .keyArguments: language.text(en: "Key Arguments", zh: "关键论证")
        case .limitations: language.text(en: "Limitations & Risks", zh: "局限与风险")
        case .readerFit: language.text(en: "Who Should Read This", zh: "适合读者")
        case .extensionQuestions: language.text(en: "Extension Questions", zh: "可延伸问题")
        }
    }
}

private extension Array where Element == PageAnchor {
    func macPageRange(language: AppLanguage) -> String {
        let pages = map(\.pageNumber).sorted()
        guard let first = pages.first, let last = pages.last else { return language.text(en: "No page anchor", zh: "无页码锚点") }
        return first == last ? language.text(en: "Page \(first)", zh: "第 \(first) 页") : language.text(en: "Pages \(first)-\(last)", zh: "第 \(first)-\(last) 页")
    }
}
