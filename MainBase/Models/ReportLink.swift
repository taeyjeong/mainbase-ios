import Foundation

/// A link on a published report: one added on the clock-out sheet (the report's `links` array)
/// or, for older reports, a URL pasted into the text.
struct ReportLink: Identifiable {
    let id: String
    let url: URL
    /// What the person wrote about the link; empty for pasted links.
    let description: String

    var platform: LinkPlatform { LinkPlatform.detect(from: url) }

    var displayText: String {
        if !description.isEmpty { return description }
        let host = url.host ?? url.absoluteString
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    /// This link's entry in the report's `links` field.
    var firestoreValue: [String: String] {
        ["url": url.absoluteString, "description": description]
    }

    /// Parses the report's `links` field.
    static func list(from value: Any?) -> [ReportLink] {
        (value as? [[String: Any]] ?? []).enumerated().compactMap { index, link in
            guard let url = (link["url"] as? String).flatMap(URL.init(string:)) else { return nil }
            return ReportLink(id: "link-\(index)", url: url, description: link["description"] as? String ?? "")
        }
    }
}

/// One link row being filled in on the clock-out sheet or in EditReportSheet.
struct ReportLinkDraft: Identifiable, Equatable {
    static let descriptionLimit = 50

    let id = UUID()
    var url = ""
    var description = ""

    init() {}

    /// A row prefilled with a saved link, for editing it in EditReportSheet.
    init(link: ReportLink) {
        url = link.url.absoluteString
        description = link.description
    }

    var isBlank: Bool {
        url.trimmingCharacters(in: .whitespaces).isEmpty
            && description.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// The typed link as a web URL, adding "https://" when no scheme was typed. Nil unless it
    /// has a host with a dot, e.g. "docs.google.com".
    var normalizedURL: URL? {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let withScheme = trimmed.range(of: "^https?://", options: [.regularExpression, .caseInsensitive]) == nil
            ? "https://\(trimmed)"
            : trimmed
        guard let url = URL(string: withScheme), let host = url.host, host.contains(".") else { return nil }
        return url
    }

    /// A row with a description but no link, or a link that isn't a web address.
    var isInvalid: Bool { !isBlank && normalizedURL == nil }

    /// The report's `links` entry, or nil for a blank or invalid row.
    var firestoreValue: [String: String]? {
        guard let normalizedURL else { return nil }
        return [
            "url": normalizedURL.absoluteString,
            "description": String(description.trimmingCharacters(in: .whitespaces).prefix(Self.descriptionLimit)),
        ]
    }
}
