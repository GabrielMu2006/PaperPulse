import Foundation
import XCTest
@testable import PaperCore

final class ModelContractsTests: XCTestCase {
    func testFeedConfigDefaultsAndProviderProfileAssignmentsAreStable() {
        let searchProfileID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let rerankProfileID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let shortSummaryProfileID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        let fullSummaryProfileID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
        let extractionProfileID = UUID(uuidString: "55555555-5555-5555-5555-555555555555")!
        let schedule = FeedSchedule(hour: 9, minute: 30, weekdays: [2, 3, 4, 5, 6])

        let defaults = FeedConfig(name: "Daily papers")
        let configured = FeedConfig(
            name: "Daily papers",
            schedule: schedule,
            searchProviderProfileID: searchProfileID,
            rerankProviderProfileID: rerankProfileID,
            shortSummaryProviderProfileID: shortSummaryProfileID,
            fullSummaryProviderProfileID: fullSummaryProfileID,
            extractionProviderProfileID: extractionProfileID
        )

        XCTAssertEqual(defaults.enabledSources, [.arxiv, .semanticScholar, .openAlex, .crossref])
        XCTAssertEqual(defaults.lookbackDays, 7)
        XCTAssertNil(defaults.schedule)
        XCTAssertNil(defaults.searchProviderProfileID)
        XCTAssertEqual(configured.schedule, schedule)
        XCTAssertEqual(configured.searchProviderProfileID, searchProfileID)
        XCTAssertEqual(configured.rerankProviderProfileID, rerankProfileID)
        XCTAssertEqual(configured.shortSummaryProviderProfileID, shortSummaryProfileID)
        XCTAssertEqual(configured.fullSummaryProviderProfileID, fullSummaryProfileID)
        XCTAssertEqual(configured.extractionProviderProfileID, extractionProfileID)
    }

    func testPaperAndSummaryContractsPreserveEvidenceAndAnchors() {
        let retrievedAt = Date(timeIntervalSince1970: 1_783_000_000)
        let profileID = UUID(uuidString: "66666666-6666-6666-6666-666666666666")!
        let provenance = PaperProvenance(
            source: .openAlex,
            sourceID: "W123",
            sourceURL: URL(string: "https://openalex.org/W123"),
            retrievedAt: retrievedAt
        )
        let evidence = OpenAccessEvidence(
            status: .verified,
            source: .unpaywall,
            url: URL(string: "https://repository.example/paper.pdf"),
            license: "CC-BY-4.0",
            verifiedAt: retrievedAt
        )
        let identity = PaperIdentity(
            doi: "10.1000/example",
            arxivID: "2607.00001",
            normalizedTitleHash: "a1b2c3"
        )
        let evaluation = AuthorityEvaluation(
            decision: .accepted,
            score: 91,
            reasons: ["Preferred institution"]
        )
        let progress = PipelineProgress(
            stage: .summarizing,
            completedUnitCount: 2,
            totalUnitCount: 4,
            currentPaperID: "doi:10.1000/example",
            message: "Creating full summary"
        )
        let anchor = PageAnchor(pageNumber: 3, startOffset: 12, endOffset: 48)

        let candidate = PaperCandidate(
            source: .arxiv,
            sourceID: "2607.00001v1",
            title: "Contract paper",
            summary: "Contract summary.",
            provenance: [provenance],
            openAccessEvidence: evidence
        )
        let summary = PaperSummary(
            paperID: candidate.id,
            shortText: "Short",
            fullText: "Full",
            language: "en",
            model: "test-model",
            generatedAt: retrievedAt,
            sourceRange: "pages 3",
            kind: .full,
            providerProfileID: profileID,
            sourceTextHash: "sha256:abc",
            anchors: [anchor]
        )

        XCTAssertEqual(candidate.provenance, [provenance])
        XCTAssertEqual(candidate.openAccessEvidence, evidence)
        XCTAssertEqual(identity.doi, "10.1000/example")
        XCTAssertEqual(evaluation.decision, .accepted)
        XCTAssertEqual(progress.stage, .summarizing)
        XCTAssertEqual(ProviderRole.rerank.rawValue, "rerank")
        XCTAssertEqual(summary.kind, .full)
        XCTAssertEqual(summary.providerProfileID, profileID)
        XCTAssertEqual(summary.sourceTextHash, "sha256:abc")
        XCTAssertEqual(summary.anchors, [anchor])
    }

    func testNewPaperAndSummaryFieldsHaveBackwardsCompatibleDefaults() {
        let candidate = PaperCandidate(
            source: .arxiv,
            sourceID: "2607.00002v1",
            title: "Existing initializer",
            summary: "Still works."
        )
        let summary = PaperSummary(
            shortText: "Short",
            fullText: nil,
            language: "en",
            model: "test-model",
            generatedAt: Date(timeIntervalSince1970: 0),
            sourceRange: "metadata"
        )

        XCTAssertEqual(candidate.provenance, [])
        XCTAssertNil(candidate.openAccessEvidence)
        XCTAssertEqual(summary.kind, .short)
        XCTAssertNil(summary.providerProfileID)
        XCTAssertNil(summary.sourceTextHash)
        XCTAssertEqual(summary.anchors, [])
    }

    func testLegacyJSONDecodesNewNonoptionalFieldsToDefaults() throws {
        let feedJSON = """
        {
          "id": "77777777-7777-7777-7777-777777777777",
          "name": "Legacy feed",
          "categories": ["cs.AI"],
          "keywords": ["agent"],
          "excludedKeywords": [],
          "authorityPolicy": {
            "preferredInstitutions": [],
            "blockedInstitutions": [],
            "preferredVenues": [],
            "dailyLimit": 8
          },
          "enableWebAugmentation": false
        }
        """
        let candidateJSON = """
        {
          "source": "arxiv",
          "sourceID": "2607.00003v1",
          "title": "Legacy candidate",
          "summary": "Legacy summary"
        }
        """
        let summaryJSON = """
        {
          "id": "88888888-8888-8888-8888-888888888888",
          "paperID": "arxiv:2607.00003",
          "shortText": "Legacy short summary",
          "fullText": null,
          "language": "en",
          "model": "legacy-model",
          "generatedAt": 0,
          "sourceRange": "metadata"
        }
        """
        let decoder = JSONDecoder()

        let feed = try decoder.decode(FeedConfig.self, from: Data(feedJSON.utf8))
        let candidate = try decoder.decode(PaperCandidate.self, from: Data(candidateJSON.utf8))
        let summary = try decoder.decode(PaperSummary.self, from: Data(summaryJSON.utf8))

        XCTAssertEqual(feed.enabledSources, FeedConfig.defaultEnabledSources)
        XCTAssertEqual(feed.lookbackDays, 7)
        XCTAssertNil(feed.schedule)
        XCTAssertEqual(candidate.provenance, [])
        XCTAssertNil(candidate.openAccessEvidence)
        XCTAssertEqual(summary.kind, .short)
        XCTAssertNil(summary.providerProfileID)
        XCTAssertNil(summary.sourceTextHash)
        XCTAssertEqual(summary.anchors, [])
    }
}
