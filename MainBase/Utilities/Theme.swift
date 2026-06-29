//  Theme.swift — matches lacoachoffice's Colors.ts palette

import SwiftUI

struct AppColors {
    static let primary = Color(hex: "#007AFF")
    static let primaryLight = Color(hex: "#5AC8FA")
    static let text = Color(hex: "#000000")
    static let textSecondary = Color(hex: "#666666")
    static let border = Color(hex: "#E5E5E5")
    static let cardBackground = Color(hex: "#FFFFFF")
    static let background = Color(hex: "#F5F5F5")
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
}
