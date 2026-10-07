import FirebaseAuth
import SwiftUI

/// The signed-in user's own work schedule, opened from the calendar icon in TimeTrackerView's
/// header. The weekly schedule is set in its own time zone (EmploymentTerms.timeZone); this
/// lists the shifts of the schedule's next 7 days converted to the device's time zone, so away
/// from that zone a shift can land on a different local day than its scheduled weekday. Above the shifts: the employee's
/// current wage (WageHistory), last month's paycheck (paid amount, or an estimate until an
/// admin marks it paid) and a button to request a day off or a shortened day.
struct ScheduleView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var termsVM = EmployeeTermsViewModel(userId: Auth.auth().currentUser?.uid ?? "")
    @StateObject private var wageVM = WageHistoryViewModel(userId: Auth.auth().currentUser?.uid ?? "")
    @StateObject private var payoutsVM = EmployeePayoutsViewModel(userId: Auth.auth().currentUser?.uid ?? "")
    @StateObject private var requestsVM = TimeOffRequestsViewModel(userId: Auth.auth().currentUser?.uid ?? "")
    @State private var showingEditor = false
    @State private var showingTimeOffRequest = false

    private static let daysShown = 7
    /// How far ahead a day off or shortened day can be requested.
    private static let requestableDays = 60

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEEEMMMd")
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()

    private static var localZoneAbbreviation: String {
        TimeZone.current.abbreviation() ?? TimeZone.current.identifier
    }

    /// Scheduled shifts from today through the next 6 days in the schedule's zone, including one
    /// in progress.
    private var upcomingShifts: [DateInterval] {
        termsVM.terms.upcomingShifts(days: Self.daysShown)
    }

    /// Last Pacific month's pay: frozen if an admin marked it paid, otherwise estimated.
    private var lastMonthPayout: PayoutRecord? {
        guard let lastMonth = PayoutRecord.calendar.date(byAdding: .month, value: -1, to: Date()) else { return nil }
        return payoutsVM.record(forMonth: PayoutRecord.monthKey(for: lastMonth), using: wageVM.history)
    }

    var body: some View {
        NavigationStack {
            Group {
                if termsVM.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 12) {
                            payCards
                            requestTimeOffButton
                            if !requestsVM.upcoming.isEmpty {
                                requestsCard
                            }
                            if !termsVM.hasSavedTerms {
                                emptyState("No schedule set yet")
                            } else if upcomingShifts.isEmpty {
                                emptyState("No shifts in the next \(Self.daysShown) days")
                            } else {
                                weeklyTotalCard
                                shiftsCard
                                Text("Times are in your time zone (\(Self.localZoneAbbreviation)).")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                        .padding(.bottom, 40)
                    }
                }
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("My Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Edit") { showingEditor = true }
                        .disabled(termsVM.isLoading)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingEditor) {
                EditMyScheduleSheet(termsVM: termsVM)
            }
            .sheet(isPresented: $showingTimeOffRequest) {
                TimeOffRequestSheet(
                    requestsVM: requestsVM,
                    upcomingShifts: termsVM.terms.upcomingShifts(days: Self.requestableDays)
                )
            }
            .task {
                async let terms: Void = termsVM.load()
                async let wages: Void = wageVM.load()
                async let payouts: Void = payoutsVM.load()
                async let requests: Void = requestsVM.load()
                _ = await (terms, wages, payouts, requests)
            }
            .alert("Schedule", isPresented: Binding(
                get: { alertMessage != nil },
                set: {
                    if !$0 {
                        termsVM.alertMessage = nil
                        wageVM.alertMessage = nil
                        payoutsVM.alertMessage = nil
                        requestsVM.alertMessage = nil
                    }
                }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage ?? "")
            }
        }
    }

    /// The first error from any of the screen's view models.
    private var alertMessage: String? {
        termsVM.alertMessage ?? wageVM.alertMessage ?? payoutsVM.alertMessage ?? requestsVM.alertMessage
    }

    private var payCards: some View {
        let wage = wageVM.history.current()
        let payout = lastMonthPayout
        return HStack(spacing: 12) {
            payCard(
                title: wage?.payType.rateLabel ?? "Wage",
                value: wage.map { $0.rate.formatted($0.currency.format) },
                detail: wage?.payType.rateUnit ?? "",
                isLoading: wageVM.isLoading
            )
            payCard(
                title: "Last month's paycheck",
                value: payout.flatMap { record in record.amount?.formatted(record.currency.format) },
                detail: payout.map { "\($0.monthTitle) · \($0.isPaid ? "Paid" : "Estimated")" } ?? "",
                isLoading: wageVM.isLoading || payoutsVM.isLoading
            )
        }
    }

    private func payCard(title: String, value: String?, detail: String, isLoading: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppColors.textSecondary)
            if isLoading {
                ProgressView()
            } else {
                Text(value ?? "Not set")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(value == nil ? AppColors.textSecondary : AppColors.text)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                if value != nil {
                    Text(detail)
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.cardBackground)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColors.border, lineWidth: 1))
        )
    }

    private var requestTimeOffButton: some View {
        Button {
            showingTimeOffRequest = true
        } label: {
            Label("Request Day Off or Shortened Day", systemImage: "calendar.badge.minus")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 12).fill(AppColors.primary))
        }
        .disabled(!termsVM.hasSavedTerms)
        .opacity(termsVM.hasSavedTerms ? 1 : 0.5)
    }

    private var requestsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("My requests")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppColors.text)
                .padding(.bottom, 10)
            ForEach(Array(requestsVM.upcoming.enumerated()), id: \.element.id) { index, request in
                if index > 0 {
                    Divider()
                        .padding(.vertical, 10)
                }
                requestRow(request)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.cardBackground)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColors.border, lineWidth: 1))
        )
    }

    private func requestRow(_ request: TimeOffRequest) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(request.kind.displayName) · \(Self.dayFormatter.string(from: request.shiftStart))")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.text)
                if let start = request.requestedStart, let end = request.requestedEnd {
                    Text("Work \(Self.timeFormatter.string(from: start)) – \(Self.timeFormatter.string(from: end))")
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            Spacer()
            Text(request.status.displayName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(statusColor(request.status))
        }
        .contextMenu {
            if request.status == .pending {
                Button("Withdraw Request", role: .destructive) {
                    Task { await requestsVM.withdraw(request) }
                }
            }
        }
    }

    private func statusColor(_ status: TimeOffRequest.Status) -> Color {
        switch status {
        case .pending: return .orange
        case .approved: return .green
        case .denied: return .red
        }
    }

    private var weeklyTotalCard: some View {
        HStack {
            Text("Total this week")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppColors.text)
            Spacer()
            Text(DurationFormatting.hoursMinutes(EmploymentTerms.weeklyHours(termsVM.terms.schedule)))
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppColors.primary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.cardBackground)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColors.border, lineWidth: 1))
        )
    }

    private var shiftsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(upcomingShifts.enumerated()), id: \.offset) { index, shift in
                if index > 0 {
                    Divider()
                        .padding(.vertical, 10)
                }
                shiftRow(shift)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.cardBackground)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColors.border, lineWidth: 1))
        )
    }

    private func shiftRow(_ shift: DateInterval) -> some View {
        let isNow = shift.contains(Date())
        let endsNextDay = !Calendar.current.isDate(shift.start, inSameDayAs: shift.end)
        return HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Self.dayFormatter.string(from: shift.start))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.text)
                Text("\(Self.timeFormatter.string(from: shift.start)) – \(Self.timeFormatter.string(from: shift.end))\(endsNextDay ? " (next day)" : "")")
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.textSecondary)
            }
            Spacer()
            if let request = requestsVM.activeRequest(for: shift) {
                Text(request.kind == .dayOff ? "Off requested" : "Shortened")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(statusColor(request.status))
            } else if isNow {
                Text("Now")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.primary)
            }
        }
    }

    private func emptyState(_ message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar")
                .font(.system(size: 36))
                .foregroundColor(AppColors.textSecondary)
            Text(message)
                .font(.system(size: 15))
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

#Preview {
    ScheduleView()
}
