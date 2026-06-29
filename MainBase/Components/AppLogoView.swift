import SwiftUI

struct AppLogoView: View {
    var body: some View {
        HStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(AppColors.primary)
                    .frame(width: 24, height: 24)
                RoundedRectangle(cornerRadius: 2)
                    .fill(AppColors.cardBackground)
                    .frame(width: 12, height: 12)
            }
            Text("MainBase")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppColors.primary)
        }
    }
}

#Preview {
    AppLogoView()
}
