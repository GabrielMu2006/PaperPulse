import XCTest
@testable import PaperCore

final class RankingTests: XCTestCase {
    func testRanksDeduplicatedCandidatesWithAuthorityAndKeywords() {
        let policy = AuthorityPolicy(
            preferredInstitutions: ["Fudan University", "Tsinghua University"],
            blockedInstitutions: ["Unknown Lab"],
            preferredVenues: ["NeurIPS"],
            minimumCitationCount: 10,
            dailyLimit: 2
        )
        let feed = FeedConfig(
            name: "Agents",
            categories: ["cs.AI"],
            keywords: ["agent", "world model"],
            excludedKeywords: ["protein"],
            authorityPolicy: policy
        )
        let duplicate = PaperCandidate.fixture(
            sourceID: "2607.00001v1",
            doi: "10.123/example",
            title: "World Model Agents",
            summary: "An agent learns a world model.",
            institutions: ["Fudan University"],
            citationCount: 12
        )
        let lowerQualityDuplicate = PaperCandidate.fixture(
            sourceID: "openalex:W1",
            doi: "10.123/example",
            title: "World Model Agents",
            summary: "An agent learns a world model.",
            institutions: ["Unknown Lab"],
            citationCount: 1
        )
        let unrelated = PaperCandidate.fixture(
            sourceID: "2607.00002v1",
            title: "Protein Segmentation",
            summary: "A biomedical paper.",
            institutions: ["Tsinghua University"],
            citationCount: 30
        )

        let ranked = PaperRanker().rank(
            [lowerQualityDuplicate, unrelated, duplicate],
            feed: feed,
            now: Date(timeIntervalSince1970: 1_782_950_400)
        )

        XCTAssertEqual(ranked.map(\.candidate.sourceID), ["2607.00001v1", "2607.00002v1"])
        XCTAssertGreaterThan(ranked[0].score, ranked[1].score)
        XCTAssertTrue(ranked[0].reasons.contains("preferred institution"))
    }

    func testBlockedInstitutionIsHardExcludedEvenWhenItWouldOtherwiseRankFirst() {
        let feed = FeedConfig(
            name: "Agents",
            keywords: ["agent"],
            authorityPolicy: AuthorityPolicy(
                preferredInstitutions: ["Trusted University"],
                blockedInstitutions: ["Blocked Institute"],
                dailyLimit: 5
            )
        )
        let blocked = PaperCandidate.fixture(
            sourceID: "blocked",
            title: "Agent Planning at Blocked Institute",
            summary: "agent agent agent",
            institutions: ["Blocked Institute"],
            citationCount: 1_000
        )
        let accepted = PaperCandidate.fixture(
            sourceID: "accepted",
            title: "Agent Planning",
            summary: "agent",
            institutions: ["Trusted University"]
        )

        let ranked = PaperRanker().rank([blocked, accepted], feed: feed, now: .now)

        XCTAssertEqual(ranked.map(\.candidate.sourceID), ["accepted"])
    }

    func testUnknownCitationCountIsNotExcludedByMinimumCitationPolicy() {
        let feed = FeedConfig(
            name: "Agents",
            authorityPolicy: AuthorityPolicy(minimumCitationCount: 20, dailyLimit: 5)
        )
        let recentPaper = PaperCandidate.fixture(sourceID: "new", citationCount: nil)

        let ranked = PaperRanker().rank([recentPaper], feed: feed, now: .now)

        XCTAssertEqual(ranked.map(\.candidate.sourceID), ["new"])
    }
}
