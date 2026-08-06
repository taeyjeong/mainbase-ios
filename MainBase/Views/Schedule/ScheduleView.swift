import SwiftUI

/// Will eventually show every worker's clock in/out schedule. Placeholder for now.
struct ScheduleView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                Image(systemName: "calendar")
                    .font(.system(size: 36))
                    .foregroundColor(AppColors.textSecondary)
                Text("Schedule coming soon")
                    .font(.system(size: 15))
                    .foregroundColor(AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    ScheduleView()
}
