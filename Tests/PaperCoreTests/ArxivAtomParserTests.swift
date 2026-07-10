import XCTest
@testable import PaperCore

final class ArxivAtomParserTests: XCTestCase {
    func testParsesArxivAtomEntryIntoPaperCandidate() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <feed xmlns="http://www.w3.org/2005/Atom">
          <entry>
            <id>http://arxiv.org/abs/2607.05174v1</id>
            <updated>2026-07-06T10:00:00Z</updated>
            <published>2026-07-06T09:00:00Z</published>
            <title>AgentGym2: Benchmarking Large Language Model Agents</title>
            <summary>We present a de-idealized benchmark for LLM agents.</summary>
            <author><name>Zhiheng Xi</name></author>
            <author><name>Dingwen Yang</name></author>
            <category term="cs.AI"/>
            <category term="cs.CL"/>
            <link href="http://arxiv.org/abs/2607.05174v1" rel="alternate" type="text/html"/>
            <link title="pdf" href="https://arxiv.org/pdf/2607.05174v1.pdf" rel="related" type="application/pdf"/>
          </entry>
        </feed>
        """

        let candidates = try ArxivAtomParser().parse(Data(xml.utf8))

        XCTAssertEqual(candidates.count, 1)
        XCTAssertEqual(candidates[0].sourceID, "2607.05174v1")
        XCTAssertEqual(candidates[0].baseID, "2607.05174")
        XCTAssertEqual(candidates[0].title, "AgentGym2: Benchmarking Large Language Model Agents")
        XCTAssertEqual(candidates[0].authors, ["Zhiheng Xi", "Dingwen Yang"])
        XCTAssertEqual(candidates[0].categories, ["cs.AI", "cs.CL"])
        XCTAssertEqual(candidates[0].absURL?.absoluteString, "http://arxiv.org/abs/2607.05174v1")
        XCTAssertEqual(candidates[0].pdfURL?.absoluteString, "https://arxiv.org/pdf/2607.05174v1.pdf")
    }
}
