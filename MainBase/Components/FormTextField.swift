import SwiftUI

struct FormTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: UITextAutocapitalizationType = .words

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(AppColors.text)
            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .autocapitalization(autocapitalization)
                .autocorrectionDisabled()
                .inputFieldStyle()
        }
    }
}

#Preview {
    FormTextField(label: "Email", placeholder: "john@example.com", text: .constant(""))
        .padding()
}
