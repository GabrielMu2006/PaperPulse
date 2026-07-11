import PDFKit
import PaperCore
import SwiftData
import SwiftUI

struct MacRootView: View {
    @Environment(PaperPulseMacModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openSettings) private var openSettings
    @Query(sort: \MacPaperEntity.createdAt, order: .reverse) private var storedPapers: [MacPaperEntity]
    @Query(sort: \MacFeedPaperEntity.pushedAt, order: .reverse) private var feedPaperLinks: [MacFeedPaperEntity]
    @Query(sort: \MacSummaryEntity.generatedAt, order: .reverse) private var storedSummaries: [MacSummaryEntity]
    @State private var libraryQuery = ""
    @State private var libraryScope: MacLibraryScope = .all
    @State private var editorDraft: MacFeedEditorDraft?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var expandedFeedIDs: Set<UUID> = []
    @State private var isUnclassifiedExpanded = false

    var selectedPaper: PaperRecord? {
        storedPapers.first(where: { $0.id == appModel.selectedPaperID }).flatMap(MacPersistenceStore.record(from:))
    }

    private var visiblePapers: [MacPaperEntity] {
        MacLibraryFilter.visible(storedPapers, query: libraryQuery, scope: libraryScope)
    }

    private func visiblePapers(for feedID: UUID) -> [MacPaperEntity] {
        let paperIDs = Set(feedPaperLinks.filter { $0.feedID == feedID }.map(\.paperID))
        return visiblePapers.filter { paperIDs.contains($0.id) }
    }

    private var unclassifiedPapers: [MacPaperEntity] {
        let validFeedIDs = Set(appModel.feeds.map(\.id))
        let linkedPaperIDs = Set(feedPaperLinks.filter { validFeedIDs.contains($0.feedID) }.map(\.paperID))
        return visiblePapers.filter { !linkedPaperIDs.contains($0.id) }
    }

    private func expandOnly(_ feed: FeedConfig) {
        appModel.selectFeed(feed)
        expandedFeedIDs = [feed.id]
        isUnclassifiedExpanded = false
    }

