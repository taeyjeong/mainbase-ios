import SwiftUI

/// Admin-only screen, pushed from an employee row in AdminToolsView. Logs the employee's wage
/// (hourly rate or monthly salary; see WageHistory for when a change starts), reviews and marks
/// monthly payouts, and sets pay notes and the weekly schedule (WeeklyScheduleEditor).
struct EmployeeDetailView: View {
    let employee: EmployeeEntry
    @StateObject private var termsVM: EmployeeTermsViewModel
    @StateObject private var wageVM: WageHistoryViewModel
    @StateObject private var payoutsVM: EmployeePayoutsViewModel

    @State private var newWageType: PayType = .hourly
    @State private var newWageText = ""
    @State private var newWageCurrency: PayCurrency = .usd
    @State private var showLogWageConfirm = false
    @State private var payoutToMarkPaid: PayoutRecord?
    @ObservedObject private var rates = ExchangeRates.shared

    init(employee: EmployeeEntry) {
        self.employee = employee
        _termsVM = StateObject(wrappedValue: EmployeeTermsViewModel(userId: employee.id))
        _wageVM = StateObject(wrappedValue: WageHistoryViewModel(userId: employee.id))
        _payoutsVM = StateObject(wrappedValue: EmployeePayoutsViewModel(userId: employee.id))
    }

