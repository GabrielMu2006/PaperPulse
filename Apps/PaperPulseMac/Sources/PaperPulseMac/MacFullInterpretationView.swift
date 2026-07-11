import PaperCore
import SwiftUI

struct MacInterpretationPane: View {
    @Environment(PaperPulseMacModel.self) private var appModel
    var paper: PaperRecord
    var summary: PaperSummary
    var markdownURL: URL?
    var onClose: () -> Void

    var body: some View {
        let language = appModel.appLanguage
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(language.text(en: "Full Reading", zh: "完整解读"))
                            .font(.title2.weight(.semibold))
                        Text(paper.candidate.title)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer()
                    Button(action: onClose) {
                        Label(language.text(en: "Close", zh: "关闭"), systemImage: "xmark")
                    }
                }

                Text("\(summary.model) · \(summary.generatedAt.formatted(date: .abbreviated, time: .shortened)) · \(summary.sourceRange)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let markdownURL {
                    Text(language.text(en: "Saved locally: \(markdownURL.lastPathComponent)", zh: "已保存到本地：\(markdownURL.lastPathComponent)"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let interpretation = summary.interpretation {
                    ForEach(interpretation.sections) { section in
                        GroupBox(section.kind.macTitle(language: language)) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(section.content)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text(section.anchors.macPageRange(language: language))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } else {
                    Text(summary.fullText ?? summary.shortText)
                }
            }
            .padding(20)
            .frame(minWidth: 420, maxWidth: .infinity, alignment: .leading)
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
