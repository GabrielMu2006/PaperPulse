import Foundation
import XCTest
@testable import PaperCore

final class AcademicSourceTests: XCTestCase {
    func testArxivSourceAddsProvenanceAndVerifiedOpenAccessEvidence() async throws {
        let response = """
        <?xml version="1.0" encoding="UTF-8"?>
        <feed xmlns="http://www.w3.org/2005/Atom">
          <entry>
            <id>http://arxiv.org/abs/2607.05174v2</id>
            <title>Verified arXiv paper</title>
            <summary>Open paper.</summary>
            <published>2026-07-08T09:00:00Z</published>
            <updated>2026-07-08T10:00:00Z</updated>
            <link href="https://arxiv.org/pdf/2607.05174v2.pdf" title="pdf" type="application/pdf"/>
          </entry>
        </feed>
        """
        let client = StubHTTPClient { request in
            XCTAssertEqual(request.url?.host, "export.arxiv.org")
            return HTTPResponse(data: Data(response.utf8), statusCode: 200, mimeType: "application/atom+xml", finalURL: try XCTUnwrap(request.url))
        }

        let papers = try await ArxivSource(httpClient: client).search(
            feed: FeedConfig(name: "Agents"),
            window: DateInterval(start: Self.date("2026-07-01"), end: Self.date("2026-07-09"))
        )

        XCTAssertEqual(papers[0].provenance.map(\.source), [.arxiv])
        XCTAssertEqual(papers[0].provenance[0].sourceID, "2607.05174v2")
        XCTAssertEqual(papers[0].openAccessEvidence?.status, .verified)
        XCTAssertEqual(papers[0].openAccessEvidence?.source, .arxiv)
        XCTAssertEqual(papers[0].openAccessEvidence?.url, papers[0].openAccessPDFURL)
    }

