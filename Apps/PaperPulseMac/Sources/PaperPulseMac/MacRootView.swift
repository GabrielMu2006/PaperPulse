import PDFKit
import PaperCore
import SwiftUI

struct MacRootView: View {
    @Environment(PaperPulseMacModel.self) private var appModel
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
            .navigationTitle("Papers")
            .toolbar {
                Button {
                    openSettings()
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }

                Button {
                    Task { await appModel.runDefaultFeed() }
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
    }
}

struct PaperDetailView: View {
    var paper: PaperRecord
    var summary: PaperSummary?

    var body: some View {
        HSplitView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(paper.candidate.title)
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text(paper.candidate.authors.joined(separator: ", "))
                        .foregroundStyle(.secondary)
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
