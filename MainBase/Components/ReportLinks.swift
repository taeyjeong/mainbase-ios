import SwiftUI

struct ExtractedLink: Identifiable {
    let id = UUID()
    let url: URL
    let platform: LinkPlatform
}

/// Pulls URLs out of freeform report text so they can be rendered separately as tappable icon chips.
enum ReportTextLinks {
    static func extract(from text: String) -> (cleanedText: String, links: [ExtractedLink]) {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return (text, [])
        }
        let matches = detector.matches(in: text, range: NSRange(text.startIndex..., in: text))
        guard !matches.isEmpty else { return (text, []) }

        var links: [ExtractedLink] = []
        var cleaned = text
        for match in matches.reversed() {
            guard let range = Range(match.range, in: text), let url = match.url else { continue }
            links.insert(ExtractedLink(url: url, platform: LinkPlatform.detect(from: url)), at: 0)
            cleaned.replaceSubrange(range, with: "")
        }
        cleaned = cleaned
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
        return (cleaned, links)
    }
}

struct ReportLinkChip: View {
    let link: ExtractedLink

    var body: some View {
        Link(destination: link.url) {
            Image(systemName: link.platform.iconName)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(link.platform.tintColor)
                .frame(width: 36, height: 36)
                .background(AppColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(AppColors.border, lineWidth: 1)
                )
        }
        .accessibilityLabel(link.platform.label)
    }
}

struct ReportLinksGrid: View {
    let links: [ExtractedLink]

    private let columns = [GridItem(.adaptive(minimum: 36), spacing: 8)]

    var body: some View {
        if !links.isEmpty {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                ForEach(links) { link in
                    ReportLinkChip(link: link)
                }
            }
        }
    }
}
