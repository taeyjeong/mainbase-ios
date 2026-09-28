import SwiftUI

/// Admin-only month calendar, pushed from a Monthly Payouts row in EmployeeDetailView. Shows
/// hours worked per day and, for hourly pay, what each day earned at the record's rate (the
/// frozen rate for a paid month, the wage in effect that month for an estimate), plus any
/// bonus, deduction and note added when it was marked paid. Tapping a day shows that day's
/// shifts (clock in/out, hours) and the report written for each. Days are Pacific days, and a
/// session counts toward the day it was clocked out on, matching the month totals.
struct PayoutMonthCalendarView: View {
    let record: PayoutRecord
    let entriesByDay: [String: [HistoryEntry]]

    /// "yyyy-MM-dd" of the tapped day.
    @State private var selectedDayKey: String?

    private static let dayDetailID = "dayDetail"

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeZone = PayoutRecord.calendar.timeZone
        formatter.timeStyle = .short
        return formatter
    }()

    private static let dayTitleFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = PayoutRecord.calendar
        formatter.timeZone = PayoutRecord.calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate("EEEEMMMMd")
        return formatter
    }()

    private static let currencyFormat = FloatingPointFormatStyle<Double>.Currency(code: "USD")
    private static let cellCurrencyFormat = currencyFormat.precision(.fractionLength(0))
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
                summaryRow("Hourly rate", record.rate?.formatted(Self.currencyFormat) ?? "Not set")
                summaryRow("Earned", record.basePay?.formatted(Self.currencyFormat) ?? "—")
            case .salary:
                summaryRow("Monthly salary", record.basePay?.formatted(Self.currencyFormat) ?? "Not set")
            }
            if record.bonus > 0 {
                summaryRow("Bonus", "+" + record.bonus.formatted(Self.currencyFormat))
            }
            if record.deduction > 0 {
                summaryRow("Deduction", "−" + record.deduction.formatted(Self.currencyFormat))
            }
            summaryRow("Total", record.amount?.formatted(Self.currencyFormat) ?? "—", emphasized: true)
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

    private func summaryRow(_ label: String, _ value: String, emphasized: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(AppColors.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: emphasized ? 16 : 14, weight: emphasized ? .semibold : .medium))
                .foregroundColor(AppColors.text)
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

            Text("Pacific Time (US). Hours count toward the day the shift was clocked out. Tap a day for its shifts and reports.")
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
                        Text((hours * rate).formatted(Self.cellCurrencyFormat))
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
                    Text("Earned \((hours * rate).formatted(Self.currencyFormat)) at \(rate.formatted(Self.currencyFormat)) / hour")
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
                        shiftRow(entry)
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

    private func shiftRow(_ entry: HistoryEntry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(Self.timeFormatter.string(from: entry.clockIn)) – \(Self.timeFormatter.string(from: entry.clockOut)) PT")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppColors.text)
                Spacer()
                Text(entry.durationFormatted)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppColors.primary)
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
