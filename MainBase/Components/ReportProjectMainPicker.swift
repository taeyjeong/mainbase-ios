import SwiftUI

/// Picks the one project Main a report is about, on the clock-out sheet and in EditReportSheet.
/// Only one can be selected; tapping the selected Main clears it, since a Main is optional.
struct ReportProjectMainPicker: View {
    let projectMains: [ProjectMain]
    @Binding var selectedMainId: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Project Main")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)

            if projectMains.isEmpty {
                Text("No project Mains yet")
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.textSecondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(projectMains) { main in
                            MainSwatchButton(
                                main: main,
                                isSelected: selectedMainId == main.id,
                                action: { selectedMainId = selectedMainId == main.id ? nil : main.id }
                            )
                        }
                    }
                    .padding(4)
                }
            }
        }
    }
}
