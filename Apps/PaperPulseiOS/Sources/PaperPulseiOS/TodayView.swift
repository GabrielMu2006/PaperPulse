import SwiftUI

struct TodayView: View {
    @Environment(PaperPulseAppModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        let language = appModel.appLanguage
        NavigationStack {
            PaperPulseScreen(title: language.text(en: "Today", zh: "今日")) {
                if let feed = appModel.activeFeed {
                    PaperPulseCard {
                        Text(language.text(en: "Active Feed", zh: "当前订阅"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(feed.name)
                            .font(.headline)
                        Text(feed.keywords.joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Button {
                        Task { await appModel.run(feed: feed, modelContext: modelContext) }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "arrow.clockwise")
                                .font(.title3)
                            Text(appModel.isRunning
                                 ? language.text(en: "Running...", zh: "正在运行...")
                                 : language.text(en: "Run \(feed.name)", zh: "运行 \(feed.name)"))
                                .font(.headline)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .padding(.horizontal, 18)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(appModel.isRunning)
                } else {
                    PaperPulseCard {
                        Label(language.text(en: "Create a feed before running a search", zh: "请先创建订阅再检索"), systemImage: "line.3.horizontal.decrease.circle")
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text(language.text(en: "Selected Papers", zh: "已选论文"))
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    if appModel.todayPapers.isEmpty {
                        PaperPulseCard {
                        Label(
                            appModel.isRunning
                                ? language.text(en: "Searching academic sources, downloading PDFs, and summarizing...", zh: "正在检索学术源、下载 PDF 并生成简介...")
                                : language.text(en: "No papers selected yet", zh: "还没有选中的论文"),
                            systemImage: appModel.isRunning ? "arrow.clockwise" : "doc.text.magnifyingglass"
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        }
                    }

                    ForEach(appModel.todayPapers) { paper in
                        PaperPulseCard {
                            Text(paper.candidate.title)
                                .font(.headline)
                            Text(appModel.summaries[paper.id]?.shortText ?? paper.candidate.summary)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(4)
                        }
                    }
                }

                if let lastRun = appModel.lastRun, !lastRun.failures.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(language.text(en: "Run Notes", zh: "运行说明"))
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        ForEach(lastRun.failures, id: \.self) { failure in
                            PaperPulseCard {
                                Text(failure.userMessage(language: language))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .alert(language.text(en: "Run Failed", zh: "运行失败"), isPresented: Binding(
                get: { appModel.errorMessage != nil },
                set: { if !$0 { appModel.errorMessage = nil } }
            )) {
                Button("OK") { appModel.errorMessage = nil }
            } message: {
                Text(appModel.errorMessage ?? "")
            }
        }
    }
}
