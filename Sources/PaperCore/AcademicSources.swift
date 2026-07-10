import Foundation

public struct ArxivSource: PaperSource {
    private let httpClient: HTTPClient
    private let parser: ArxivAtomParser

    public init(httpClient: HTTPClient = URLSessionHTTPClient(), parser: ArxivAtomParser = ArxivAtomParser()) {
        self.httpClient = httpClient
        self.parser = parser
    }

    public func search(feed: FeedConfig, window: DateInterval) async throws -> [PaperCandidate] {
        var components = URLComponents(string: "https://export.arxiv.org/api/query")!
        components.queryItems = [
            URLQueryItem(name: "search_query", value: arxivQuery(feed: feed, window: window)),
            URLQueryItem(name: "start", value: "0"),
            URLQueryItem(name: "max_results", value: String(max(feed.authorityPolicy.dailyLimit * 4, 25))),
            URLQueryItem(name: "sortBy", value: "submittedDate"),
            URLQueryItem(name: "sortOrder", value: "descending")
        ]
        let response = try await httpClient.perform(URLRequest(url: components.url!))
        try response.requireSuccess()
        return try parser.parse(response.data).map { candidate in
            var candidate = candidate
            candidate.provenance = [
                PaperProvenance(source: .arxiv, sourceID: candidate.sourceID, sourceURL: candidate.absURL)
            ]
            if let pdfURL = candidate.openAccessPDFURL {
                candidate.openAccessEvidence = OpenAccessEvidence(
                    status: .verified,
                    source: .arxiv,
                    url: pdfURL
                )
            }
            return candidate
        }
    }

    private func arxivQuery(feed: FeedConfig, window: DateInterval) -> String {
        let categoryQuery = feed.categories.isEmpty
            ? "all:\(feed.name)"
            : feed.categories.map { "cat:\($0)" }.joined(separator: " OR ")
        let keywordQuery = feed.keywords.map { #"all:"\#($0)""# }.joined(separator: " OR ")
        let start = Self.arxivDate(window.start)
        let end = Self.arxivDate(window.end)
        let dateQuery = "submittedDate:[\(start) TO \(end)]"
        if keywordQuery.isEmpty {
            return "(\(categoryQuery)) AND \(dateQuery)"
        }
        return "(\(categoryQuery)) AND (\(keywordQuery)) AND \(dateQuery)"
    }

    private static func arxivDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMddHHmm"
        return formatter.string(from: date)
    }
}

public struct SemanticScholarSource: PaperSource {
    private let httpClient: HTTPClient
    private let apiKey: String

    public init(apiKey: String = "", httpClient: HTTPClient = URLSessionHTTPClient()) {
        self.apiKey = apiKey
        self.httpClient = httpClient
    }

    public func search(feed: FeedConfig, window: DateInterval) async throws -> [PaperCandidate] {
        var components = URLComponents(string: "https://api.semanticscholar.org/graph/v1/paper/search")!
        components.queryItems = [
            URLQueryItem(name: "query", value: ([feed.name] + feed.keywords).joined(separator: " ")),
            URLQueryItem(name: "limit", value: String(max(feed.authorityPolicy.dailyLimit * 3, 10))),
            URLQueryItem(name: "fields", value: "title,abstract,authors,year,externalIds,openAccessPdf,url,publicationDate,citationCount,venue")
        ]
        var request = URLRequest(url: components.url!)
        if !apiKey.isEmpty {
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        }
        let response = try await httpClient.perform(request)
        try response.requireSuccess()
        let decoded = try JSONDecoder().decode(SemanticScholarResponse.self, from: response.data)
        return (decoded.data ?? []).compactMap { item in
            guard let paperID = item.paperId, let title = item.title else { return nil }
            let openAccessPDFURL = item.openAccessPdf?.url.flatMap(URL.init(string:))
            return PaperCandidate(
                source: .semanticScholar,
                sourceID: paperID,
                baseID: item.externalIds?.arxiv.flatMap(PaperCandidate.arxivBaseID),
                doi: item.externalIds?.doi,
                title: title,
                summary: item.abstract ?? "",
                authors: (item.authors ?? []).map(\.name),
                publishedAt: item.publicationDate.flatMap(PaperPulseDateParser.dateOnly),
                absURL: item.url.flatMap(URL.init(string:)),
                pdfURL: openAccessPDFURL,
                venue: item.venue,
                citationCount: item.citationCount,
                openAccessPDFURL: openAccessPDFURL,
                provenance: [
                    PaperProvenance(source: .semanticScholar, sourceID: paperID, sourceURL: item.url.flatMap(URL.init(string:)))
                ],
                openAccessEvidence: openAccessPDFURL.map {
                    OpenAccessEvidence(status: .verified, source: .semanticScholar, url: $0)
                }
            )
        }
    }

}

