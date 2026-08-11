import SwiftUI

struct ReportsListView: View {
    @StateObject private var vm = ReportsViewModel()
    @State private var chattingReport: Report?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if vm.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else if vm.reports.isEmpty {
                emptyState(message: "No reports yet")
            } else {
                monthAndFilterRow
                    .padding(.bottom, 12)

                if vm.reportsForSelectedMonth.isEmpty {
                    emptyState(message: emptyMonthMessage)
                } else {
                    VStack(spacing: 14) {
                        ForEach(vm.reportsForSelectedMonth) { report in
                            ReportRow(report: report, onOpenChat: { chattingReport = report })
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .contentShape(Rectangle())
        .gesture(monthSwipeGesture)
        .onAppear { vm.startListening() }
        .onDisappear { vm.stopListening() }
        .onChange(of: vm.selectedUserId) { _, _ in
            vm.selectedMonth = MonthGrouping.startOfMonth(for: Date())
        }
        .sheet(item: $chattingReport) { report in
            ReportChatView(report: report, vm: vm)
        }
    }

    private func emptyState(message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text")
                .font(.system(size: 30))
                .foregroundColor(AppColors.textSecondary)
            Text(message)
                .font(.system(size: 14))
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private var emptyMonthMessage: String {
        if vm.selectedUserId == nil {
            return "No reports for \(vm.selectedMonthTitle)"
        }
        return "No reports for this person in \(vm.selectedMonthTitle)"
    }

    private static let shortMonthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter
    }()

    private var shortMonthTitle: String {
        Self.shortMonthFormatter.string(from: vm.selectedMonth)
    }

    private var monthAndFilterRow: some View {
        HStack(spacing: 4) {
            monthNavButton(systemName: "chevron.left", enabled: vm.canGoToPreviousMonth) {
                vm.goToPreviousMonth()
            }

            Text(shortMonthTitle)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppColors.text)
                .frame(minWidth: 88)
                .multilineTextAlignment(.center)

            monthNavButton(systemName: "chevron.right", enabled: vm.canGoToNextMonth) {
                vm.goToNextMonth()
            }

            Spacer(minLength: 8)

            if !vm.availablePeople.isEmpty {
                filterMenu
            }
        }
    }

    private var filterMenu: some View {
        Menu {
            Picker("Filter by person", selection: $vm.selectedUserId) {
                Text("All people").tag(String?.none)
                ForEach(vm.availablePeople, id: \.id) { person in
                    Text(person.name).tag(Optional(person.id))
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: 14, weight: .semibold))
                Text(selectedFilterLabel)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(AppColors.primary)
        }
    }

    private var selectedFilterLabel: String {
        guard let selectedUserId = vm.selectedUserId else { return "All Reports" }
        return vm.availablePeople.first { $0.id == selectedUserId }?.name ?? "All Reports"
    }

    private func monthNavButton(systemName: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(enabled ? AppColors.primary : AppColors.textSecondary.opacity(0.4))
                .frame(width: 32, height: 32)
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

}

private struct ReportRow: View {
    let report: Report
    let onOpenChat: () -> Void

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()

    private var formattedTimestamp: String {
        "\(Self.dateFormatter.string(from: report.timestamp)) · \(Self.timeFormatter.string(from: report.timestamp))"
    }

    private var displayEmoji: String {
        report.emoji.trimmingCharacters(in: .whitespaces).isEmpty ? "👻" : report.emoji
    }

    var body: some View {
        let parsed = ReportTextLinks.extract(from: report.reportText)

        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                Text(displayEmoji)
                    .font(.system(size: 16))
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.gray.opacity(0.15)))

                Text(report.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppColors.text)
                Spacer()
                Text(formattedTimestamp)
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textSecondary)
            }
            if !parsed.cleanedText.isEmpty {
                Text(parsed.cleanedText)
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(alignment: .bottom) {
                ReportLinksGrid(links: parsed.links)
                Spacer(minLength: 8)
                replyButton
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.cardBackground)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColors.border, lineWidth: 1))
        )
    }

    private var replyButton: some View {
        Button(action: onOpenChat) {
            HStack(spacing: 5) {
                Image(systemName: "bubble.left.fill")
                    .font(.system(size: 11))
                Text(report.messageCount > 0 ? "Reply · \(report.messageCount)" : "Reply")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(AppColors.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(AppColors.primary.opacity(0.1)))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ReportsListView()
}
