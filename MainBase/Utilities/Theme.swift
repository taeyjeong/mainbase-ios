//  Theme.swift — matches lacoachoffice's Colors.ts palette

import SwiftUI
import UIKit

enum AppearancePreference: String {
    case system
    case light
    case dark

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

struct AppColors {
    static let primary = Color(hex: "#007AFF")
    static let primaryLight = Color(hex: "#5AC8FA")
    static let text = Color(light: "#000000", dark: "#FFFFFF")
    static let textSecondary = Color(light: "#666666", dark: "#9B9B9B")
    static let border = Color(light: "#E5E5E5", dark: "#3A3A3C")
    static let cardBackground = Color(light: "#FFFFFF", dark: "#1C1C1E")
    static let background = Color(light: "#F5F5F5", dark: "#0A0A0A")
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: .init(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255
        let g = Double((rgb >> 8) & 0xFF) / 255
        let b = Double(rgb & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }

    /// A color that automatically switches between a light-mode and dark-mode hex value.
    init(light: String, dark: String) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(Color(hex: dark)) : UIColor(Color(hex: light))
        })
    }

    /// Blends this color toward white by `amount` (0 = unchanged, 1 = white).
    /// Used for the project detail background in light mode, as a light tint of the project's Main color.
    func lightened(by amount: CGFloat = 0.85) -> Color {
        let uiColor = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return Color(
            red: Double(r + (1 - r) * amount),
            green: Double(g + (1 - g) * amount),
            blue: Double(b + (1 - b) * amount)
        )
    }

    /// Blends this color toward black by `amount` (0 = unchanged, 1 = black).
    /// Used for the project detail background in dark mode — lightening toward white there
    /// would wash out to a jarring near-white patch against the rest of the dark UI.
    func darkened(by amount: CGFloat = 0.75) -> Color {
        let uiColor = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return Color(
            red: Double(r * (1 - amount)),
            green: Double(g * (1 - amount)),
            blue: Double(b * (1 - amount))
        )
    }

    /// Round-trips a `ColorPicker` selection back into the `"#RRGGBB"` strings this app stores.
    func toHex() -> String {
        let uiColor = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}