private struct SemanticScholarResponse: Decodable {
    var data: [SemanticScholarPaper]?
}

private struct SemanticScholarPaper: Decodable {
    var paperId: String?
    var title: String?
    var abstract: String?
    var authors: [SemanticScholarAuthor]?
    var externalIds: ExternalIDs?
    var openAccessPdf: OpenPDF?
    var url: String?
    var publicationDate: String?
    var citationCount: Int?
    var venue: String?

    struct ExternalIDs: Decodable {
        var doi: String?
        var arxiv: String?

        enum CodingKeys: String, CodingKey {
            case doi = "DOI"
            case arxiv = "ArXiv"
        }
    }

    struct OpenPDF: Decodable {
        var url: String?
    }
}

private struct SemanticScholarAuthor: Decodable {
    var name: String
}

public struct OpenAlexSource: PaperSource {
    private let httpClient: HTTPClient

    public init(httpClient: HTTPClient = URLSessionHTTPClient()) {
        self.httpClient = httpClient
    }

    public func search(feed: FeedConfig, window: DateInterval) async throws -> [PaperCandidate] {
        var components = URLComponents(string: "https://api.openalex.org/works")!
        components.queryItems = [
            URLQueryItem(name: "search", value: ([feed.name] + feed.keywords).joined(separator: " ")),
            URLQueryItem(name: "per-page", value: String(max(feed.authorityPolicy.dailyLimit * 3, 10))),
            URLQueryItem(name: "filter", value: Self.publicationDateFilter(window)),
            URLQueryItem(name: "sort", value: "publication_date:desc")
        ]
        let response = try await httpClient.perform(URLRequest(url: components.url!))
        try response.requireSuccess()
        let decoded = try JSONDecoder().decode(OpenAlexResponse.self, from: response.data)
        return (decoded.results ?? []).compactMap { work in
            guard let id = work.id, let title = work.title ?? work.displayName else { return nil }
            let openAccessPDFURL = work.openAccess?.oaURL.flatMap(URL.init(string:))
            return PaperCandidate(
                source: .openAlex,
                sourceID: id,
                doi: work.doi?.replacingOccurrences(of: "https://doi.org/", with: ""),
                title: title,
                summary: work.abstractInvertedIndex?.plainText ?? "",
                authors: (work.authorships ?? []).compactMap { $0.author?.displayName },
                institutions: (work.authorships ?? []).flatMap { ($0.institutions ?? []).compactMap(\.displayName) },
                publishedAt: work.publicationDate.flatMap(PaperPulseDateParser.dateOnly),
                absURL: id.hasPrefix("http") ? URL(string: id) : nil,
                pdfURL: openAccessPDFURL,
                venue: work.primaryLocation?.source?.displayName,
                citationCount: work.citedByCount,
                openAccessPDFURL: openAccessPDFURL,
                provenance: [
                    PaperProvenance(source: .openAlex, sourceID: id, sourceURL: id.hasPrefix("http") ? URL(string: id) : nil)
                ],
                openAccessEvidence: openAccessPDFURL.map {
                    OpenAccessEvidence(status: .verified, source: .openAlex, url: $0)
                }
            )
        }
    }

