import SwiftUI

/// Admin-only month calendar, pushed from a Monthly Payouts row in EmployeeDetailView. Shows
/// hours worked per day and, for hourly pay, what each day earned at the record's rate (the
/// frozen rate for a paid month, the wage in effect that month for an estimate), plus any
/// bonus, deduction and note added when it was marked paid. Tapping a day shows that day's
/// shifts (clock in/out, hours) and the report written for each; in an unpaid month, a shift's
/// times can be corrected (EditShiftSheet). Days are Pacific days, and a session counts toward
/// the day it was clocked out on, matching the month totals; shift times are shown in the
/// viewer's own time zone.
struct PayoutMonthCalendarView: View {
    let monthKey: String
    let wages: WageHistory
    @ObservedObject var payoutsVM: EmployeePayoutsViewModel

    /// "yyyy-MM-dd" of the tapped day.
    @State private var selectedDayKey: String?
    @State private var shiftToEdit: HistoryEntry?
    @ObservedObject private var rates = ExchangeRates.shared

    private var record: PayoutRecord {
        payoutsVM.record(forMonth: monthKey, using: wages)
    }

    private var entriesByDay: [String: [HistoryEntry]] {
        payoutsVM.entriesByDay
    }

    private static let dayDetailID = "dayDetail"

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMMd")
        return formatter
    }()

    private static var localZoneAbbreviation: String {
        TimeZone.current.abbreviation() ?? TimeZone.current.identifier
    }

    private static let dayTitleFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = PayoutRecord.calendar
        formatter.timeZone = PayoutRecord.calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate("EEEEMMMMd")
        return formatter
    }()

    private var currencyFormat: FloatingPointFormatStyle<Double>.Currency { record.currency.format }
    private var cellCurrencyFormat: FloatingPointFormatStyle<Double>.Currency { currencyFormat.precision(.fractionLength(0)) }
    private static let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    /// Sunday-first weekday symbols ("S", "M", …), matching PayoutRecord.calendar.
    private var weekdaySymbols: [String] {
        PayoutRecord.calendar.veryShortStandaloneWeekdaySymbols
    }

    /// nil entries are the blank cells before the 1st, so the 1st lands under its weekday.
    private var days: [Date?] {
        let calendar = PayoutRecord.calendar
        guard let monthStart = PayoutRecord.monthStart(forKey: record.id),
              let dayRange = calendar.range(of: .day, in: .month, for: monthStart)
        else { return [] }
        let leadingBlanks = calendar.component(.weekday, from: monthStart) - calendar.firstWeekday
        let blanks = [Date?](repeating: nil, count: (leadingBlanks + 7) % 7)
        let dates = dayRange.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: monthStart)
        }
        return blanks + dates
    }

    /// "≈ $…" at the rate frozen when the month was paid, or today's for an estimate.
    private func dollarsText(_ amount: Double?) -> String? {
        rates.dollarsText(amount, in: record.currency, rate: record.usdRate)
    }

    private var showsEarnings: Bool {
        record.payType == .hourly && record.rate != nil
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    summaryCard
                    calendarCard
                    dayDetailCard
                        .id(Self.dayDetailID)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
            .onChange(of: selectedDayKey) { _, key in
                guard key != nil else { return }
                withAnimation { proxy.scrollTo(Self.dayDetailID, anchor: .top) }
            }
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle(record.monthTitle)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $shiftToEdit) { entry in
            EditShiftSheet(entry: entry, payoutsVM: payoutsVM)
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(record.isPaid ? "Paid" : "Estimate")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(record.isPaid ? .green : AppColors.textSecondary)
                Spacer()
            }
            summaryRow("Hours worked", record.hoursWorked.formatted(.number.precision(.fractionLength(0...1))) + " hrs")
            switch record.payType {
            case .hourly:
                summaryRow("Hourly rate", record.rate?.formatted(currencyFormat) ?? "Not set", dollars: dollarsText(record.rate))
                summaryRow("Earned", record.basePay?.formatted(currencyFormat) ?? "—", dollars: dollarsText(record.basePay))
            case .salary:
                summaryRow("Monthly salary", record.basePay?.formatted(currencyFormat) ?? "Not set", dollars: dollarsText(record.basePay))
            }
            if record.bonus > 0 {
                summaryRow("Bonus", "+" + record.bonus.formatted(currencyFormat))
            }
            if record.deduction > 0 {
                summaryRow("Deduction", "−" + record.deduction.formatted(currencyFormat))
            }
            summaryRow("Total", record.amount?.formatted(currencyFormat) ?? "—", dollars: dollarsText(record.amount), emphasized: true)
            if !record.note.isEmpty {
                Text(record.note)
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.cardBackground)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColors.border, lineWidth: 1))
        )
    }

    /// `dollars` is the "≈ $…" figure shown under a non-USD value (ExchangeRates).
    private func summaryRow(_ label: String, _ value: String, dollars: String? = nil, emphasized: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(AppColors.textSecondary)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(value)
                    .font(.system(size: emphasized ? 16 : 14, weight: emphasized ? .semibold : .medium))
                    .foregroundColor(AppColors.text)
                if let dollars {
                    Text(dollars)
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
    }

    private var calendarCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: Self.columns, spacing: 4) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                        .frame(maxWidth: .infinity)
                }
                ForEach(Array(days.enumerated()), id: \.offset) { _, date in
                    if let date {
                        dayCell(date)
                    } else {
                        Color.clear.frame(height: cellHeight)
                    }
                }
            }

            Text("Days follow Pacific Time (US), and hours count toward the day the shift was clocked out. Shift times are in your time zone (\(Self.localZoneAbbreviation)). Tap a day for its shifts and reports.")
                .font(.system(size: 12))
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.cardBackground)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColors.border, lineWidth: 1))
        )
    }

    private var cellHeight: CGFloat { showsEarnings ? 58 : 46 }

    private func hours(forDayKey key: String) -> Double {
        (entriesByDay[key] ?? []).reduce(0) { $0 + $1.hours }
    }

    private func dayCell(_ date: Date) -> some View {
        let key = PayoutRecord.dayKey(for: date)
        let hours = hours(forDayKey: key)
        let worked = hours > 0
        let isSelected = key == selectedDayKey
        return Button {
            selectedDayKey = isSelected ? nil : key
        } label: {
            VStack(spacing: 2) {
                Text("\(PayoutRecord.calendar.component(.day, from: date))")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(worked ? AppColors.text : AppColors.textSecondary)
                if worked {
                    Text(hours.formatted(.number.precision(.fractionLength(0...1))) + "h")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AppColors.primary)
                    if showsEarnings, let rate = record.rate {
                        Text((hours * rate).formatted(cellCurrencyFormat))
                            .font(.system(size: 10))
                            .foregroundColor(AppColors.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: cellHeight)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(worked ? AppColors.primary.opacity(0.12) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppColors.primary, lineWidth: isSelected ? 2 : 0)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var dayDetailCard: some View {
        if let key = selectedDayKey, let date = Self.dayDate(forKey: key) {
            let entries = entriesByDay[key] ?? []
            let hours = hours(forDayKey: key)
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(Self.dayTitleFormatter.string(from: date))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.text)
                    Spacer()
                    Text(hours.formatted(.number.precision(.fractionLength(0...2))) + " hrs")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.primary)
                }
                if showsEarnings, let rate = record.rate, hours > 0 {
                    Text("Earned \((hours * rate).formatted(currencyFormat)) at \(rate.formatted(currencyFormat)) / hour")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary)
                }

                if entries.isEmpty {
                    Text("No shifts clocked out this day.")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.textSecondary)
                } else {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        if index > 0 { Divider() }
                        shiftRow(entry, dayKey: key)
                    }
                    if record.isPaid {
                        Text("This month is marked paid. Mark it unpaid to change its shifts.")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.textSecondary)
                    }
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
    }

    /// A time in the viewer's zone, prefixed with its local date when that isn't the Pacific
    /// day the shift is listed under (e.g. a viewer in Korea, or an overnight shift).
    private func timeText(_ date: Date, dayKey: String) -> String {
        let time = Self.timeFormatter.string(from: date)
        let local = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let localKey = String(format: "%04d-%02d-%02d", local.year ?? 0, local.month ?? 0, local.day ?? 0)
        return localKey == dayKey ? time : "\(Self.shortDateFormatter.string(from: date)), \(time)"
    }

    private func shiftRow(_ entry: HistoryEntry, dayKey: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(timeText(entry.clockIn, dayKey: dayKey)) – \(timeText(entry.clockOut, dayKey: dayKey)) \(Self.localZoneAbbreviation)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppColors.text)
                Spacer()
                Text(entry.durationFormatted)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppColors.primary)
                if !record.isPaid {
                    Button {
                        shiftToEdit = entry
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(AppColors.primary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Edit clock-in and clock-out")
                }
            }
            if entry.editedAt != nil {
                Text("Times edited by an admin")
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.textSecondary)
            }
            Text("Report")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)
            Text(entry.report.isEmpty ? "No report written." : entry.report)
                .font(.system(size: 14))
                .foregroundColor(entry.report.isEmpty ? AppColors.textSecondary : AppColors.text)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
    }

    private static func dayDate(forKey key: String) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return PayoutRecord.calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }
}