    private func expansionBinding(for feedID: UUID) -> Binding<Bool> {
        Binding(
            get: { expandedFeedIDs.contains(feedID) },
            set: { expanded in
                if expanded { expandedFeedIDs.insert(feedID) }
                else { expandedFeedIDs.remove(feedID) }
            }
        )
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

        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(selection: $appModel.selectedPaperID) {
                Section {
                    Button { openSettings() } label: {
                        Label(appModel.appLanguage.text(en: "Settings", zh: "设置"), systemImage: "gearshape")
                    }
                    .accessibilityIdentifier("mac-settings-button")
                }

                Section(appModel.appLanguage.text(en: "Feeds", zh: "订阅")) {
                    ForEach(appModel.feeds) { feed in
                        let isActive = appModel.activeFeed?.id == feed.id
                        MacFeedRow(
                            feed: feed,
                            isActive: isActive,
                            isPushing: appModel.isRunning && isActive,
                            onSelect: { expandOnly(feed) },
                            onPush: { Task { await appModel.run(feed: feed, modelContext: modelContext) } }
                        )
                        .contextMenu {
                            Button(appModel.appLanguage.text(en: "Edit Feed", zh: "编辑订阅")) {
                                editorDraft = MacFeedEditorDraft(feed: feed, keywordLibrary: appModel.keywordLibrary)
                            }
                            if appModel.feeds.count > 1 {
                                Button(appModel.appLanguage.text(en: "Delete Feed", zh: "删除订阅"), role: .destructive) {
                                    appModel.deleteFeed(feed, modelContext: modelContext)
                                    if let active = appModel.activeFeed { expandedFeedIDs = [active.id] }
                                }
                            }
                        }
                    }
                    Button {
                        editorDraft = MacFeedEditorDraft(keywordLibrary: appModel.keywordLibrary)
                    } label: {
                        Label(appModel.appLanguage.text(en: "New Feed", zh: "新建订阅"), systemImage: "plus")
                    }
                }

                Section(appModel.appLanguage.text(en: "Library", zh: "论文库")) {
                    ForEach(appModel.feeds) { feed in
                        let papers = visiblePapers(for: feed.id)
                        DisclosureGroup(isExpanded: expansionBinding(for: feed.id)) {
                            if papers.isEmpty {
                                Text(appModel.appLanguage.text(en: "No pushed papers", zh: "尚未推送论文"))
                                    .foregroundStyle(.secondary)
                            }
                            ForEach(papers) { paper in
                                MacLibraryRow(paper: paper, summary: shortSummary(for: paper.id), language: appModel.appLanguage)
                                    .tag(paper.id)
                            }
                        } label: {
                            HStack {
                                Text(feed.name)
                                Spacer()
                                Text("\(papers.count)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if !unclassifiedPapers.isEmpty {
                        DisclosureGroup(isExpanded: $isUnclassifiedExpanded) {
                            ForEach(unclassifiedPapers) { paper in
                                MacLibraryRow(paper: paper, summary: shortSummary(for: paper.id), language: appModel.appLanguage)
                                    .tag(paper.id)
                            }
                        } label: {
                            HStack {
                                Text(appModel.appLanguage.text(en: "Unclassified", zh: "未归类"))
                                Spacer()
                                Text("\(unclassifiedPapers.count)")
                                    .foregroundStyle(.secondary)
                            }
                        }
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
            }
        } detail: {
            if let selectedPaper {
                PaperDetailView(
                    paper: selectedPaper,
                    summary: appModel.summaries[selectedPaper.id],
                    onOpenFullReading: { columnVisibility = .detailOnly },
                    onCloseFullReading: { columnVisibility = .all }
                )
                .id(selectedPaper.id)
            } else {
                ContentUnavailableView("No Paper Selected", systemImage: "doc.text.magnifyingglass")
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        .task {
            appModel.bootstrap(modelContext: modelContext)
            if let active = appModel.activeFeed { expandedFeedIDs = [active.id] }
        }
        .sheet(item: $editorDraft) { draft in
            MacFeedEditorView(draft: draft) { feed in
                appModel.saveFeed(feed, modelContext: modelContext)
                expandedFeedIDs = [feed.id]
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
    var onOpenFullReading: () -> Void
    var onCloseFullReading: () -> Void
    @State private var fullSummary: PaperSummary?
    @State private var isReadingFull = false
    @AppStorage("PaperPulse.macOS.detailSplitRatio") private var detailSplitRatio = 0.5

    var body: some View {
        MacBalancedSplitView(ratio: $detailSplitRatio) {
            if isReadingFull, let fullSummary {
                MacInterpretationPane(
                    paper: paper,
                    summary: fullSummary,
                    markdownURL: try? MacPersistenceStore.fullSummaryFileURL(for: paper.id, in: modelContext),
                    onClose: {
                        isReadingFull = false
                        onCloseFullReading()
                    },
                    onDelete: deleteFullReading
                )
            } else {
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
                            fullReadingControl
                        }
                        if let error = appModel.fullSummaryErrors[paper.id] {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                        Text(summary?.shortText ?? paper.candidate.summary)
                        if let url = paper.candidate.absURL {
                            Link("Open source page", destination: url)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        } trailing: {
            if let file = paper.localFile {
                MacPDFView(url: file.fileURL)
            } else {
                ContentUnavailableView("PDF not downloaded", systemImage: "doc")
            }
        }
        .task(id: paper.id) {
            fullSummary = try? MacPersistenceStore.fullSummary(for: paper.id, in: modelContext)
            isReadingFull = false
        }
    }

    @ViewBuilder
    private var fullReadingControl: some View {
        let language = appModel.appLanguage
        if appModel.fullSummaryPaperIDs.contains(paper.id) {
            ProgressView(language.text(en: "Generating", zh: "正在生成"))
                .controlSize(.small)
        } else if fullSummary != nil {
            Button {
                isReadingFull = true
                onOpenFullReading()
            } label: {
                Label(language.text(en: "Open Full Reading", zh: "打开完整解读"), systemImage: "text.book.closed")
            }
        } else {
            Button {
                Task {
                    await appModel.generateFullSummary(for: paper, modelContext: modelContext)
                    fullSummary = try? MacPersistenceStore.fullSummary(for: paper.id, in: modelContext)
                }
            } label: {
                Label(
                    appModel.fullSummaryErrors[paper.id] == nil
                        ? language.text(en: "Generate Full Reading", zh: "生成完整解读")
                        : language.text(en: "Retry Full Reading", zh: "重新生成完整解读"),
                    systemImage: "sparkles"
                )
            }
            .disabled(paper.localFile == nil)
        }
    }

    private func deleteFullReading() {
        do {
            try MacPersistenceStore.deleteFullSummary(for: paper.id, in: modelContext)
            fullSummary = nil
            isReadingFull = false
            onCloseFullReading()
        } catch {
            appModel.fullSummaryErrors[paper.id] = appModel.appLanguage.text(en: "The full reading could not be deleted.", zh: "完整解读无法删除。")
        }
    }
}

struct MacBalancedSplitView<Leading: View, Trailing: View>: View {
    @Binding var ratio: Double
    @ViewBuilder var leading: () -> Leading
    @ViewBuilder var trailing: () -> Trailing
    @State private var dragStartRatio: Double?

    var body: some View {
        GeometryReader { proxy in
            let availableWidth = max(1, proxy.size.width - 8)
            HStack(spacing: 0) {
                leading()
                    .frame(width: availableWidth * ratio)
                Rectangle()
                    .fill(.separator)
                    .frame(width: 8)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let start = dragStartRatio ?? ratio
                                dragStartRatio = start
                                ratio = min(max(start + (value.translation.width / availableWidth), 0.25), 0.75)
                            }
                            .onEnded { _ in dragStartRatio = nil }
                    )
                trailing()
                    .frame(width: availableWidth * (1 - ratio))
            }
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
