import PDFKit
import SwiftData
import SwiftUI

struct LibraryView: View {
    @Environment(PaperPulseAppModel.self) private var appModel
    @Query(sort: \PaperEntity.createdAt, order: .reverse) private var storedPapers: [PaperEntity]
    @Query(sort: \SummaryEntity.generatedAt, order: .reverse) private var storedSummaries: [SummaryEntity]

    var body: some View {
        let language = appModel.appLanguage
        NavigationStack {
            PaperPulseScreen(title: language.text(en: "Library", zh: "论文库")) {
                if storedPapers.isEmpty && appModel.todayPapers.isEmpty {
                    PaperPulseCard {
                        Label(language.text(en: "No saved papers yet", zh: "还没有保存的论文"), systemImage: "books.vertical")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                ForEach(storedPapers) { paper in
                    NavigationLink {
                        PaperDetailView(paper: paper)
                    } label: {
                        PaperPulseCard {
                            Text(paper.title)
                                .font(.headline)
                                .lineLimit(2)
                                .foregroundStyle(.primary)
                            Text(paper.authors.joined(separator: ", "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            if let summary = storedSummaries.first(where: { $0.paperID == paper.id }) {
                                Text(summary.shortText)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }

                if storedPapers.isEmpty {
                    ForEach(appModel.todayPapers) { paper in
                        NavigationLink {
                            if let file = paper.localFile {
                                PDFReaderView(url: file.fileURL)
                                    .navigationTitle(paper.candidate.title)
                            } else {
                                ContentUnavailableView(language.text(en: "No PDF", zh: "没有 PDF"), systemImage: "doc.questionmark")
                            }
                        } label: {
                            Text(paper.candidate.title)
                                .lineLimit(2)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

struct PaperDetailView: View {
    @Environment(PaperPulseAppModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext
    var paper: PaperEntity
    @Query private var summaries: [SummaryEntity]

    init(paper: PaperEntity) {
        self.paper = paper
        let paperID = paper.id
        _summaries = Query(
            filter: #Predicate<SummaryEntity> { summary in
                summary.paperID == paperID
            },
            sort: \SummaryEntity.generatedAt,
            order: .reverse
        )
    }

    private var summary: SummaryEntity? {
        summaries.first
    }

    var body: some View {
        let language = appModel.appLanguage
        PaperPulseScreen(title: language.text(en: "Paper", zh: "论文")) {
            PaperPulseCard {
                Text(paper.title)
                    .font(.title3.weight(.semibold))
                if !paper.authors.isEmpty {
                    Text(paper.authors.joined(separator: ", "))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if let summary {
                PaperPulseCard {
                    Text(language.text(en: "Short Summary", zh: "短简介"))
                        .font(.headline)
                    Text(summary.shortText)
                        .font(.body)
                    Text("Model: \(summary.model) · \(summary.language) · \(summary.sourceRange)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let fullText = summary?.fullText, !fullText.isEmpty {
                PaperPulseCard {
                    Text(language.text(en: "Full Summary", zh: "完整简介"))
                        .font(.headline)
                    Text(fullText)
                        .font(.body)
                }
            }

            PaperPulseCard {
                Button {
                    Task {
                        await appModel.generateFullSummary(for: paper, modelContext: modelContext)
                    }
                } label: {
                    Label(
                        appModel.fullSummaryPaperIDs.contains(paper.id)
                            ? language.text(en: "Generating Full Summary...", zh: "正在生成完整简介...")
                            : language.text(en: "Generate Full Summary", zh: "生成完整简介"),
                        systemImage: "text.book.closed"
                    )
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(appModel.fullSummaryPaperIDs.contains(paper.id) || paper.resolvedPDFURL == nil)

                if let url = paper.resolvedPDFURL {
                    NavigationLink {
                        PDFReaderView(url: url)
                            .navigationTitle(paper.title)
                    } label: {
                        Label(language.text(en: "Open PDF", zh: "打开 PDF"), systemImage: "doc.richtext")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    Label(language.text(en: "PDF is not available", zh: "PDF 不可用"), systemImage: "doc.questionmark")
                        .foregroundStyle(.secondary)
                }
            }

            PaperPulseCard {
                Text(language.text(en: "Abstract", zh: "摘要"))
                    .font(.headline)
                Text(paper.abstract)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .alert(language.text(en: "Action Failed", zh: "操作失败"), isPresented: Binding(
            get: { appModel.errorMessage != nil },
            set: { if !$0 { appModel.errorMessage = nil } }
        )) {
            Button("OK") { appModel.errorMessage = nil }
        } message: {
            Text(appModel.errorMessage ?? "")
        }
    }
}

struct PDFReaderView: UIViewRepresentable {
    var url: URL

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.document = PDFDocument(url: url)
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {}
}
