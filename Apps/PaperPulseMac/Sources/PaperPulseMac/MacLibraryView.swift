import PaperCore
import SwiftUI

enum MacLibraryScope: String, CaseIterable, Identifiable {
    case all
    case favorites

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .all: language.text(en: "All Papers", zh: "全部论文")
        case .favorites: language.text(en: "Favorites", zh: "收藏")
        }
    }
}

enum MacLibraryFilter {
    static func visible(_ papers: [MacPaperEntity], query: String, scope: MacLibraryScope) -> [MacPaperEntity] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return papers.filter { paper in
            let passesScope: Bool
            switch scope {
            case .all: passesScope = true
            case .favorites: passesScope = paper.isFavorite
            }
            guard passesScope else { return false }
            guard !trimmedQuery.isEmpty else { return true }
            return [paper.title, paper.authors.joined(separator: " "), paper.abstract]
                .joined(separator: " ")
                .localizedCaseInsensitiveContains(trimmedQuery)
        }
    }
}

enum MacBrand {
    static let pulseRed = Color(red: 0.94, green: 0.10, blue: 0.12)
    static let pulseMagenta = Color(red: 0.92, green: 0.12, blue: 0.64)
    static let pulsePurple = Color(red: 0.42, green: 0.17, blue: 0.92)
    static let deepBlue = Color(red: 0.05, green: 0.08, blue: 0.18)
    static let warmGold = Color(red: 1.0, green: 0.63, blue: 0.12)

    static var pulseGradient: LinearGradient {
        LinearGradient(
            colors: [pulseRed, pulseMagenta, pulsePurple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var hairline: Color { Color.primary.opacity(0.10) }
    static var quietFill: Color { Color.primary.opacity(0.045) }
}

struct MacSurfaceCard<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .padding(padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(MacBrand.hairline, lineWidth: 1)
        }
    }
}

struct MacPulseMark: View {
    var isActive = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isActive ? MacBrand.pulseGradient : LinearGradient(colors: [MacBrand.quietFill, MacBrand.quietFill], startPoint: .topLeading, endPoint: .bottomTrailing))
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isActive ? .white : MacBrand.pulseRed)
        }
        .frame(width: 22, height: 22)
    }
}

struct MacLibraryRow: View {
    var paper: MacPaperEntity
    var summary: PaperSummary?
    var language: AppLanguage

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "doc.text")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(MacBrand.pulseRed)
                .frame(width: 18, height: 20)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(paper.title)
                        .font(.callout.weight(.semibold))
                        .lineLimit(2)
                    Spacer(minLength: 4)
                    if paper.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(MacBrand.warmGold)
                    }
                }

                if !paper.authors.isEmpty {
                    Text(paper.authors.prefix(3).joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let summary {
                    Text(summary.shortText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Text(paper.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 5)
        .help(paper.title)
    }
}

struct MacSidebarBrandHeader: View {
    var language: AppLanguage
    var isRunning: Bool
    var status: String

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(MacBrand.pulseGradient)
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.90))
                    .offset(y: 4)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text("PaperPulse")
                    .font(.headline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 6)
    }

    private var subtitle: String {
        if isRunning {
            return language.text(en: "Discovering recent papers", zh: "正在发现近期论文")
        }
        if !status.isEmpty {
            return status
        }
        return language.text(en: "Research workbench", zh: "科研论文工作台")
    }
}

struct MacFeedRow: View {
    var feed: FeedConfig
    var language: AppLanguage
    var isActive: Bool
    var isPushing: Bool
    var onSelect: () -> Void
    var onPush: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onSelect) {
                HStack(spacing: 9) {
                    MacPulseMark(isActive: isActive)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(feed.name)
                            .font(.callout.weight(isActive ? .semibold : .regular))
                            .lineLimit(1)
                        Text(feedDetail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)

            Button(action: onPush) {
                if isPushing {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(MacBrand.pulseRed)
                }
            }
            .buttonStyle(.borderless)
            .disabled(isPushing)
            .help(language.text(en: "Push papers for this feed", zh: "为此订阅推送论文"))
        }
        .padding(.vertical, 2)
    }

    private var feedDetail: String {
        let categories = feed.categories.isEmpty
            ? language.text(en: "Any category", zh: "任意分类")
            : feed.categories.joined(separator: ", ")
        let keywords = feed.keywords.prefix(2).joined(separator: ", ")
        guard !keywords.isEmpty else { return categories }
        return "\(categories) · \(keywords)"
    }
}

struct MacLibraryGroupLabel: View {
    var title: String
    var count: Int
    var isActive = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isActive ? "folder.fill" : "folder")
                .foregroundStyle(isActive ? MacBrand.pulseRed : .secondary)
                .frame(width: 16)
            Text(title)
                .lineLimit(1)
            Spacer()
            Text("\(count)")
                .font(.caption.weight(.medium))
                .foregroundStyle(isActive ? MacBrand.pulseRed : .secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(MacBrand.quietFill, in: Capsule())
        }
    }
}

struct MacEmptyInlineRow: View {
    var text: String

    var body: some View {
        Label(text, systemImage: "tray")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.vertical, 6)
    }
}
