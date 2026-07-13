import SwiftUI

/// Renders description text as a tappable link (opens in the default browser)
/// when it starts with "https://" or "www.", otherwise as plain text.
struct DescriptionText: View {
    let text: String
    var font: Font = .system(size: 14)
    var color: Color = AppColors.textSecondary
    var lineLimit: Int? = nil

    private var url: URL? {
        if text.hasPrefix("https://") {
            return URL(string: text)
        } else if text.hasPrefix("www.") {
            return URL(string: "https://" + text)
        }
        return nil
    }

    var body: some View {
        if let url {
            Link(text, destination: url)
                .font(font)
                .lineLimit(lineLimit)
        } else {
            Text(text)
                .font(font)
                .foregroundColor(color)
                .lineLimit(lineLimit)
        }
    }
}