    var body: some View {
        Group {
            if termsVM.isLoading || wageVM.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        paySection
                        payoutsSection
                        scheduleSection
                        saveButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 40)
                }
            }
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle(employee.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            async let payouts: Void = payoutsVM.load()
            async let wages: Void = wageVM.load()
            async let exchangeRates: Void = rates.load()
            await termsVM.load()
            await wages
            await payouts
            await exchangeRates
            let latest = wageVM.history.upcoming() ?? wageVM.history.current()
            newWageType = latest?.payType ?? .hourly
            newWageCurrency = latest?.currency ?? .usd
        }
        .alert("Pay & Schedule", isPresented: Binding(
            get: { termsVM.alertMessage != nil },
            set: { if !$0 { termsVM.alertMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(termsVM.alertMessage ?? "")
        }
    }

    // MARK: - Pay

    private var paySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Pay")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppColors.text)

            if let current = wageVM.history.current() {
                wageRow(title: "Current wage", change: current, caption: currentWageCaption(current))
            } else {
                Text("No wage logged yet.")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textSecondary)
            }

            if let upcoming = wageVM.history.upcoming() {
                HStack(alignment: .top) {
                    wageRow(title: "Upcoming", change: upcoming, caption: "Starts \(upcoming.effectiveDateText)")
                    Button("Cancel") {
                        Task { await wageVM.cancelUpcoming(upcoming) }
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.red)
                }
            }

            Divider()

            newWageEditor

            if !wageVM.history.isEmpty {
                Divider()
                wageHistoryList
            }

            Divider()

            NotesField(title: "Notes", placeholder: "Raises, bonuses, overtime terms…", text: $termsVM.terms.payNotes)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.cardBackground)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColors.border, lineWidth: 1))
        )
        .alert("Wage", isPresented: Binding(
            get: { wageVM.alertMessage != nil },
            set: { if !$0 { wageVM.alertMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(wageVM.alertMessage ?? "")
        }
    }

    private func currentWageCaption(_ current: WageChange) -> String {
        current.id == wageVM.history.changes.first?.id ? "First wage" : "Since \(current.effectiveDateText)"
    }

    private func wageRow(title: String, change: WageChange, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)
            Text(change.summary)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppColors.text)
            if let dollars = rates.dollarsText(change.rate, in: change.currency) {
                Text("\(dollars) \(change.payType.rateUnit) today")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textSecondary)
            }
            Text(caption)
                .font(.system(size: 12))
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var newWageStartText: String {
        guard !wageVM.history.isEmpty else {
            return "This is the first wage. It applies right away, including earlier months."
        }
        let month = wageVM.history.effectiveMonth()
        let start = WageChange(id: month, payType: newWageType, rate: 0, currency: newWageCurrency, changedAt: Date(), changedByEmail: "").effectiveDateText
        if wageVM.history.upcoming() != nil {
            return "Starts \(start), replacing the upcoming change."
        }
        return "Starts \(start)."
    }

    private var newWageEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(wageVM.history.isEmpty ? "First wage" : "New wage")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppColors.text)

            Picker("Pay type", selection: $newWageType) {
                ForEach(PayType.allCases, id: \.self) { payType in
                    Text(payType.displayName).tag(payType)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                Text("Currency")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.text)
                Spacer()
                Picker("Currency", selection: $newWageCurrency) {
                    ForEach(PayCurrency.allCases) { currency in
                        Text(currency.displayName).tag(currency)
                    }
                }
                .pickerStyle(.menu)
                .tint(AppColors.primary)
            }

            AmountField(title: newWageType.rateLabel, text: $newWageText, unit: newWageType.rateUnit, symbol: newWageCurrency.symbol)

            if let dollars = rates.dollarsText(Double(newWageText), in: newWageCurrency) {
                Text("\(dollars) \(newWageType.rateUnit) at today's rate")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textSecondary)
            }

            Text(newWageStartText)
                .font(.system(size: 12))
                .foregroundColor(AppColors.textSecondary)

            Button {
                showLogWageConfirm = true
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppColors.primary, lineWidth: 1.5)
                        .frame(height: 44)
                    if wageVM.isSaving {
                        ProgressView()
                    } else {
                        Text("Log Wage")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppColors.primary)
                    }
                }
            }
            .disabled(wageVM.isSaving || Double(newWageText) == nil)
            .opacity(Double(newWageText) == nil ? 0.5 : 1)
            .confirmationDialog(
                "Log \(newWageType.displayName.lowercased()) wage of \(Double(newWageText)?.formatted(newWageCurrency.format) ?? "") \(newWageType.rateUnit)?",
                isPresented: $showLogWageConfirm,
                titleVisibility: .visible
            ) {
                Button("Log Wage") {
                    Task {
                        if await wageVM.logNewWage(payType: newWageType, rate: Double(newWageText), currency: newWageCurrency) {
                            newWageText = ""
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(newWageStartText)
            }
        }
    }

    private var wageHistoryList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Wage history")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppColors.text)
            ForEach(wageVM.history.changes.reversed()) { change in
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(change.effectiveDateText) · \(change.summary)" + (rates.dollarsText(change.rate, in: change.currency).map { " (\($0))" } ?? ""))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppColors.text)
                    Text(historyCaption(change))
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
    }

    private func historyCaption(_ change: WageChange) -> String {
        let logged = "Logged \(change.changedAt.formatted(date: .abbreviated, time: .omitted))"
        return change.changedByEmail.isEmpty ? logged : "\(logged) by \(change.changedByEmail)"
    }

    // MARK: - Payouts

    private var payoutsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Monthly Payouts")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppColors.text)
                .padding(.bottom, 4)

            Text("Every month since the first logged shift. Unpaid months are estimated from clock-out history and the wage in effect that month; work before the first wage uses the first wage. Marking a month paid locks in its numbers, bonus and deduction.")
                .font(.system(size: 12))
                .foregroundColor(AppColors.textSecondary)
                .padding(.bottom, 16)

            if payoutsVM.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else {
                let records = payoutsVM.records(using: wageVM.history)
                ForEach(Array(records.enumerated()), id: \.element.id) { index, record in
                    if index > 0 {
                        Divider()
                            .padding(.vertical, 8)
                    }
                    payoutRow(record)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.cardBackground)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColors.border, lineWidth: 1))
        )
        .alert("Payouts", isPresented: Binding(
            get: { payoutsVM.alertMessage != nil },
            set: { if !$0 { payoutsVM.alertMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(payoutsVM.alertMessage ?? "")
        }
        .sheet(item: $payoutToMarkPaid) { record in
            MarkPaidSheet(record: record, payoutsVM: payoutsVM)
        }
    }

    private func payoutRow(_ record: PayoutRecord) -> some View {
        HStack(alignment: .center, spacing: 12) {
            NavigationLink {
                PayoutMonthCalendarView(monthKey: record.id, wages: wageVM.history, payoutsVM: payoutsVM)
            } label: {
                HStack(spacing: 6) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(record.monthTitle)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppColors.text)
                        Text(payoutDetail(record))
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            VStack(alignment: .trailing, spacing: 4) {
                Text(record.amount?.formatted(record.currency.format) ?? "—")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.text)
                if let dollars = rates.dollarsText(record.amount, in: record.currency, rate: record.usdRate) {
                    Text(dollars)
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary)
                }
                if let paidAt = record.paidAt {
                    Menu {
                        Button("Mark as Unpaid", role: .destructive) {
                            Task { await payoutsVM.unmarkPaid(record) }
                        }
                    } label: {
                        Text("Paid \(paidAt.formatted(.dateTime.month(.abbreviated).day()))")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.green)
                    }
                } else {
                    Button("Mark Paid") { payoutToMarkPaid = record }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.primary)
                        .disabled(record.basePay == nil)
                }
            }
        }
    }

    private func payoutDetail(_ record: PayoutRecord) -> String {
        let hours = record.hoursWorked.formatted(.number.precision(.fractionLength(0...1)))
        var detail: String
        switch record.payType {
        case .hourly:
            guard let rate = record.rate else { return "\(hours) hrs · no wage logged" }
            detail = "\(hours) hrs × \(rate.formatted(record.currency.format))"
        case .salary:
            detail = record.rate == nil ? "\(hours) hrs · no wage logged" : "\(hours) hrs · monthly salary"
        }
        if record.bonus > 0 { detail += " + bonus" }
        if record.deduction > 0 { detail += " − deduction" }
        return detail
    }

    // MARK: - Schedule

    private var scheduleSection: some View {
        WeeklyScheduleEditor(schedule: $termsVM.terms.schedule, timeZoneId: $termsVM.terms.timeZoneId)
    }

    private var saveButton: some View {
        Button {
            Task { await termsVM.save() }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(AppColors.primary)
                    .frame(height: 50)
                if termsVM.isSaving {
                    ProgressView().tint(.white)
                } else {
                    Text("Save Notes & Schedule")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
        }
        .disabled(termsVM.isSaving)
        .opacity(termsVM.isSaving ? 0.7 : 1)
    }
}
