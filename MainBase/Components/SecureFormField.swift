import SwiftUI

struct SecureFormField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    @Binding var isVisible: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(AppColors.text)
            HStack {
                Group {
                    if isVisible {
                        TextField(placeholder, text: $text)
                    } else {
                        SecureField(placeholder, text: $text)
                    }
                }
                .autocapitalization(.none)
                .autocorrectionDisabled()
                .frame(height: 50)

                Button(action: { isVisible.toggle() }) {
                    Image(systemName: isVisible ? "eye" : "eye.slash")
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(.trailing, 16)
            }
            .padding(.leading, 16)
            .background(AppColors.cardBackground)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.border, lineWidth: 1))
        }
    }
}

#Preview {
    SecureFormField(
        label: "Password",
        placeholder: "Enter password",
        text: .constant(""),
        isVisible: .constant(false)
    )
    .padding()
}
