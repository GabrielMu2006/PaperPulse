import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

public final class ArxivAtomParser: NSObject, XMLParserDelegate {
    private var entries: [Entry] = []
    private var currentEntry: Entry?
    private var currentText = ""
    private var insideAuthor = false

    public override init() {}

    public func parse(_ data: Data) throws -> [PaperCandidate] {
        entries = []
        currentEntry = nil
        currentText = ""
        insideAuthor = false

        let parser = XMLParser(data: data)
        parser.delegate = self
        guard parser.parse() else {
            throw parser.parserError ?? ArxivParserError.invalidXML
        }
        return entries.map(\.candidate)
    }

    public func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        currentText = ""
        switch elementName {
        case "entry":
            currentEntry = Entry()
        case "author":
            insideAuthor = true
        case "category":
            currentEntry?.categories.append(attributeDict["term", default: ""])
        case "link":
            guard let href = attributeDict["href"], let url = URL(string: href) else { return }
            if attributeDict["title"] == "pdf" || attributeDict["type"] == "application/pdf" {
                currentEntry?.pdfURL = url
            } else if attributeDict["rel"] == "alternate" {
                currentEntry?.absURL = url
            }
        default:
            break
        }
    }

    public func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    public func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let text = currentText.cleanedWhitespace
        switch elementName {
        case "id":
            currentEntry?.id = text
        case "title":
            currentEntry?.title = text
        case "summary":
            currentEntry?.summary = text
        case "published":
            currentEntry?.published = PaperPulseDateParser.iso8601(text)
        case "updated":
            currentEntry?.updated = PaperPulseDateParser.iso8601(text)
        case "name" where insideAuthor:
            if !text.isEmpty {
                currentEntry?.authors.append(text)
            }
        case "author":
            insideAuthor = false
        case "entry":
            if let currentEntry {
                entries.append(currentEntry)
            }
            self.currentEntry = nil
        default:
            break
        }
        currentText = ""
    }
}

public enum ArxivParserError: Error, Equatable {
    case invalidXML
}

private struct Entry {
    var id = ""
    var title = ""
    var summary = ""
    var authors: [String] = []
    var categories: [String] = []
    var published: Date?
    var updated: Date?
    var absURL: URL?
    var pdfURL: URL?

    var candidate: PaperCandidate {
        let sourceID = id.split(separator: "/").last.map(String.init) ?? id
        return PaperCandidate(
            source: .arxiv,
            sourceID: sourceID,
            baseID: PaperCandidate.arxivBaseID(from: sourceID),
            title: title,
            summary: summary,
            authors: authors,
            categories: categories.filter { !$0.isEmpty },
            publishedAt: published,
            updatedAt: updated,
            absURL: absURL ?? URL(string: "https://arxiv.org/abs/\(sourceID)"),
            pdfURL: pdfURL ?? URL(string: "https://arxiv.org/pdf/\(sourceID).pdf"),
            openAccessPDFURL: pdfURL ?? URL(string: "https://arxiv.org/pdf/\(sourceID).pdf")
        )
    }
}

enum PaperPulseDateParser {
    static func iso8601(_ string: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: string) {
            return date
        }
        let regular = ISO8601DateFormatter()
        regular.formatOptions = [.withInternetDateTime]
        return regular.date(from: string)
    }

    static func dateOnly(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: string)
    }

    static func dateOnlyString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
