import PDFKit
import PaperCore
import SwiftData
import SwiftUI

struct LibraryView: View {
    @Environment(PaperPulseAppModel.self) private var appModel
    @Query(sort: \PaperEntity.createdAt, order: .reverse) private var storedPapers: [PaperEntity]
    @Query(sort: \SummaryEntity.generatedAt, order: .reverse) private var storedSummaries: [SummaryEntity]
    @State private var searchText = ""
    @State private var filter: LibraryFilter = .all

    private var displayedPapers: [PaperEntity] {
        storedPapers.filter { paper in
            let passesFilter: Bool
            switch filter {
            case .all: passesFilter = true
            case .favorites: passesFilter = paper.isFavorite
            case .unread: passesFilter = !paper.isRead
            }
            guard passesFilter else { return false }
            guard !searchText.isEmpty else { return true }
            return [paper.title, paper.authors.joined(separator: " "), paper.abstract]
                .joined(separator: " ")
                .localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        let language = appModel.appLanguage
        NavigationStack {
            List {
                if displayedPapers.isEmpty && appModel.todayPapers.isEmpty {
                    ContentUnavailableView(
                        language.text(en: "No saved papers", zh: "还没有保存的论文"),
                        systemImage: "books.vertical",
                        description: Text(language.text(en: "Run a feed to build your offline library.", zh: "运行订阅后，论文会保存在离线库中。"))
                    )
                    .listRowBackground(Color.clear)
                }

                ForEach(displayedPapers) { paper in
                    NavigationLink {
                        PaperDetailView(paper: paper)
                    } label: {
                        LibraryRow(
                            paper: paper,
                            summary: storedSummaries.first(where: { $0.paperID == paper.id }),
                            language: language
                        )
                    }
                }

                if storedPapers.isEmpty {
                    ForEach(appModel.todayPapers) { paper in
                        NavigationLink {
                            if let file = paper.localFile {
                                PDFReaderView(url: file.fileURL)
                                    .navigationTitle(paper.candidate.title)
                                    .navigationBarTitleDisplayMode(.inline)
                            } else {
                                ContentUnavailableView(language.text(en: "No PDF", zh: "没有 PDF"), systemImage: "doc.questionmark")
                            }
                        } label: {
                            Text(paper.candidate.title).lineLimit(2)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle(language.text(en: "Library", zh: "论文库"))
            .searchable(text: $searchText, prompt: language.text(en: "Search papers", zh: "搜索论文"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker(language.text(en: "Filter", zh: "筛选"), selection: $filter) {
                            ForEach(LibraryFilter.allCases) { option in
                                Text(option.title(language: language)).tag(option)
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
        }
    }
}

private struct LibraryRow: View {
    var paper: PaperEntity
    var summary: SummaryEntity?
    var language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(paper.title)
                    .font(.headline)
                    .lineLimit(2)
                if paper.isFavorite {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                        .accessibilityLabel(language.text(en: "Favorite", zh: "已收藏"))
                }
            }
            Text(paper.authors.joined(separator: ", "))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            if let summary {
                Text(summary.shortText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .padding(.vertical, 4)
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

    private var summary: SummaryEntity? { summaries.first }

    var body: some View {
        let language = appModel.appLanguage
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(paper.title).font(.title3.weight(.semibold))
                    if !paper.authors.isEmpty {
                        Text(paper.authors.joined(separator: ", "))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack {
                    Button {
                        paper.isFavorite.toggle()
                        try? modelContext.save()
                    } label: {
                        Label(
                            paper.isFavorite ? language.text(en: "Unfavorite", zh: "取消收藏") : language.text(en: "Favorite", zh: "收藏"),
                            systemImage: paper.isFavorite ? "star.fill" : "star"
                        )
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                    Button {
                        paper.isRead.toggle()
                        try? modelContext.save()
                    } label: {
                        Label(
                            paper.isRead ? language.text(en: "Mark Unread", zh: "标记未读") : language.text(en: "Mark Read", zh: "标记已读"),
                            systemImage: paper.isRead ? "circle" : "checkmark.circle"
                        )
                    }
                    .buttonStyle(.bordered)
                }

                if let summary {
                    GroupBox(language.text(en: "Short Summary", zh: "短简介")) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(summary.shortText).font(.body)
                            Text("\(summary.model) · \(summary.language) · \(summary.sourceRange)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                if let fullText = summary?.fullText, !fullText.isEmpty {
                    GroupBox(language.text(en: "Full Summary", zh: "完整简介")) {
                        Text(fullText).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Button {
                        Task { await appModel.generateFullSummary(for: paper, modelContext: modelContext) }
                    } label: {
                        Label(
                            appModel.fullSummaryPaperIDs.contains(paper.id)
                                ? language.text(en: "Generating Full Summary...", zh: "正在生成完整简介...")
                                : language.text(en: "Generate Full Summary", zh: "生成完整简介"),
                            systemImage: "text.book.closed"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(appModel.fullSummaryPaperIDs.contains(paper.id) || paper.resolvedPDFURL == nil)

                    if let url = paper.resolvedPDFURL {
                        NavigationLink {
                            PDFReaderView(url: url)
                                .navigationTitle(paper.title)
                                .navigationBarTitleDisplayMode(.inline)
                        } label: {
                            Label(language.text(en: "Open PDF", zh: "打开 PDF"), systemImage: "doc.richtext")
                        }
                    } else {
                        Label(language.text(en: "PDF is not available", zh: "PDF 不可用"), systemImage: "doc.questionmark")
                            .foregroundStyle(.secondary)
                    }
                }

                GroupBox(language.text(en: "Abstract", zh: "摘要")) {
                    Text(paper.abstract)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
        }
        .navigationTitle(language.text(en: "Paper", zh: "论文"))
        .navigationBarTitleDisplayMode(.inline)
        .alert(language.text(en: "Action Failed", zh: "操作失败"), isPresented: Binding(
            get: { appModel.errorMessage != nil },
            set: { if !$0 { appModel.errorMessage = nil } }
        )) {
            Button(language.text(en: "OK", zh: "确定")) { appModel.errorMessage = nil }
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
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.document = PDFDocument(url: url)
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {}
}

private enum LibraryFilter: String, CaseIterable, Identifiable {
    case all
    case favorites
    case unread

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .all: language.text(en: "All Papers", zh: "全部论文")
        case .favorites: language.text(en: "Favorites", zh: "收藏")
        case .unread: language.text(en: "Unread", zh: "未读")
        }
    }
}
