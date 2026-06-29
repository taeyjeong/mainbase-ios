import SwiftUI

struct CheckboxToggle<Label: View>: View {
    @Binding var isOn: Bool
    @ViewBuilder let label: () -> Label

    var body: some View {
        Button(action: { isOn.toggle() }) {
            HStack(alignment: .top, spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(isOn ? AppColors.primary : AppColors.text, lineWidth: 2)
                        .frame(width: 20, height: 20)
                    if isOn {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(AppColors.primary)
                            .frame(width: 20, height: 20)
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .padding(.top, 2)
                label()
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    CheckboxToggle(isOn: .constant(true)) {
        Text("Remember Me")
            .font(.system(size: 16))
            .foregroundColor(AppColors.text)
    }
    .padding()
}
