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
    static let deepBlue = Color(red: 0.03, green: 0.05, blue: 0.16)
    static let deepPurple = Color(red: 0.16, green: 0.02, blue: 0.22)
    static let midnight = Color(red: 0.02, green: 0.01, blue: 0.06)
    static let paper = Color(red: 1.0, green: 0.97, blue: 0.91)
    static let paperSoft = Color(red: 1.0, green: 0.93, blue: 0.84)
    static let paperInk = Color(red: 0.12, green: 0.10, blue: 0.13)
    static let paperSecondary = Color(red: 0.36, green: 0.31, blue: 0.36)
    static let warmGold = Color(red: 1.0, green: 0.63, blue: 0.12)

    static var pulseGradient: LinearGradient {
        LinearGradient(
            colors: [pulseRed, pulseMagenta, pulsePurple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var shellGradient: LinearGradient {
        LinearGradient(
            colors: [
                midnight,
                deepBlue,
                deepPurple,
                Color(red: 0.30, green: 0.02, blue: 0.18),
                Color(red: 0.06, green: 0.03, blue: 0.20)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var paperGradient: LinearGradient {
        LinearGradient(
            colors: [paper, .white, paperSoft],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var glassStroke: Color { Color.white.opacity(0.16) }
    static var glassFill: Color { Color.white.opacity(0.075) }
    static var quietFill: Color { Color.white.opacity(0.10) }
}

struct MacBrandShellBackground: View {
    var body: some View {
        ZStack {
            MacBrand.shellGradient
            RadialGradient(
                colors: [MacBrand.pulseRed.opacity(0.40), .clear],
                center: .topLeading,
                startRadius: 40,
                endRadius: 520
            )
            RadialGradient(
                colors: [MacBrand.pulsePurple.opacity(0.45), .clear],
                center: .bottomTrailing,
                startRadius: 70,
                endRadius: 560
            )
            VStack {
                Spacer()
                LinearGradient(
                    colors: [.clear, MacBrand.pulseMagenta.opacity(0.16), MacBrand.pulsePurple.opacity(0.26)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 120)
                .blur(radius: 30)
            }
        }
        .ignoresSafeArea()
    }
}

struct MacGlassPanel<Content: View>: View {
    var padding: CGFloat = 14
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .padding(padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MacBrand.glassFill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(MacBrand.glassStroke, lineWidth: 1)
        }
    }
}

struct MacFormCard<Content: View>: View {
    var padding: CGFloat = 18
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .padding(padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(.white)
        .tint(MacBrand.pulseRed)
        .background(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.13),
                    Color.white.opacity(0.075),
                    MacBrand.pulsePurple.opacity(0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.20), lineWidth: 1)
        }
        .shadow(color: MacBrand.midnight.opacity(0.26), radius: 14, y: 10)
    }
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
        .foregroundStyle(MacBrand.paperInk)
        .background(MacBrand.paperGradient, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.60), lineWidth: 1)
        }
        .shadow(color: MacBrand.midnight.opacity(0.22), radius: 16, y: 10)
    }
}

struct MacPulseButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(MacBrand.pulseGradient, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(0.24), lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.78 : 1)
    }
}

struct MacSidebarSectionTitle: View {
    var title: String

    var body: some View {
        Text(title.uppercased())
            .font(.caption.weight(.bold))
            .foregroundStyle(.white.opacity(0.58))
            .padding(.horizontal, 2)
    }
}

struct MacBrandPageHeader: View {
    var icon: String
    var title: String
    var subtitle: String?

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(MacBrand.pulseGradient)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.64))
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

struct MacSearchField: View {
    @Binding var text: String
    var prompt: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))
            TextField(prompt, text: $text)
                .textFieldStyle(.plain)
                .font(.callout)
                .foregroundStyle(.white)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.50))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        }
    }
}

struct MacScopeToggle: View {
    @Binding var selection: MacLibraryScope
    var language: AppLanguage

    var body: some View {
        HStack(spacing: 4) {
            ForEach(MacLibraryScope.allCases) { scope in
                Button {
                    selection = scope
                } label: {
                    Text(scope.title(language: language))
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .foregroundStyle(selection == scope ? .white : .white.opacity(0.62))
                        .background {
                            if selection == scope {
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(MacBrand.pulseGradient)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        }
    }
}

struct MacSidebarActionButton: View {
    var title: String
    var icon: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.callout.weight(.semibold))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .foregroundStyle(.white)
                .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }
}

struct MacSelectablePaperRow: View {
    var paper: MacPaperEntity
    var summary: PaperSummary?
    var language: AppLanguage
    var isSelected: Bool
    var onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.13) : Color.clear)
                if isSelected {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(MacBrand.pulseGradient)
                        .frame(width: 3)
                        .padding(.vertical, 7)
                }
                MacLibraryRow(paper: paper, summary: summary, language: language)
                    .padding(.leading, isSelected ? 10 : 8)
                    .padding(.trailing, 8)
                    .padding(.vertical, 3)
            }
        }
        .buttonStyle(.plain)
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
                .foregroundStyle(MacBrand.pulseMagenta)
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
                .foregroundStyle(.white)

                if !paper.authors.isEmpty {
                    Text(paper.authors.prefix(3).joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.62))
                        .lineLimit(1)
                }

                if let summary {
                    Text(summary.shortText)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.56))
                        .lineLimit(2)
                }

                Text(paper.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.42))
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
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.66))
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
                            .foregroundStyle(.white)
                        Text(feedDetail)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.58))
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
                        .foregroundStyle(.white)
                        .padding(5)
                        .background(MacBrand.pulseGradient, in: Circle())
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
                .foregroundStyle(isActive ? MacBrand.pulseMagenta : .white.opacity(0.58))
                .frame(width: 16)
            Text(title)
                .foregroundStyle(.white)
                .lineLimit(1)
            Spacer()
            Text("\(count)")
                .font(.caption.weight(.medium))
                .foregroundStyle(isActive ? .white : .white.opacity(0.68))
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(isActive ? AnyShapeStyle(MacBrand.pulseGradient) : AnyShapeStyle(MacBrand.quietFill), in: Capsule())
        }
    }
}

struct MacEmptyInlineRow: View {
    var text: String

    var body: some View {
        Label(text, systemImage: "tray")
            .font(.caption)
            .foregroundStyle(.white.opacity(0.56))
            .padding(.vertical, 6)
    }
}
