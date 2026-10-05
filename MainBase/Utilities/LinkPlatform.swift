import SwiftUI

enum LinkPlatform {
    case instagram
    case tiktok
    case pinterest
    case facebook
    case reddit
    case linkedin
    case googleDoc
    case googleSheet
    case googleSlide
    case pdf
    case website

    var iconName: String {
        switch self {
        case .instagram: return "camera"
        case .tiktok: return "music.note"
        case .pinterest: return "pin"
        case .facebook: return "person.2"
        case .reddit: return "bubble.left.and.bubble.right"
        case .linkedin: return "briefcase"
        case .googleDoc: return "doc.text"
        case .googleSheet: return "tablecells"
        case .googleSlide: return "play.rectangle"
        case .pdf: return "doc.richtext"
        case .website: return "globe"
        }
    }

    var tintColor: Color {
        switch self {
        case .instagram: return Color(hex: "#E1306C")
        case .tiktok: return Color(light: "#000000", dark: "#E5E5E5")
        case .pinterest: return Color(hex: "#E60023")
        case .facebook: return Color(hex: "#1877F2")
        case .reddit: return Color(hex: "#FF4500")
        case .linkedin: return Color(hex: "#0A66C2")
        case .googleDoc: return Color(hex: "#4285F4")
        case .googleSheet: return Color(hex: "#0F9D58")
        case .googleSlide: return Color(hex: "#F4B400")
        case .pdf: return Color(hex: "#EA4335")
        case .website: return AppColors.textSecondary
        }
    }

    var label: String {
        switch self {
        case .instagram: return "Instagram"
        case .tiktok: return "TikTok"
        case .pinterest: return "Pinterest"
        case .facebook: return "Facebook"
        case .reddit: return "Reddit"
        case .linkedin: return "LinkedIn"
        case .googleDoc: return "Google Doc"
        case .googleSheet: return "Google Sheet"
        case .googleSlide: return "Google Slide"
        case .pdf: return "PDF"
        case .website: return "Link"
        }
    }

    static func detect(from url: URL) -> LinkPlatform {
        let host = (url.host ?? "").lowercased()
        let path = url.path.lowercased()

        if url.pathExtension.lowercased() == "pdf" { return .pdf }
        if host.contains("instagram.com") { return .instagram }
        if host.contains("tiktok.com") { return .tiktok }
        if host.contains("pinterest.com") || host.contains("pin.it") { return .pinterest }
        if hostMatches(host, ["facebook.com", "fb.com", "fb.me", "fb.watch"]) { return .facebook }
        if hostMatches(host, ["reddit.com", "redd.it"]) { return .reddit }
        if hostMatches(host, ["linkedin.com", "lnkd.in"]) { return .linkedin }

        if host.contains("docs.google.com") {
            if path.contains("/spreadsheets") { return .googleSheet }
            if path.contains("/presentation") { return .googleSlide }
            return .googleDoc
        }
        if host.contains("sheets.google.com") { return .googleSheet }
        if host.contains("slides.google.com") { return .googleSlide }

        return .website
    }

    /// The host is one of `domains` or a subdomain of one (m.facebook.com, old.reddit.com),
    /// so short domains like fb.me don't match unrelated hosts that merely contain them.
    private static func hostMatches(_ host: String, _ domains: [String]) -> Bool {
        domains.contains { host == $0 || host.hasSuffix("." + $0) }
    }
}
