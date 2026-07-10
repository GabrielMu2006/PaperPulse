import Foundation

public struct PaperCandidateMerger {
    public init() {}

    public func merge(_ candidates: [PaperCandidate]) -> [PaperCandidate] {
        var groups: [[PaperCandidate]] = []

        for candidate in candidates {
            let matchingIndexes = groups.indices.filter { index in
                groups[index].contains { candidatesMatch($0, candidate) }
            }

            guard let firstIndex = matchingIndexes.first else {
                groups.append([candidate])
                continue
            }

            groups[firstIndex].append(candidate)
            for index in matchingIndexes.dropFirst().reversed() {
                groups[firstIndex] += groups[index]
                groups.remove(at: index)
            }
        }

        return groups.map(mergeGroup).sorted(by: candidateComesFirst)
    }

    private func mergeGroup(_ group: [PaperCandidate]) -> PaperCandidate {
        let ordered = group.sorted(by: candidateComesFirst)
        var merged = ordered[0]
        merged.baseID = firstNonempty(ordered.map(\.baseID))
        merged.doi = firstNonempty(ordered.map(\.doi))
        merged.title = firstNonempty(ordered.map(\.title)) ?? merged.title
        merged.summary = firstNonempty(ordered.map(\.summary)) ?? ""
        merged.authors = orderedUnion(ordered.map(\.authors))
        merged.institutions = orderedUnion(ordered.map(\.institutions))
        merged.categories = orderedUnion(ordered.map(\.categories))
        merged.publishedAt = ordered.compactMap(\.publishedAt).min()
        merged.updatedAt = ordered.compactMap(\.updatedAt).max()
        merged.absURL = firstURL(ordered.map(\.absURL))
        merged.pdfURL = firstURL(ordered.map(\.pdfURL))
        merged.venue = firstNonempty(ordered.map(\.venue))
        merged.citationCount = ordered.compactMap(\.citationCount).max()
        merged.provenance = orderedUnion(ordered.map { candidate in
            candidate.provenance.isEmpty
                ? [PaperProvenance(source: candidate.source, sourceID: candidate.sourceID, sourceURL: candidate.absURL)]
                : candidate.provenance
        })
        merged.openAccessEvidence = preferredEvidence(from: ordered)
        merged.openAccessPDFURL = firstURL(ordered.map(\.openAccessPDFURL)) ?? merged.openAccessEvidence?.url
        return merged
    }

    private func candidatesMatch(_ lhs: PaperCandidate, _ rhs: PaperCandidate) -> Bool {
        let lhsDOI = normalizedDOI(lhs.doi)
        let rhsDOI = normalizedDOI(rhs.doi)
        if let lhsDOI, let rhsDOI {
            return lhsDOI == rhsDOI
        }

        let lhsArxivID = normalizedArxivID(lhs)
        let rhsArxivID = normalizedArxivID(rhs)
        if let lhsArxivID, let rhsArxivID {
            return lhsArxivID == rhsArxivID
        }

        guard let lhsTitleHash = normalizedTitleHash(lhs.title),
              let rhsTitleHash = normalizedTitleHash(rhs.title) else {
            return false
        }
        return lhsTitleHash == rhsTitleHash
    }

    private func normalizedDOI(_ doi: String?) -> String? {
        guard var value = doi?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !value.isEmpty else {
            return nil
        }
        for prefix in ["https://doi.org/", "http://doi.org/", "doi:"] where value.hasPrefix(prefix) {
            value.removeFirst(prefix.count)
        }
        return value.trimmingCharacters(in: CharacterSet(charactersIn: "."))
    }

    private func normalizedArxivID(_ candidate: PaperCandidate) -> String? {
        let value: String?
        if let baseID = candidate.baseID, !baseID.isEmpty {
            value = baseID
        } else if candidate.source == .arxiv {
            value = candidate.sourceID
        } else {
            value = nil
        }
        return value.map(PaperCandidate.arxivBaseID)?.lowercased()
    }

    private func normalizedTitleHash(_ title: String) -> String? {
        let normalized = title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) }
            .map(String.init)
            .joined()
        guard !normalized.isEmpty else { return nil }

        var hash: UInt64 = 1_469_598_103_934_665_603
        for byte in normalized.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return String(format: "%016llx", hash)
    }

    private func candidateComesFirst(_ lhs: PaperCandidate, _ rhs: PaperCandidate) -> Bool {
        let lhsPriority = sourcePriority(lhs.source)
        let rhsPriority = sourcePriority(rhs.source)
        if lhsPriority != rhsPriority { return lhsPriority < rhsPriority }
        if lhs.sourceID.caseInsensitiveCompare(rhs.sourceID) != .orderedSame {
            return lhs.sourceID.caseInsensitiveCompare(rhs.sourceID) == .orderedAscending
        }
        return lhs.title.caseInsensitiveCompare(rhs.title) == .orderedAscending
    }

    private func sourcePriority(_ source: PaperSourceKind) -> Int {
        switch source {
        case .arxiv: 0
        case .semanticScholar: 1
        case .openAlex: 2
        case .crossref: 3
        case .unpaywall: 4
        case .web: 5
        }
    }

    private func firstNonempty(_ values: [String?]) -> String? {
        values.compactMap { value -> String? in
            guard let value else { return nil }
            let cleaned = value.cleanedWhitespace
            return cleaned.isEmpty ? nil : cleaned
        }.first
    }

    private func firstURL(_ values: [URL?]) -> URL? {
        values.compactMap { $0 }.first
    }

    private func orderedUnion<T: Hashable>(_ collections: [[T]]) -> [T] {
        var seen = Set<T>()
        return collections.flatMap { $0 }.filter { seen.insert($0).inserted }
    }

    private func preferredEvidence(from candidates: [PaperCandidate]) -> OpenAccessEvidence? {
        candidates.compactMap(\.openAccessEvidence).sorted { lhs, rhs in
            let lhsVerified = lhs.status == .verified
            let rhsVerified = rhs.status == .verified
            if lhsVerified != rhsVerified { return lhsVerified }
            if lhs.source != rhs.source { return sourcePriority(lhs.source) < sourcePriority(rhs.source) }
            return (lhs.url?.absoluteString ?? "") < (rhs.url?.absoluteString ?? "")
        }.first
    }
}
