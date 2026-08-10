import SwiftUI

struct OperationsView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                Image(systemName: "shippingbox")
                    .font(.system(size: 36))
                    .foregroundColor(AppColors.textSecondary)
                Text("Nothing here yet")
                    .font(.system(size: 15))
                    .foregroundColor(AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Operations")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    OperationsView()
}
