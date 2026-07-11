import PaperCore
import SwiftUI

enum MacLibraryScope: String, CaseIterable, Identifiable {
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

enum MacLibraryFilter {
    static func visible(_ papers: [MacPaperEntity], query: String, scope: MacLibraryScope) -> [MacPaperEntity] {
        papers.filter { paper in
            let passesScope: Bool
            switch scope {
            case .all: passesScope = true
            case .favorites: passesScope = paper.isFavorite
            case .unread: passesScope = !paper.isRead
            }
            guard passesScope else { return false }
            guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return true }
            return [paper.title, paper.authors.joined(separator: " "), paper.abstract]
                .joined(separator: " ")
                .localizedCaseInsensitiveContains(query)
        }
    }
}

struct MacLibraryRow: View {
    var paper: MacPaperEntity
    var summary: PaperSummary?
    var language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(paper.title).font(.headline).lineLimit(2)
                if paper.isFavorite {
                    Image(systemName: "star.fill").foregroundStyle(.yellow)
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
        }
        .opacity(paper.isRead ? 0.72 : 1)
        .padding(.vertical, 3)
    }
}

struct MacFeedRow: View {
    var feed: FeedConfig
    var isActive: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isActive ? Color.accentColor : Color.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(feed.name)
                Text(feed.categories.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}
