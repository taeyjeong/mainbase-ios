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

/// A report's links, one per line: the platform icon on the left (Doc, Sheet, Slides, PDF, or a
/// globe for websites) and the description on the right.
struct ReportLinkList: View {
    let links: [ReportLink]

    var body: some View {
        if !links.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(links) { link in
                    ReportLinkRow(link: link)
                }
            }
        }
    }
}

private struct ReportLinkRow: View {
    let link: ReportLink

    var body: some View {
        Link(destination: link.url) {
            HStack(spacing: 10) {
                Image(systemName: link.platform.iconName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(link.platform.tintColor)
                    .frame(width: 30, height: 30)
                    .background(AppColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(AppColors.border, lineWidth: 1)
                    )
                Text(link.displayText)
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.primary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .accessibilityLabel("\(link.platform.label): \(link.displayText)")
    }
}
