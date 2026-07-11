import PDFKit
import PaperCore
import SwiftData
import SwiftUI

struct MacRootView: View {
    @Environment(PaperPulseMacModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openSettings) private var openSettings

    var selectedPaper: PaperRecord? {
        appModel.papers.first { $0.id == appModel.selectedPaperID }
    }

    var body: some View {
        @Bindable var appModel = appModel

        NavigationSplitView {
            List(selection: $appModel.selectedPaperID) {
                ForEach(appModel.papers) { paper in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(paper.candidate.title)
                            .font(.headline)
                            .lineLimit(2)
                        Text(paper.candidate.authors.prefix(3).joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .tag(paper.id)
                }
            }
            .navigationTitle(appModel.appLanguage.text(en: "Papers", zh: "论文"))
            .toolbar {
                Button {
                    openSettings()
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }

                Button {
                    if let feed = appModel.activeFeed {
                        Task { await appModel.run(feed: feed, modelContext: modelContext) }
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(appModel.isRunning)
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
