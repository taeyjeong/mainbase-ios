import Foundation

enum Weekday: String, CaseIterable, Identifiable {
    case monday, tuesday, wednesday, thursday, friday, saturday, sunday

    var id: String { rawValue }

    var displayName: String { rawValue.capitalized }
}

/// One day of an employee's weekly schedule. Times are minutes since midnight in
/// EmploymentTerms.scheduleTimeZone (US Pacific).
struct WorkDay: Equatable {
    var isWorking: Bool
    var startMinutes: Int
    var endMinutes: Int

    static let standard = WorkDay(isWorking: true, startMinutes: 9 * 60, endMinutes: 17 * 60)
    static let off = WorkDay(isWorking: false, startMinutes: 9 * 60, endMinutes: 17 * 60)
}

/// Pay notes and weekly schedule for one employee, stored at users/{uid}/employment/terms and
/// set only by an admin. Kept off the user doc because that doc is readable by every signed-in
/// user and writable by its owner. The wage itself is logged separately (WageChange).
struct EmploymentTerms {
    /// Free-form admin notes about pay (raises, bonuses, overtime terms, …).
    var payNotes: String = ""
    var schedule: [Weekday: WorkDay] = Dictionary(uniqueKeysWithValues: Weekday.allCases.map { day in
        (day, day == .saturday || day == .sunday ? WorkDay.off : WorkDay.standard)
    })

    init() {}

    init(data: [String: Any]) {
        payNotes = data["payNotes"] as? String ?? ""
        if let scheduleData = data["schedule"] as? [String: [String: Any]] {
            for day in Weekday.allCases {
                guard let dayData = scheduleData[day.rawValue] else { continue }
                schedule[day] = WorkDay(
                    isWorking: dayData["isWorking"] as? Bool ?? false,
                    startMinutes: dayData["startMinutes"] as? Int ?? WorkDay.standard.startMinutes,
                    endMinutes: dayData["endMinutes"] as? Int ?? WorkDay.standard.endMinutes
                )
            }
        }
    }

    var firestoreData: [String: Any] {
        var scheduleData: [String: Any] = [:]
        for day in Weekday.allCases {
            let workDay = schedule[day] ?? .off
            scheduleData[day.rawValue] = [
                "isWorking": workDay.isWorking,
                "startMinutes": workDay.startMinutes,
                "endMinutes": workDay.endMinutes,
            ]
        }
        return [
            "payNotes": payNotes.trimmingCharacters(in: .whitespacesAndNewlines),
            "schedule": scheduleData,
        ]
    }
}

extension EmploymentTerms {
    /// Every schedule is set, stored and enforced in US Pacific time, for all employees.
    /// Mirrors SCHEDULE_TIME_ZONE in functions/scheduleTime.js.
    ///
    /// TODO (not implemented yet): when schedule times are shown to an employee, convert them
    /// from Pacific to the time zone of the `country` on their profile (UserProfile.country),
    /// e.g. a 9:00 AM Pacific start shows as 1:00 AM the next day for a user in Korea. Countries
    /// spanning several zones (US, Canada, Australia, …) will need a way to pick one. Admin
    /// screens keep showing Pacific.
    static let scheduleTimeZone = TimeZone(identifier: "America/Los_Angeles")!

    /// A clock-in within this long after the scheduled start is recorded as the scheduled start.
    static let clockInSnapWindow: TimeInterval = 30 * 60
    /// A session counts toward a shift only if it started no earlier than this before the start.
    /// Mirrors EARLY_CLOCK_IN_ALLOWANCE_MS in functions/index.js.
    static let earlyClockInAllowance: TimeInterval = 4 * 60 * 60

    /// The scheduled shift on the schedule-local day containing `date`, or nil on a day off.
    func shift(on date: Date) -> DateInterval? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Self.scheduleTimeZone
        // Calendar weekday is 1 = Sunday ... 7 = Saturday.
        let weekdays: [Weekday] = [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday]
        let day = weekdays[calendar.component(.weekday, from: date) - 1]
        guard let workDay = schedule[day], workDay.isWorking, workDay.endMinutes > workDay.startMinutes,
              let start = calendar.date(bySettingHour: workDay.startMinutes / 60, minute: workDay.startMinutes % 60, second: 0, of: date),
              let end = calendar.date(bySettingHour: workDay.endMinutes / 60, minute: workDay.endMinutes % 60, second: 0, of: date)
        else { return nil }
        return DateInterval(start: start, end: end)
    }

    /// The shift a session starting at `clockIn` belongs to, matching the server's rule.
    func shift(containingClockIn clockIn: Date) -> DateInterval? {
        guard let shift = shift(on: clockIn.addingTimeInterval(Self.earlyClockInAllowance)) ?? shift(on: clockIn)
        else { return nil }
        let earliest = shift.start.addingTimeInterval(-Self.earlyClockInAllowance)
        return clockIn >= earliest && clockIn < shift.end ? shift : nil
    }
}
