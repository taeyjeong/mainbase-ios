import SwiftUI

/// One task the current user marked complete today, shown as a checklist under the report box
/// on the clock-out sheet.
struct CompletedTaskItem: Identifiable {
    let id: String
    let projectTitle: String
    let taskTitle: String
}

struct ClockOutSheetView: View {
    @Binding var report: String
    var completedTasks: [CompletedTaskItem] = []
    let onCancel: () -> Void
    let onSubmit: () -> Void

    private var trimmedReport: String {
        report.trimmingCharacters(in: .whitespaces)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RoundedRectangle(cornerRadius: 2.5)
                .fill(AppColors.border)
                .frame(width: 36, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
                .padding(.bottom, 20)

            Text("End shift report")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(AppColors.text)
                .padding(.horizontal, 20)

            Text("Summarize what you completed before you clock out.")
                .font(.system(size: 14))
                .foregroundColor(AppColors.textSecondary)
                .padding(.horizontal, 20)
                .padding(.top, 6)
                .padding(.bottom, 16)

            TextField("What did you work on?", text: $report, axis: .vertical)
                .font(.system(size: 16))
                .foregroundColor(AppColors.text)
                .lineLimit(5...8)
                .padding(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.border, lineWidth: 1))
                .padding(.horizontal, 20)
                .padding(.bottom, 20)

            if !completedTasks.isEmpty {
                completedTasksList
                    .padding(.bottom, 20)
            }

            HStack(spacing: 12) {
                Button("Cancel", action: onCancel)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.vertical, 13)
                    .padding(.horizontal, 16)

                Button(action: onSubmit) {
                    Text("Submit & clock out")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AppColors.cardBackground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(trimmedReport.isEmpty
                                      ? AppColors.primary.opacity(0.5)
                                      : AppColors.primary)
                        )
                }
                .disabled(trimmedReport.isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .background(AppColors.cardBackground)
        .presentationDetents([.medium, .large])
    }

    private var completedTasksList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Completed today")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)
                .padding(.horizontal, 20)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(completedTasks) { task in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(task.projectTitle) - \(task.taskTitle)")
                                .font(.system(size: 14))
                                .foregroundColor(AppColors.text)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 8)
                            Text("COMPLETED")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.green)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Color.green.opacity(0.12)))
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            .frame(maxHeight: 160)
        }
    }
}

#Preview {
    ClockOutSheetView(report: .constant(""), onCancel: {}, onSubmit: {})
}