    private static func publicationDateFilter(_ window: DateInterval) -> String {
        "from_publication_date:\(PaperPulseDateParser.dateOnlyString(window.start)),to_publication_date:\(PaperPulseDateParser.dateOnlyString(window.end))"
    }
}

private struct OpenAlexResponse: Decodable {
    var results: [OpenAlexWork]?
}

private struct OpenAlexWork: Decodable {
    var id: String?
    var doi: String?
    var title: String?
    var displayName: String?
    var publicationDate: String?
    var citedByCount: Int?
    var authorships: [Authorship]?
    var openAccess: OpenAccess?
    var primaryLocation: Location?
    var abstractInvertedIndex: [String: [Int]]?

    enum CodingKeys: String, CodingKey {
        case id, doi, title, authorships
        case displayName = "display_name"
        case publicationDate = "publication_date"
        case citedByCount = "cited_by_count"
        case openAccess = "open_access"
        case primaryLocation = "primary_location"
        case abstractInvertedIndex = "abstract_inverted_index"
    }

    struct Authorship: Decodable {
        var author: Author?
        var institutions: [Institution]?
    }

    struct Author: Decodable {
        var displayName: String

        enum CodingKeys: String, CodingKey {
            case displayName = "display_name"
        }
    }

    struct Institution: Decodable {
        var displayName: String

        enum CodingKeys: String, CodingKey {
            case displayName = "display_name"
        }
    }

    struct OpenAccess: Decodable {
        var oaURL: String?

        enum CodingKeys: String, CodingKey {
            case oaURL = "oa_url"
        }
    }

    struct Location: Decodable {
        var source: Source?

        struct Source: Decodable {
            var displayName: String?

            enum CodingKeys: String, CodingKey {
                case displayName = "display_name"
            }
        }
    }
}

private extension Dictionary where Key == String, Value == [Int] {
    var plainText: String {
        let pairs = flatMap { word, positions in positions.map { ($0, word) } }
        return pairs.sorted { $0.0 < $1.0 }.map(\.1).joined(separator: " ")
    }
}

public struct CrossrefSource: PaperSource {
    private let httpClient: HTTPClient

    public init(httpClient: HTTPClient = URLSessionHTTPClient()) {
        self.httpClient = httpClient
    }

    public func search(feed: FeedConfig, window: DateInterval) async throws -> [PaperCandidate] {
        var components = URLComponents(string: "https://api.crossref.org/works")!
        components.queryItems = [
            URLQueryItem(name: "query", value: ([feed.name] + feed.keywords).joined(separator: " ")),
            URLQueryItem(name: "rows", value: String(max(feed.authorityPolicy.dailyLimit * 3, 10))),
            URLQueryItem(name: "filter", value: Self.publicationDateFilter(window)),
            URLQueryItem(name: "sort", value: "published"),
            URLQueryItem(name: "order", value: "desc")
        ]
        let response = try await httpClient.perform(URLRequest(url: components.url!))
        try response.requireSuccess()
        let decoded = try JSONDecoder().decode(CrossrefResponse.self, from: response.data)
        return decoded.message.items.enumerated().map { index, item in
            let pdfURL = item.link?.first(where: { $0.contentType == "application/pdf" })?.url.flatMap(URL.init(string:))
            let sourceID = item.doi ?? item.url ?? item.title?.first ?? "crossref-\(index)"
            return PaperCandidate(
                source: .crossref,
                sourceID: sourceID,
                doi: item.doi,
                title: item.title?.first ?? "Untitled",
                summary: item.abstract ?? "",
                authors: item.author?.map { [$0.given, $0.family].compactMap { $0 }.joined(separator: " ") } ?? [],
                publishedAt: item.issued?.date,
                absURL: item.url.flatMap(URL.init(string:)),
                pdfURL: pdfURL,
                venue: item.containerTitle?.first,
                provenance: [
                    PaperProvenance(source: .crossref, sourceID: sourceID, sourceURL: item.url.flatMap(URL.init(string:)))
                ]
            )
        }
    }

