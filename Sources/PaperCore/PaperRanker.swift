import Foundation

public struct PaperRanker {
    public init() {}

    public func rank(_ candidates: [PaperCandidate], feed: FeedConfig, now: Date, limit: Int? = nil) -> [RankedPaper] {
        var bestByKey: [String: RankedPaper] = [:]

        for candidate in candidates {
            let ranked = score(candidate, feed: feed, now: now)
            let key = dedupeKey(candidate)
            if let existing = bestByKey[key] {
                if ranked.score > existing.score {
                    bestByKey[key] = ranked
                }
            } else {
                bestByKey[key] = ranked
            }
        }

        let selectionLimit = limit ?? feed.authorityPolicy.dailyLimit
        return bestByKey.values.sorted { lhs, rhs in
            if lhs.score != rhs.score {
                return lhs.score > rhs.score
            }
            return (lhs.candidate.publishedAt ?? .distantPast) > (rhs.candidate.publishedAt ?? .distantPast)
        }
        .prefix(selectionLimit)
        .map { $0 }
    }

    private func score(_ candidate: PaperCandidate, feed: FeedConfig, now: Date) -> RankedPaper {
        var score = 0
        var reasons: [String] = []
        let title = candidate.title.lowercased()
        let summary = candidate.summary.lowercased()

        for keyword in feed.keywords.map({ $0.lowercased() }) where !keyword.isEmpty {
            if title.contains(keyword) {
                score += 18
                reasons.append("title keyword: \(keyword)")
            }
            if summary.contains(keyword) {
                score += 8
                reasons.append("summary keyword: \(keyword)")
            }
        }

        for keyword in feed.excludedKeywords.map({ $0.lowercased() }) where title.contains(keyword) || summary.contains(keyword) {
            score -= 35
            reasons.append("excluded keyword: \(keyword)")
        }

        if !Set(feed.categories).isDisjoint(with: Set(candidate.categories)) {
            score += 8
            reasons.append("category match")
        }

        let normalizedInstitutions = candidate.institutions.map { $0.lowercased() }
        for institution in feed.authorityPolicy.preferredInstitutions {
            if normalizedInstitutions.contains(where: { $0.contains(institution.lowercased()) }) {
                score += 30
                reasons.append("preferred institution")
                break
            }
        }

        for institution in feed.authorityPolicy.blockedInstitutions {
            if normalizedInstitutions.contains(where: { $0.contains(institution.lowercased()) }) {
                score -= 50
                reasons.append("blocked institution")
                break
            }
        }

        if let venue = candidate.venue?.lowercased() {
            for preferredVenue in feed.authorityPolicy.preferredVenues where venue.contains(preferredVenue.lowercased()) {
                score += 16
                reasons.append("preferred venue")
                break
            }
        }

        if let citationCount = candidate.citationCount {
            score += min(20, citationCount / 2)
            if let minimum = feed.authorityPolicy.minimumCitationCount, citationCount >= minimum {
                score += 5
                reasons.append("citation threshold")
            }
        }

        if let publishedAt = candidate.publishedAt {
            let age = max(0, now.timeIntervalSince(publishedAt))
            let days = age / 86_400
            score += max(0, 12 - Int(days))
            reasons.append("recent")
        }

        if candidate.pdfURL != nil || candidate.openAccessPDFURL != nil {
            score += 4
            reasons.append("open pdf")
        }

        return RankedPaper(candidate: candidate, score: score, reasons: reasons)
    }

    private func dedupeKey(_ candidate: PaperCandidate) -> String {
        if let doi = candidate.doi?.lowercased(), !doi.isEmpty {
            return "doi:\(doi)"
        }
        if let baseID = candidate.baseID?.lowercased(), !baseID.isEmpty {
            return "id:\(baseID)"
        }
        return "title:\(candidate.title.lowercased().slugComponent)"
    }
}
