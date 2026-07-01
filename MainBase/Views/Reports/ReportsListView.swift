import SwiftUI

struct ReportsListView: View {
    @StateObject private var vm = ReportsViewModel()

    var body: some View {
        VStack(spacing: 0) {
            header

            if vm.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if vm.filteredReports.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 36))
                        .foregroundColor(AppColors.textSecondary)
                    Text(vm.selectedUserId == nil ? "No reports yet" : "No reports for this person")
                        .font(.system(size: 15))
                        .foregroundColor(AppColors.textSecondary)
                }
                Spacer()
            } else {
                monthNavigator
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)

                if vm.reportsForSelectedMonth.isEmpty {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 36))
                            .foregroundColor(AppColors.textSecondary)
                        Text(emptyMonthMessage)
                            .font(.system(size: 15))
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 20)
                    Spacer()
                } else {
                    List {
                        ForEach(vm.reportsForSelectedMonth) { report in
                            ReportRow(report: report)
                                .listRowBackground(AppColors.cardBackground)
                        }
                    }
                    .listStyle(.plain)
                    .listRowSeparatorTint(AppColors.border)
                }
            }
        }
        .background(AppColors.background.ignoresSafeArea())
        .contentShape(Rectangle())
        .gesture(monthSwipeGesture)
        .onAppear { vm.startListening() }
        .onDisappear { vm.stopListening() }
        .onChange(of: vm.selectedUserId) { _, _ in
            vm.selectedMonth = MonthGrouping.startOfMonth(for: Date())
        }
    }

    private var emptyMonthMessage: String {
        if vm.selectedUserId == nil {
            return "No reports for \(vm.selectedMonthTitle)"
        }
        return "No reports for this person in \(vm.selectedMonthTitle)"
    }

    private var monthNavigator: some View {
        HStack(spacing: 12) {
            monthNavButton(systemName: "chevron.left", enabled: vm.canGoToPreviousMonth) {
                vm.goToPreviousMonth()
            }

            Spacer(minLength: 8)

            Text(vm.selectedMonthTitle)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppColors.text)

            Spacer(minLength: 8)

            monthNavButton(systemName: "chevron.right", enabled: vm.canGoToNextMonth) {
                vm.goToNextMonth()
            }
        }
    }

    private func monthNavButton(systemName: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(enabled ? AppColors.primary : AppColors.textSecondary.opacity(0.4))
                .frame(width: 36, height: 36)
        }
        .disabled(!enabled)
    }

    private var monthSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 30, coordinateSpace: .local)
            .onEnded { value in
                guard !vm.filteredReports.isEmpty else { return }
                let horizontal = value.translation.width
                guard abs(horizontal) > abs(value.translation.height) else { return }
                if horizontal > 60 {
                    vm.goToPreviousMonth()
                } else if horizontal < -60 {
                    vm.goToNextMonth()
                }
            }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reports")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppColors.text)

            if !vm.availablePeople.isEmpty {
                HStack {
                    Text("Filter")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)

                    Picker("Filter by person", selection: $vm.selectedUserId) {
                        Text("All people").tag(String?.none)
                        ForEach(vm.availablePeople, id: \.id) { person in
                            Text(person.name).tag(Optional(person.id))
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(AppColors.primary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 16)
        .background(AppColors.background)
    }
}

private struct ReportRow: View {
    let report: Report

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                Text(report.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.text)
                Spacer()
                Text(Self.formatter.string(from: report.timestamp))
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textSecondary)
            }
            Text(report.reportText)
                .font(.system(size: 14))
                .foregroundColor(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    ReportsListView()
}