    func testSemanticScholarSendsOnlyNonemptyAPIKeyAndParsesVerifiedOA() async throws {
        let response = """
        { "data": [{
          "paperId": "semantic-123",
          "title": "Semantic Agent Paper",
          "authors": [{ "name": "Ada Lovelace" }],
          "externalIds": { "DOI": "10.1000/semantic", "ArXiv": "2607.00001v3" },
          "openAccessPdf": { "url": "https://repository.example/semantic.pdf" }
        }] }
        """
        let keyedClient = StubHTTPClient { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "x-api-key"), "secret-key")
            return HTTPResponse(data: Data(response.utf8), statusCode: 200, mimeType: "application/json", finalURL: try XCTUnwrap(request.url))
        }
        let unkeyedClient = StubHTTPClient { request in
            XCTAssertNil(request.value(forHTTPHeaderField: "x-api-key"))
            return HTTPResponse(data: Data(response.utf8), statusCode: 200, mimeType: "application/json", finalURL: try XCTUnwrap(request.url))
        }
        let feed = FeedConfig(name: "Agents")
        let window = DateInterval(start: Self.date("2026-07-01"), end: Self.date("2026-07-09"))

        let keyed = try await SemanticScholarSource(apiKey: "secret-key", httpClient: keyedClient).search(feed: feed, window: window)
        _ = try await SemanticScholarSource(apiKey: "", httpClient: unkeyedClient).search(feed: feed, window: window)

        XCTAssertEqual(keyed[0].baseID, "2607.00001")
        XCTAssertEqual(keyed[0].provenance.map(\.source), [.semanticScholar])
        XCTAssertEqual(keyed[0].openAccessEvidence?.status, .verified)
        XCTAssertEqual(keyed[0].openAccessEvidence?.source, .semanticScholar)
    }

    func testOpenAlexSourceBuildsDateFilteredRequestAndParsesWorkMetadata() async throws {
        let response = """
        {
          "results": [
            {
              "id": "https://openalex.org/W123",
              "doi": "https://doi.org/10.1145/example",
              "display_name": "Open Agent Benchmarks",
              "publication_date": "2026-07-08",
              "cited_by_count": 42,
              "abstract_inverted_index": {
                "Agents": [0],
                "coordinate": [1],
                "tools.": [2]
              },
              "authorships": [
                {
                  "author": { "display_name": "A. Researcher" },
                  "institutions": [{ "display_name": "Stanford University" }]
                }
              ],
              "open_access": { "oa_url": "https://publisher.example/paper.pdf" },
              "primary_location": {
                "source": { "display_name": "Proceedings of ExampleConf" }
              }
            }
          ]
        }
        """
        let client = StubHTTPClient { request in
            let components = try XCTUnwrap(URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false))
            XCTAssertEqual(components.host, "api.openalex.org")
            XCTAssertEqual(components.path, "/works")
            XCTAssertEqual(components.queryValue("search"), "LLM Agents agent")
            XCTAssertEqual(components.queryValue("per-page"), "10")
            XCTAssertEqual(components.queryValue("sort"), "publication_date:desc")
            XCTAssertEqual(
                components.queryValue("filter"),
                "from_publication_date:2026-07-01,to_publication_date:2026-07-09"
            )
            return HTTPResponse(data: Data(response.utf8), statusCode: 200, mimeType: "application/json", finalURL: request.url!)
        }
        let source = OpenAlexSource(httpClient: client)
        let feed = FeedConfig(
            name: "LLM Agents",
            keywords: ["agent"],
            authorityPolicy: AuthorityPolicy(dailyLimit: 3)
        )
        let window = DateInterval(
            start: Self.date("2026-07-01"),
            end: Self.date("2026-07-09")
        )

        let papers = try await source.search(feed: feed, window: window)

        XCTAssertEqual(papers.count, 1)
        XCTAssertEqual(papers[0].source, .openAlex)
        XCTAssertEqual(papers[0].sourceID, "https://openalex.org/W123")
        XCTAssertEqual(papers[0].doi, "10.1145/example")
        XCTAssertEqual(papers[0].title, "Open Agent Benchmarks")
        XCTAssertEqual(papers[0].summary, "Agents coordinate tools.")
        XCTAssertEqual(papers[0].authors, ["A. Researcher"])
        XCTAssertEqual(papers[0].institutions, ["Stanford University"])
        XCTAssertEqual(papers[0].citationCount, 42)
        XCTAssertEqual(papers[0].venue, "Proceedings of ExampleConf")
        XCTAssertEqual(papers[0].openAccessPDFURL?.absoluteString, "https://publisher.example/paper.pdf")
        XCTAssertEqual(papers[0].provenance.map(\.source), [.openAlex])
        XCTAssertEqual(papers[0].openAccessEvidence?.status, .verified)
    }

    func testCrossrefSourceBuildsDateFilteredRequestAndParsesWorkMetadata() async throws {
        let response = """
        {
          "message": {
            "items": [
              {
                "DOI": "10.5555/crossref.example",
                "title": ["Crossref Agent Evaluation"],
                "abstract": "A metadata-rich agent evaluation paper.",
                "author": [
                  { "given": "Ada", "family": "Lovelace" }
                ],
                "issued": { "date-parts": [[2026, 7, 7]] },
                "URL": "https://doi.org/10.5555/crossref.example",
                "container-title": ["Journal of Agent Systems"],
                "link": [
                  {
                    "URL": "https://publisher.example/crossref-agent.pdf",
                    "content-type": "application/pdf"
                  }
                ]
              }
            ]
          }
        }
        """
        let client = StubHTTPClient { request in
            let components = try XCTUnwrap(URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false))
            XCTAssertEqual(components.host, "api.crossref.org")
            XCTAssertEqual(components.path, "/works")
            XCTAssertEqual(components.queryValue("query"), "LLM Agents agent")
            XCTAssertEqual(components.queryValue("rows"), "10")
            XCTAssertEqual(components.queryValue("sort"), "published")
            XCTAssertEqual(components.queryValue("order"), "desc")
            XCTAssertEqual(
                components.queryValue("filter"),
                "from-pub-date:2026-07-01,until-pub-date:2026-07-09"
            )
            return HTTPResponse(data: Data(response.utf8), statusCode: 200, mimeType: "application/json", finalURL: request.url!)
        }
        let source = CrossrefSource(httpClient: client)
        let feed = FeedConfig(
            name: "LLM Agents",
            keywords: ["agent"],
            authorityPolicy: AuthorityPolicy(dailyLimit: 3)
        )
        let window = DateInterval(
            start: Self.date("2026-07-01"),
            end: Self.date("2026-07-09")
        )

        let papers = try await source.search(feed: feed, window: window)

        XCTAssertEqual(papers.count, 1)
        XCTAssertEqual(papers[0].source, .crossref)
        XCTAssertEqual(papers[0].sourceID, "10.5555/crossref.example")
        XCTAssertEqual(papers[0].doi, "10.5555/crossref.example")
        XCTAssertEqual(papers[0].title, "Crossref Agent Evaluation")
        XCTAssertEqual(papers[0].summary, "A metadata-rich agent evaluation paper.")
        XCTAssertEqual(papers[0].authors, ["Ada Lovelace"])
        XCTAssertEqual(papers[0].venue, "Journal of Agent Systems")
        XCTAssertEqual(papers[0].pdfURL?.absoluteString, "https://publisher.example/crossref-agent.pdf")
        XCTAssertNil(papers[0].openAccessPDFURL)
        XCTAssertNil(papers[0].openAccessEvidence)
        XCTAssertEqual(papers[0].provenance.map(\.source), [.crossref])
    }

    func testUnpaywallPDFEnricherAddsOpenAccessPDFURLForDOICandidate() async throws {
        let response = """
        {
          "best_oa_location": {
            "url_for_pdf": "https://repository.example/agent.pdf"
          }
        }
        """
        let client = StubHTTPClient { request in
            let components = try XCTUnwrap(URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false))
            XCTAssertEqual(components.host, "api.unpaywall.org")
            XCTAssertEqual(components.path, "/v2/10.5555/agent")
            XCTAssertEqual(components.queryValue("email"), "paperpulse@example.com")
            return HTTPResponse(data: Data(response.utf8), statusCode: 200, mimeType: "application/json", finalURL: request.url!)
        }
        let enricher = UnpaywallPDFEnricher(email: "paperpulse@example.com", httpClient: client)
        let candidate = PaperCandidate.fixture(
            sourceID: "doi-only",
            doi: "10.5555/agent",
            title: "Repository Agent Paper",
            pdfURL: nil
        )

        let enriched = try await enricher.enrich(candidate)

        XCTAssertEqual(enriched.openAccessPDFURL?.absoluteString, "https://repository.example/agent.pdf")
        XCTAssertNil(enriched.pdfURL)
        XCTAssertEqual(enriched.openAccessEvidence?.status, .verified)
        XCTAssertEqual(enriched.openAccessEvidence?.source, .unpaywall)
        XCTAssertEqual(enriched.provenance.map(\.source), [.unpaywall])
    }

    func testSemanticScholarRejectsMalformedPayload() async {
        let client = StubHTTPClient { request in
            HTTPResponse(data: Data("not json".utf8), statusCode: 200, mimeType: "application/json", finalURL: try XCTUnwrap(request.url))
        }

        await XCTAssertThrowsErrorAsync(
            try await SemanticScholarSource(httpClient: client).search(
                feed: FeedConfig(name: "Agents"),
                window: DateInterval(start: Self.date("2026-07-01"), end: Self.date("2026-07-09"))
            )
        ) { error in
            XCTAssertTrue(error is DecodingError)
        }
    }

    private static func date(_ value: String) -> Date {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)!
    }
}

private extension URLComponents {
    func queryValue(_ name: String) -> String? {
        queryItems?.first(where: { $0.name == name })?.value
    }
}
