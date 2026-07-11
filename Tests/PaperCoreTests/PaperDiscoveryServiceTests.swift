import Foundation
import XCTest
@testable import PaperCore

final class PaperDiscoveryServiceTests: XCTestCase {
    func testDiscoverUsesOnlyEnabledSourcesLookbackWindowAndKeepsPartialResults() async {
        let arxiv = RecordingPaperSource(results: [candidate(source: .arxiv, sourceID: "2607.00001v1", title: "arXiv result")])
        let openAlex = RecordingPaperSource(error: DiscoveryTestError.unavailable)
        let ignored = RecordingPaperSource(results: [candidate(source: .openAlex, sourceID: "W-ignored", title: "ignored")])
        let service = PaperDiscoveryService(sources: [
            .arxiv: arxiv,
            .openAlex: openAlex,
            .crossref: ignored
        ])
        let now = Date(timeIntervalSince1970: 1_783_000_000)
        let feed = FeedConfig(
            name: "Agents",
            enabledSources: [.openAlex, .arxiv],
            lookbackDays: 3
        )

        let result = await service.discover(feed: feed, now: now)

        XCTAssertEqual(result.candidates.map(\.sourceID), ["2607.00001v1"])
        XCTAssertEqual(result.failures.count, 1)
        XCTAssertEqual(result.failures[0].source, .openAlex)
        XCTAssertEqual(result.failures[0].phase, .discovery)
        let arxivWindows = await arxiv.windows()
        let openAlexWindows = await openAlex.windows()
        XCTAssertEqual(arxivWindows, [DateInterval(start: now.addingTimeInterval(-3 * 86_400), end: now)])
        XCTAssertEqual(openAlexWindows, [DateInterval(start: now.addingTimeInterval(-3 * 86_400), end: now)])
        let ignoredWindows = await ignored.windows()
        XCTAssertTrue(ignoredWindows.isEmpty)
    }

    func testMergerUsesNormalizedDOIThenUnionsComplementaryMetadata() {
        let arxiv = candidate(
            source: .arxiv,
            sourceID: "2607.00001v2",
            baseID: "2607.00001",
            doi: "https://doi.org/10.1000/Example",
            title: "A Shared Paper",
            summary: "arXiv abstract",
            authors: ["Ada"],
            categories: ["cs.AI"],
            pdfURL: URL(string: "https://arxiv.org/pdf/2607.00001.pdf"),
            openAccessEvidence: OpenAccessEvidence(status: .verified, source: .arxiv, url: URL(string: "https://arxiv.org/pdf/2607.00001.pdf"))
        )
        let crossref = candidate(
            source: .crossref,
            sourceID: "10.1000/example",
            doi: "doi:10.1000/example",
            title: "A Shared Paper",
            summary: "Crossref abstract",
            authors: ["Grace"],
            institutions: ["Example University"],
            categories: ["cs.CL"],
            absURL: URL(string: "https://doi.org/10.1000/example"),
            venue: "Journal of Examples",
            citationCount: 17
        )

        let merged = PaperCandidateMerger().merge([crossref, arxiv])

        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged[0].source, .arxiv)
        XCTAssertEqual(merged[0].summary, "arXiv abstract")
        XCTAssertEqual(merged[0].authors, ["Ada", "Grace"])
        XCTAssertEqual(merged[0].institutions, ["Example University"])
        XCTAssertEqual(merged[0].categories, ["cs.AI", "cs.CL"])
        XCTAssertEqual(merged[0].venue, "Journal of Examples")
        XCTAssertEqual(merged[0].citationCount, 17)
        XCTAssertEqual(merged[0].provenance.map(\.source), [.arxiv, .crossref])
        XCTAssertEqual(merged[0].openAccessEvidence?.source, .arxiv)
    }

    func testMergerFallsBackToArxivBaseIDThenNormalizedTitleHashDeterministically() {
        let crossrefByArxivID = candidate(
            source: .crossref,
            sourceID: "C-1",
            baseID: "2607.00002",
            title: "Different displayed title",
            summary: "crossref"
        )
        let arxiv = candidate(
            source: .arxiv,
            sourceID: "2607.00002v3",
            baseID: "2607.00002",
            title: "Different displayed title",
            summary: "arxiv"
        )
        let titleFirst = candidate(source: .openAlex, sourceID: "W-1", title: "Tool-Using Agents: A Survey", summary: "openalex")
        let titleSecond = candidate(source: .crossref, sourceID: "C-1", title: " tool using agents a survey ", summary: "crossref")

        let merged = PaperCandidateMerger().merge([titleSecond, crossrefByArxivID, titleFirst, arxiv])

        XCTAssertEqual(merged.count, 2)
        XCTAssertEqual(merged[0].source, .arxiv)
        XCTAssertEqual(merged[0].summary, "arxiv")
        XCTAssertEqual(merged[1].source, .openAlex)
        XCTAssertEqual(merged[1].summary, "openalex")
    }

    func testMergerUsesArxivIDWhenOnlyOneRecordHasDOI() {
        let crossref = candidate(
            source: .crossref,
            sourceID: "C-2",
            baseID: "2607.00003",
            doi: "10.1000/crossref-only",
            title: "Crossref title",
            summary: "crossref"
        )
        let arxiv = candidate(
            source: .arxiv,
            sourceID: "2607.00003v1",
            baseID: "2607.00003",
            title: "arXiv title",
            summary: "arxiv"
        )

        let merged = PaperCandidateMerger().merge([crossref, arxiv])

        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged[0].doi, "10.1000/crossref-only")
        XCTAssertEqual(merged[0].provenance.map(\.source), [.arxiv, .crossref])
    }

    private func candidate(
        source: PaperSourceKind,
        sourceID: String,
        baseID: String? = nil,
        doi: String? = nil,
        title: String,
        summary: String = "",
        authors: [String] = [],
        institutions: [String] = [],
        categories: [String] = [],
        absURL: URL? = nil,
        pdfURL: URL? = nil,
        venue: String? = nil,
        citationCount: Int? = nil,
        openAccessEvidence: OpenAccessEvidence? = nil
    ) -> PaperCandidate {
        PaperCandidate(
            source: source,
            sourceID: sourceID,
            baseID: baseID,
            doi: doi,
            title: title,
            summary: summary,
            authors: authors,
            institutions: institutions,
            categories: categories,
            absURL: absURL,
            pdfURL: pdfURL,
            venue: venue,
            citationCount: citationCount,
            openAccessPDFURL: openAccessEvidence?.url,
            provenance: [PaperProvenance(source: source, sourceID: sourceID, sourceURL: absURL)],
            openAccessEvidence: openAccessEvidence
        )
    }
}

private enum DiscoveryTestError: LocalizedError {
    case unavailable

    var errorDescription: String? { "unavailable" }
}
