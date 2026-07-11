import PDFKit
import PaperCore
import SwiftData
import SwiftUI

struct MacRootView: View {
    @Environment(PaperPulseMacModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openSettings) private var openSettings
    @Query(sort: \MacPaperEntity.createdAt, order: .reverse) private var storedPapers: [MacPaperEntity]
    @Query(sort: \MacSummaryEntity.generatedAt, order: .reverse) private var storedSummaries: [MacSummaryEntity]
    @State private var libraryQuery = ""
    @State private var libraryScope: MacLibraryScope = .all
    @State private var editorDraft: MacFeedEditorDraft?

    var selectedPaper: PaperRecord? {
        storedPapers.first(where: { $0.id == appModel.selectedPaperID }).flatMap(MacPersistenceStore.record(from:))
    }

    private var visiblePapers: [MacPaperEntity] {
        MacLibraryFilter.visible(storedPapers, query: libraryQuery, scope: libraryScope)
    }

    private func shortSummary(for paperID: String) -> PaperSummary? {
        guard let entity = storedSummaries.first(where: { $0.paperID == paperID && $0.kindRawValue == SummaryKind.short.rawValue }) else { return nil }
        let anchors = (try? JSONDecoder().decode([PageAnchor].self, from: entity.anchorsData)) ?? []
        return PaperSummary(
            id: entity.id,
            paperID: entity.paperID,
            shortText: entity.shortText,
            fullText: entity.fullText,
            language: entity.language,
            model: entity.model,
            generatedAt: entity.generatedAt,
            sourceRange: entity.sourceRange,
            kind: .short,
            providerProfileID: entity.providerProfileID,
            sourceTextHash: entity.sourceTextHash,
            anchors: anchors
        )
    }

    var body: some View {
        @Bindable var appModel = appModel

        NavigationSplitView {
            List(selection: $appModel.selectedPaperID) {
                Section(appModel.appLanguage.text(en: "Feeds", zh: "订阅")) {
                    ForEach(appModel.feeds) { feed in
                        let isActive = appModel.activeFeed?.id == feed.id
                        Button {
                            appModel.selectFeed(feed)
                        } label: {
                            MacFeedRow(feed: feed, isActive: isActive)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(appModel.appLanguage.text(en: "Edit Feed", zh: "编辑订阅")) {
                                editorDraft = MacFeedEditorDraft(feed: feed)
                            }
                            if appModel.feeds.count > 1 {
                                Button(appModel.appLanguage.text(en: "Delete Feed", zh: "删除订阅"), role: .destructive) {
                                    appModel.deleteFeed(feed, modelContext: modelContext)
                                }
                            }
                        }
                    }
                    Button {
                        editorDraft = MacFeedEditorDraft()
                    } label: {
                        Label(appModel.appLanguage.text(en: "New Feed", zh: "新建订阅"), systemImage: "plus")
                    }
                }

                Section(appModel.appLanguage.text(en: "Library", zh: "论文库")) {
                    if visiblePapers.isEmpty {
                        Text(appModel.appLanguage.text(en: "No saved papers", zh: "还没有保存的论文"))
                            .foregroundStyle(.secondary)
                    }
                    ForEach(visiblePapers) { paper in
                        MacLibraryRow(paper: paper, summary: shortSummary(for: paper.id), language: appModel.appLanguage)
                            .tag(paper.id)
                    }
                }
            }
            .searchable(text: $libraryQuery, prompt: appModel.appLanguage.text(en: "Search papers", zh: "搜索论文"))
            .navigationTitle(appModel.appLanguage.text(en: "PaperPulse", zh: "论文速递"))
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Menu {
                        Picker(appModel.appLanguage.text(en: "Library filter", zh: "论文筛选"), selection: $libraryScope) {
                            ForEach(MacLibraryScope.allCases) { scope in
                                Text(scope.title(language: appModel.appLanguage)).tag(scope)
                            }
                        }
                    } label: {
                        Label(appModel.appLanguage.text(en: "Filter", zh: "筛选"), systemImage: "line.3.horizontal.decrease.circle")
                    }
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        openSettings()
                    } label: {
                        Label(appModel.appLanguage.text(en: "Settings", zh: "设置"), systemImage: "gearshape")
                    }
                    .help(appModel.appLanguage.text(en: "Settings", zh: "设置"))
                    .accessibilityIdentifier("mac-settings-button")

                    Button {
                        if let feed = appModel.activeFeed {
                            Task { await appModel.run(feed: feed, modelContext: modelContext) }
                        }
                    } label: {
                        Label(appModel.appLanguage.text(en: "Refresh", zh: "刷新"), systemImage: "arrow.clockwise")
                    }
                    .help(appModel.appLanguage.text(en: "Refresh latest papers", zh: "刷新最新论文"))
                    .accessibilityIdentifier("mac-refresh-button")
                    .disabled(appModel.isRunning)
                }
            }
        } detail: {
            if let selectedPaper {
                PaperDetailView(paper: selectedPaper, summary: appModel.summaries[selectedPaper.id])
            } else {
                ContentUnavailableView("No Paper Selected", systemImage: "doc.text.magnifyingglass")
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        .task {
            appModel.bootstrap(modelContext: modelContext)
        }
        .sheet(item: $editorDraft) { draft in
            MacFeedEditorView(draft: draft) { feed in
                appModel.saveFeed(feed, modelContext: modelContext)
            }
            .environment(appModel)
        }
    }
}

struct PaperDetailView: View {
    @Environment(PaperPulseMacModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext
    var paper: PaperRecord
    var summary: PaperSummary?
    @State private var isShowingFullReading = false

    var body: some View {
        HSplitView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(paper.candidate.title)
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text(paper.candidate.authors.joined(separator: ", "))
                        .foregroundStyle(.secondary)
                    HStack {
                        Button {
                            if let entity = try? MacPersistenceStore.paper(id: paper.id, in: modelContext) {
                                entity.isFavorite.toggle()
                                try? modelContext.save()
                            }
                        } label: { Label(appModel.appLanguage.text(en: "Favorite", zh: "收藏"), systemImage: "star") }
                        Button {
                            if let entity = try? MacPersistenceStore.paper(id: paper.id, in: modelContext) {
                                entity.isRead.toggle()
                                try? modelContext.save()
                            }
                        } label: { Label(appModel.appLanguage.text(en: "Mark Read", zh: "标记已读"), systemImage: "checkmark.circle") }
                        Button {
                            isShowingFullReading = true
                        } label: { Label(appModel.appLanguage.text(en: "Full Reading", zh: "完整解读"), systemImage: "text.book.closed") }
                        .disabled(paper.localFile == nil)
                    }
                    Text(summary?.shortText ?? paper.candidate.summary)
                    if let url = paper.candidate.absURL {
                        Link("Open source page", destination: url)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let file = paper.localFile {
                MacPDFView(url: file.fileURL)
            } else {
                ContentUnavailableView("PDF not downloaded", systemImage: "doc")
            }
        }
        .sheet(isPresented: $isShowingFullReading) {
            MacFullInterpretationView(paper: paper)
                .environment(appModel)
        }
    }
}

struct MacPDFView: NSViewRepresentable {
    var url: URL

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.document = PDFDocument(url: url)
        return view
    }

    func updateNSView(_ nsView: PDFView, context: Context) {}
}
