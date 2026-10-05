import SwiftUI

struct ReportsListView: View {
    /// Called with the selected month when the user asks for a summary of their own reports;
    /// the parent shows MonthlySummaryPopup, since a pop-up here would be clipped to this list.
    var onSummarizeMonth: (Date) -> Void = { _ in }

    @StateObject private var vm = ReportsViewModel()
    @State private var chattingReport: Report?
    @State private var editingReport: Report?

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
                    if vm.isFilteredToCurrentUser {
                        summarizeButton
                            .padding(.bottom, 4)
                    }
                    VStack(spacing: 14) {
                        ForEach(vm.reportsForSelectedMonth) { report in
                            ReportRow(
                                report: report,
                                projectMain: vm.projectMain(withId: report.projectMainId),
                                onOpenChat: { chattingReport = report },
                                onEdit: vm.canEdit(report) ? { editingReport = report } : nil
                            )
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
        .sheet(item: $editingReport) { report in
            EditReportSheet(report: report, vm: vm)
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

    private var summarizeButton: some View {
        Button { onSummarizeMonth(vm.selectedMonth) } label: {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                Text("Summarize this month")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(RoundedRectangle(cornerRadius: 12).fill(AppColors.primary))
        }
        .buttonStyle(.plain)
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
    let projectMain: ProjectMain?
    let onOpenChat: () -> Void
    /// Only set for the signed-in user's own reports.
    let onEdit: (() -> Void)?

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
        let parsed = report.textAndLinks

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
            if let projectMain {
                projectMainTag(projectMain)
            }
            if !parsed.text.isEmpty {
                Text(parsed.text)
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ReportLinkList(links: parsed.links)
            HStack(alignment: .bottom) {
                Spacer(minLength: 8)
                if let onEdit {
                    editButton(action: onEdit)
                }
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

    private func projectMainTag(_ main: ProjectMain) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color(hex: main.colorHex))
                .frame(width: 8, height: 8)
            Text(main.name)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppColors.text)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color(hex: main.colorHex).opacity(0.12)))
    }

    private func editButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: "pencil")
                    .font(.system(size: 11, weight: .semibold))
                Text("Edit")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(AppColors.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(AppColors.primary.opacity(0.1)))
        }
        .buttonStyle(.plain)
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