    private static func publicationDateFilter(_ window: DateInterval) -> String {
        "from-pub-date:\(PaperPulseDateParser.dateOnlyString(window.start)),until-pub-date:\(PaperPulseDateParser.dateOnlyString(window.end))"
    }
}

private struct CrossrefResponse: Decodable {
    var message: Message

    struct Message: Decodable {
        var items: [Item]
    }

    struct Item: Decodable {
        var doi: String?
        var title: [String]?
        var abstract: String?
        var author: [Author]?
        var issued: Issued?
        var url: String?
        var link: [Link]?
        var containerTitle: [String]?

        enum CodingKeys: String, CodingKey {
            case doi = "DOI"
            case title, abstract, author, issued
            case url = "URL"
            case link
            case containerTitle = "container-title"
        }
    }

    struct Author: Decodable {
        var given: String?
        var family: String?
    }

    struct Issued: Decodable {
        var dateParts: [[Int]]?

        enum CodingKeys: String, CodingKey {
            case dateParts = "date-parts"
        }

        var date: Date? {
            guard let first = dateParts?.first, let year = first.first else { return nil }
            var components = DateComponents()
            components.calendar = Calendar(identifier: .gregorian)
            components.timeZone = TimeZone(secondsFromGMT: 0)
            components.year = year
            components.month = first.count > 1 ? first[1] : 1
            components.day = first.count > 2 ? first[2] : 1
            return components.date
        }
    }

    struct Link: Decodable {
        var url: String?
        var contentType: String?

        enum CodingKeys: String, CodingKey {
            case url = "URL"
            case contentType = "content-type"
        }
    }
}

public struct UnpaywallClient {
    private let httpClient: HTTPClient
    private let email: String

    public init(email: String, httpClient: HTTPClient = URLSessionHTTPClient()) {
        self.email = email
        self.httpClient = httpClient
    }

    public func openAccessPDFURL(forDOI doi: String) async throws -> URL? {
        var components = URLComponents(string: "https://api.unpaywall.org/v2/\(doi)")!
        components.queryItems = [URLQueryItem(name: "email", value: email)]
        let response = try await httpClient.perform(URLRequest(url: components.url!))
        try response.requireSuccess()
        let decoded = try JSONDecoder().decode(UnpaywallResponse.self, from: response.data)
        return decoded.bestOALocation?.urlForPDF.flatMap(URL.init(string:))
    }
}

public struct UnpaywallPDFEnricher: PaperMetadataEnricher {
    private let client: UnpaywallClient

    public init(email: String, httpClient: HTTPClient = URLSessionHTTPClient()) {
        client = UnpaywallClient(email: email, httpClient: httpClient)
    }

    public func enrich(_ candidate: PaperCandidate) async throws -> PaperCandidate {
        guard candidate.openAccessPDFURL == nil else {
            return candidate
        }
        guard let doi = candidate.doi, !doi.isEmpty else {
            return candidate
        }
        guard let pdfURL = try await client.openAccessPDFURL(forDOI: doi) else {
            return candidate
        }

        var enriched = candidate
        enriched.openAccessPDFURL = pdfURL
        enriched.openAccessEvidence = OpenAccessEvidence(status: .verified, source: .unpaywall, url: pdfURL)
        enriched.provenance.append(
            PaperProvenance(source: .unpaywall, sourceID: doi, sourceURL: URL(string: "https://api.unpaywall.org/v2/\(doi)"))
        )
        return enriched
    }
}

private struct UnpaywallResponse: Decodable {
    var bestOALocation: Location?

    enum CodingKeys: String, CodingKey {
        case bestOALocation = "best_oa_location"
    }

    struct Location: Decodable {
        var urlForPDF: String?

        enum CodingKeys: String, CodingKey {
            case urlForPDF = "url_for_pdf"
        }
    }
}
