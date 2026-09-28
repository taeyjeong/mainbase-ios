import SwiftUI

/// Titled "$ [0.00] unit" input box for dollar amounts. Only accepts digits and one decimal
/// point with up to two digits after it. Bound to a String (parse with `Double(text)`) so a
/// value typed just before tapping a button isn't lost to an uncommitted number field.
struct AmountField: View {
    let title: String
    @Binding var text: String
    var unit: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppColors.text)
            HStack(spacing: 6) {
                Text("$")
                    .foregroundColor(AppColors.textSecondary)
                TextField("0.00", text: $text)
                    .keyboardType(.decimalPad)
                if let unit {
                    Text(unit)
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            .inputFieldStyle(background: AppColors.background)
        }
        .onChange(of: text) { _, newText in
            let sanitized = Self.sanitized(newText)
            if sanitized != newText { text = sanitized }
        }
    }

    static func sanitized(_ text: String) -> String {
        var result = ""
        var hasDecimalPoint = false
        var fractionDigits = 0
        for character in text {
            if character.isASCII, character.isNumber {
                if hasDecimalPoint {
                    guard fractionDigits < 2 else { continue }
                    fractionDigits += 1
                }
                result.append(character)
            } else if character == ".", !hasDecimalPoint {
                hasDecimalPoint = true
                result.append(character)
            }
        }
        return result
    }
}

/// Titled multi-line text box, styled to match `inputFieldStyle`.
struct NotesField: View {
    let title: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppColors.text)
            TextField(placeholder, text: $text, axis: .vertical)
                .lineLimit(3...8)
                .font(.system(size: 16))
                .foregroundColor(AppColors.text)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(AppColors.background)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.border, lineWidth: 1))
        }
    }
}
