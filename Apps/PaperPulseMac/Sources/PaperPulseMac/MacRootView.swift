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
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebarColumn
                .navigationSplitViewColumnWidth(min: 300, ideal: 340, max: 420)
        } detail: {
            detailColumn
        }
        .preferredColorScheme(.dark)
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

    private var sidebarColumn: some View {
        let language = appModel.appLanguage

        return ZStack {
            MacBrandShellBackground()

            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    MacSidebarBrandHeader(
                        language: language,
                        isRunning: appModel.isRunning,
                        status: appModel.status
                    )

                    MacSearchField(
                        text: $libraryQuery,
                        prompt: language.text(en: "Search papers, authors, abstracts", zh: "搜索论文、作者、摘要")
                    )

                    MacScopeToggle(selection: $libraryScope, language: language)

                    HStack(spacing: 8) {
                        MacSidebarActionButton(
                            title: language.text(en: "Settings", zh: "设置"),
                            icon: "gearshape",
                            action: { openSettings() }
                        )
                        .accessibilityIdentifier("mac-settings-button")

                        MacSidebarActionButton(
                            title: language.text(en: "New Feed", zh: "新建订阅"),
                            icon: "plus",
                            action: { editorDraft = MacFeedEditorDraft(keywordLibrary: appModel.keywordLibrary) }
                        )
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 12)

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        feedsPanel(language: language)
                        libraryPanel(language: language)
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 18)
                }
                .scrollContentBackground(.hidden)
            }
        }
    }

    private func feedsPanel(language: AppLanguage) -> some View {
        MacGlassPanel(padding: 12) {
            MacSidebarSectionTitle(title: language.text(en: "Feeds", zh: "订阅"))
            VStack(alignment: .leading, spacing: 8) {
                ForEach(appModel.feeds) { feed in
                    let isActive = appModel.activeFeed?.id == feed.id
                    MacFeedRow(
                        feed: feed,
                        language: language,
                        isActive: isActive,
                        isPushing: appModel.isRunning && isActive,
                        onSelect: { expandOnly(feed) },
                        onPush: { Task { await appModel.run(feed: feed, modelContext: modelContext) } }
                    )
                    .contextMenu {
                        Button(language.text(en: "Edit Feed", zh: "编辑订阅")) {
                            editorDraft = MacFeedEditorDraft(feed: feed, keywordLibrary: appModel.keywordLibrary)
                        }
                        if appModel.feeds.count > 1 {
                            Button(language.text(en: "Delete Feed", zh: "删除订阅"), role: .destructive) {
                                appModel.deleteFeed(feed, modelContext: modelContext)
                                if let active = appModel.activeFeed { expandedFeedIDs = [active.id] }
                            }
                        }
                    }
                }
            }
        }
    }

    private func libraryPanel(language: AppLanguage) -> some View {
        MacGlassPanel(padding: 12) {
            HStack {
                MacSidebarSectionTitle(title: language.text(en: "Library", zh: "论文库"))
                Spacer()
                Text("\(visiblePapers.count)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.70))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.10), in: Capsule())
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(appModel.feeds) { feed in
                    let papers = visiblePapers(for: feed.id)
                    DisclosureGroup(isExpanded: expansionBinding(for: feed.id)) {
                        if papers.isEmpty {
                            MacEmptyInlineRow(text: language.text(en: "No pushed papers", zh: "尚未推送论文"))
                        }
                        ForEach(papers) { paper in
                            MacSelectablePaperRow(
                                paper: paper,
                                summary: shortSummary(for: paper.id),
                                language: language,
                                isSelected: appModel.selectedPaperID == paper.id,
                                onSelect: { appModel.selectedPaperID = paper.id }
                            )
                        }
                    } label: {
                        MacLibraryGroupLabel(
                            title: feed.name,
                            count: papers.count,
                            isActive: appModel.activeFeed?.id == feed.id
                        )
                    }
                    .tint(.white.opacity(0.70))
                }

                if !unclassifiedPapers.isEmpty {
                    DisclosureGroup(isExpanded: $isUnclassifiedExpanded) {
                        ForEach(unclassifiedPapers) { paper in
                            MacSelectablePaperRow(
                                paper: paper,
                                summary: shortSummary(for: paper.id),
                                language: language,
                                isSelected: appModel.selectedPaperID == paper.id,
                                onSelect: { appModel.selectedPaperID = paper.id }
                            )
                        }
                    } label: {
                        MacLibraryGroupLabel(
                            title: language.text(en: "Unclassified", zh: "未归类"),
                            count: unclassifiedPapers.count
                        )
                    }
                    .tint(.white.opacity(0.70))
                }
            }
        }
    }

    @ViewBuilder
    private var detailColumn: some View {
        ZStack {
            MacBrandShellBackground()
            if let selectedPaper {
                PaperDetailView(
                    paper: selectedPaper,
                    summary: appModel.summaries[selectedPaper.id],
                    onOpenFullReading: { columnVisibility = .detailOnly },
                    onCloseFullReading: { columnVisibility = .all }
                )
                .id(selectedPaper.id)
            } else {
                VStack {
                    MacGlassPanel(padding: 24) {
                        Label(
                            appModel.appLanguage.text(en: "No Paper Selected", zh: "未选择论文"),
                            systemImage: "doc.text.magnifyingglass"
                        )
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                        Text(appModel.appLanguage.text(en: "Choose a paper from the library to start reading.", zh: "从论文库中选择一篇论文开始阅读。"))
                            .font(.body)
                            .foregroundStyle(.white.opacity(0.66))
                    }
                    .frame(maxWidth: 460)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(32)
            }
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
    @State private var isFavorite = false
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
                    VStack(alignment: .leading, spacing: 14) {
                        MacSurfaceCard(padding: 18) {
                            HStack(alignment: .top, spacing: 16) {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(paper.candidate.title)
                                        .font(.title2.weight(.semibold))
                                        .lineLimit(4)
                                        .textSelection(.enabled)
                                    if !paper.candidate.authors.isEmpty {
                                        Text(paper.candidate.authors.joined(separator: ", "))
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                            .textSelection(.enabled)
                                    }
                                    HStack(spacing: 8) {
                                        MacInfoPill(
                                            icon: "dot.radiowaves.left.and.right",
                                            text: paper.candidate.source.macDisplayName
                                        )
                                        if let venue = paper.candidate.venue, !venue.isEmpty {
                                            MacInfoPill(icon: "building.columns", text: venue)
                                        }
                                        if let date = paper.candidate.publishedAt {
                                            MacInfoPill(icon: "calendar", text: date.formatted(date: .abbreviated, time: .omitted))
                                        }
                                        if let citations = paper.candidate.citationCount {
                                            MacInfoPill(icon: "quote.bubble", text: "\(citations)")
                                        }
                                    }
                                }
                                Spacer(minLength: 0)
                                Button {
                                    toggleFavorite()
                                } label: {
                                    Label(
                                        isFavorite ? appModel.appLanguage.text(en: "Favorited", zh: "已收藏") : appModel.appLanguage.text(en: "Favorite", zh: "收藏"),
                                        systemImage: isFavorite ? "star.fill" : "star"
                                    )
                                }
                                .buttonStyle(.bordered)
                                .tint(isFavorite ? MacBrand.warmGold : MacBrand.pulseRed)
                            }
                        }

                        MacSurfaceCard {
                            HStack(alignment: .firstTextBaseline) {
                                Label(appModel.appLanguage.text(en: "Brief", zh: "简介"), systemImage: "text.quote")
                                    .font(.headline)
                                Spacer()
                                fullReadingControl
                            }
                            Text(summary?.shortText ?? paper.candidate.summary)
                                .font(.body)
                                .lineSpacing(4)
                                .textSelection(.enabled)
                        }

                        if let error = appModel.fullSummaryErrors[paper.id] {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }

                        if let url = paper.candidate.absURL {
                            MacSurfaceCard(padding: 14) {
                                Link(destination: url) {
                                    Label(appModel.appLanguage.text(en: "Open source page", zh: "打开来源页面"), systemImage: "arrow.up.right.square")
                                }
                            }
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(MacWorkbenchBackground())
            }
        } trailing: {
            ZStack {
                Color.black.opacity(0.20)
                if let file = paper.localFile {
                    MacPDFView(url: file.fileURL)
                } else {
                    VStack {
                        MacGlassPanel(padding: 22) {
                            Label(
                                appModel.appLanguage.text(en: "PDF not downloaded", zh: "尚未下载 PDF"),
                                systemImage: "doc"
                            )
                            .font(.headline)
                            .foregroundStyle(.white)
                            Text(appModel.appLanguage.text(en: "Only open-access PDFs are saved locally.", zh: "仅公开可访问的 PDF 会保存到本地。"))
                                .font(.callout)
                                .foregroundStyle(.white.opacity(0.66))
                        }
                        .frame(maxWidth: 360)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(24)
                }
            }
        }
        .background(MacBrandShellBackground())
        .task(id: paper.id) {
            fullSummary = try? MacPersistenceStore.fullSummary(for: paper.id, in: modelContext)
            isFavorite = (try? MacPersistenceStore.paper(id: paper.id, in: modelContext)?.isFavorite) ?? false
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
            .buttonStyle(.borderedProminent)
            .tint(MacBrand.pulseRed)
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
            .buttonStyle(.borderedProminent)
            .tint(MacBrand.pulseRed)
        }
    }

    private func toggleFavorite() {
        if let entity = try? MacPersistenceStore.paper(id: paper.id, in: modelContext) {
            entity.isFavorite.toggle()
            try? modelContext.save()
            isFavorite = entity.isFavorite
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

struct MacInfoPill: View {
    var icon: String
    var text: String

    var body: some View {
        Label(text, systemImage: icon)
            .font(.caption.weight(.medium))
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(MacBrand.pulseRed.opacity(0.09), in: Capsule())
            .foregroundStyle(MacBrand.paperSecondary)
    }
}

struct MacWorkbenchBackground: View {
    var body: some View {
        MacBrandShellBackground()
    }
}

private extension PaperSourceKind {
    var macDisplayName: String {
        switch self {
        case .arxiv: "arXiv"
        case .semanticScholar: "Semantic Scholar"
        case .openAlex: "OpenAlex"
        case .crossref: "Crossref"
        case .unpaywall: "Unpaywall"
        case .web: "Web"
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
                    .fill(Color.white.opacity(0.14))
                    .frame(width: 8)
                    .overlay {
                        Capsule()
                            .fill(Color.white.opacity(0.24))
                            .frame(width: 2, height: 48)
                    }
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
