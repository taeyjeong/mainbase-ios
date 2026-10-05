import Foundation

struct Report: Identifiable {
    let id: String
    let userId: String
    let name: String
    let emoji: String
    let reportText: String
    let timestamp: Date
    let messageCount: Int
    /// The one project Main (projectMains/{id}) the report is about, if any.
    var projectMainId: String? = nil
    /// Links added on the clock-out sheet.
    var links: [ReportLink] = []

    /// The text with any pasted URLs taken out, and every link to show under it: the clock-out
    /// sheet's links first, then pasted ones (older reports) not already among them.
    var textAndLinks: (text: String, links: [ReportLink]) {
        let parsed = ReportTextLinks.extract(from: reportText)
        let pasted = parsed.links
            .filter { extracted in !links.contains { $0.url == extracted.url } }
            .enumerated()
            .map { ReportLink(id: "pasted-\($0.offset)", url: $0.element.url, description: "") }
        return (parsed.cleanedText, links + pasted)
    }
}
