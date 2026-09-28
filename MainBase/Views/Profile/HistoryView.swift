import SwiftUI

/// The signed-in user's own clock-out history, pushed from ProfileSheetView's "History" button.
struct HistoryView: View {
    @StateObject private var historyVM = HistoryViewModel()

    var body: some View {
        ScrollView(showsIndicators: false) {
            HistoryEntriesList(historyVM: historyVM)
                .historyCard()
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 40)
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { historyVM.startListening() }
        .onDisappear { historyVM.stopListening() }
    }
}

/// Admin-only: any employee's clock-out history, pushed from AdminToolsView's
/// "Employee History" button. Shares AdminToolsView's employee listener for the picker.
struct EmployeeHistoryView: View {
    @ObservedObject var adminVM: AdminEmployeesViewModel
    @StateObject private var historyVM = HistoryViewModel()
    @State private var selectedUserId: String?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Employee")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.text)
                    Spacer()
                    Picker("View history for", selection: $selectedUserId) {
                        Text("Select").tag(String?.none)
                        ForEach(adminVM.employees) { employee in
                            Text(employee.name).tag(Optional(employee.id))
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(AppColors.primary)
                }
                .padding(.bottom, 16)

                if selectedUserId == nil {
                    Text("Choose an employee to see their clock-out history.")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    HistoryEntriesList(historyVM: historyVM)
                }
            }
            .historyCard()
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 40)
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Employee History")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { historyVM.stopListening() }
        .onChange(of: selectedUserId) { _, userId in
            // HistoryViewModel falls back to the current user for nil, so stop instead.
            if let userId {
                historyVM.startListening(userId: userId)
            } else {
                historyVM.stopListening()
            }
        }
    }
}

private extension View {
    func historyCard() -> some View {
        padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppColors.cardBackground)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColors.border, lineWidth: 1))
            )
    }
}

/// Month-grouped clock-out history, shared by HistoryView (your own history) and
/// EmployeeHistoryView (a selected employee's history).
struct HistoryEntriesList: View {
    @ObservedObject var historyVM: HistoryViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if historyVM.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else if historyVM.sections.isEmpty {
                Text("No clock-out history yet.")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(Array(historyVM.sections.enumerated()), id: \.offset) { index, section in
                    if index > 0 {
                        Divider()
                            .padding(.vertical, 12)
                    }

                    Text(section.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.bottom, 8)

                    ForEach(section.items) { entry in
                        HistoryRow(entry: entry)
                        if entry.id != section.items.last?.id {
                            Divider()
                                .padding(.vertical, 8)
                        }
                    }
                }
            }
        }
    }
}

private struct HistoryRow: View {
    let entry: HistoryEntry

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(Self.dateFormatter.string(from: entry.clockOut))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppColors.text)
                Spacer()
                Text(entry.durationFormatted)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppColors.primary)
            }

            if !entry.report.isEmpty {
                Text(entry.report)
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
