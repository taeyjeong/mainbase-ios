import SwiftUI

/// Card for editing a weekly schedule, with the week's total scheduled hours. Shared by the
/// admin's EmployeeDetailView and the employee's own EditMyScheduleSheet. Times are wall-clock
/// times in US Pacific (EmploymentTerms.scheduleTimeZone), so the pickers run in a fixed GMT
/// calendar to avoid shifting by the editor's own zone.
struct WeeklyScheduleEditor: View {
    @Binding var schedule: [Weekday: WorkDay]

    private static let pickerTimeZone = TimeZone(identifier: "GMT")!

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Weekly Schedule")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.text)
                Spacer()
                Text("\(DurationFormatting.hoursMinutes(EmploymentTerms.weeklyHours(schedule))) / week")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.primary)
            }
            .padding(.bottom, 4)

            Text("All times are Pacific Time (US).")
                .font(.system(size: 12))
                .foregroundColor(AppColors.textSecondary)
                .padding(.bottom, 16)

            ForEach(Array(Weekday.allCases.enumerated()), id: \.element) { index, day in
                if index > 0 {
                    Divider()
                        .padding(.vertical, 8)
                }
                dayRow(day)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.cardBackground)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColors.border, lineWidth: 1))
        )
    }

    private func dayRow(_ day: Weekday) -> some View {
        let workDay = Binding(
            get: { schedule[day] ?? .off },
            set: { schedule[day] = $0 }
        )
        return VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: workDay.isWorking) {
                HStack {
                    Text(day.displayName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.text)
                    if workDay.wrappedValue.scheduledHours > 0 {
                        Text(DurationFormatting.hoursMinutes(workDay.wrappedValue.scheduledHours))
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
            .tint(AppColors.primary)

            if workDay.wrappedValue.isWorking {
                HStack {
                    DatePicker("Start", selection: timeBinding(workDay.startMinutes), displayedComponents: .hourAndMinute)
                        .labelsHidden()
                    Text("to")
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.textSecondary)
                    DatePicker("End", selection: timeBinding(workDay.endMinutes), displayedComponents: .hourAndMinute)
                        .labelsHidden()
                    Spacer()
                }
                .environment(\.timeZone, Self.pickerTimeZone)
            }
        }
    }

    /// Bridges minutes-since-midnight to a Date on 1970-01-01 in GMT for DatePicker.
    private func timeBinding(_ minutes: Binding<Int>) -> Binding<Date> {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Self.pickerTimeZone
        return Binding(
            get: { Date(timeIntervalSince1970: TimeInterval(minutes.wrappedValue * 60)) },
            set: { date in
                let components = calendar.dateComponents([.hour, .minute], from: date)
                minutes.wrappedValue = (components.hour ?? 0) * 60 + (components.minute ?? 0)
            }
        )
    }
}
