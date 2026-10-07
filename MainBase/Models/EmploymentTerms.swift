import Foundation

enum Weekday: String, CaseIterable, Identifiable {
    case monday, tuesday, wednesday, thursday, friday, saturday, sunday

    var id: String { rawValue }

    var displayName: String { rawValue.capitalized }
}

/// One day of an employee's weekly schedule. Times are minutes since midnight in the
/// schedule's own time zone (EmploymentTerms.timeZone).
struct WorkDay: Equatable {
    var isWorking: Bool
    var startMinutes: Int
    var endMinutes: Int

    static let standard = WorkDay(isWorking: true, startMinutes: 9 * 60, endMinutes: 17 * 60)
    static let off = WorkDay(isWorking: false, startMinutes: 9 * 60, endMinutes: 17 * 60)

    /// Hours on the clock this day; 0 on a day off or when the end isn't after the start.
    var scheduledHours: Double {
        guard isWorking, endMinutes > startMinutes else { return 0 }
        return Double(endMinutes - startMinutes) / 60
    }
}

/// Pay notes and weekly schedule for one employee, stored at users/{uid}/employment/terms and
/// set by an admin (the employee may edit only the schedule and its time zone). Kept off the user doc because that doc is readable by every signed-in
/// user and writable by its owner. The wage itself is logged separately (WageChange).
struct EmploymentTerms {
    /// Free-form admin notes about pay (raises, bonuses, overtime terms, …).
    var payNotes: String = ""
    var schedule: [Weekday: WorkDay] = Dictionary(uniqueKeysWithValues: Weekday.allCases.map { day in
        (day, day == .saturday || day == .sunday ? WorkDay.off : WorkDay.standard)
    })
    /// IANA identifier of the zone the schedule's times are in, e.g. "Asia/Tokyo".
    var timeZoneId: String = EmploymentTerms.defaultTimeZone.identifier

    init() {}

    init(data: [String: Any]) {
        payNotes = data["payNotes"] as? String ?? ""
        // Schedules saved before per-employee zones have no timeZone and stay Pacific.
        if let id = data["timeZone"] as? String, TimeZone(identifier: id) != nil {
            timeZoneId = id
        }
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
            "timeZone": timeZoneId,
        ]
    }
}

extension EmploymentTerms {
    /// The zone of a schedule saved without one (all schedules from before per-employee zones),
    /// and the default for a new schedule. Mirrors DEFAULT_SCHEDULE_TIME_ZONE in
    /// functions/scheduleTime.js. Pay days and months are always Pacific (PayoutRecord.calendar).
    static let defaultTimeZone = TimeZone(identifier: "America/Los_Angeles")!

    /// Each schedule is set, stored and enforced in its own zone, so a 9:00 AM Tokyo start stays
    /// 9:00 AM Tokyo through US daylight saving changes. ScheduleView shows the shifts converted
    /// to the device's zone, which differs only when the employee is away from it.
    var timeZone: TimeZone { TimeZone(identifier: timeZoneId) ?? Self.defaultTimeZone }

    /// The schedule's own calendar, whose days are the schedule's days.
    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    /// A clock-in within this long after the scheduled start is recorded as the scheduled start.
    static let clockInSnapWindow: TimeInterval = 30 * 60
    /// A session counts toward a shift only if it started no earlier than this before the start.
    /// Mirrors EARLY_CLOCK_IN_ALLOWANCE_MS in functions/index.js.
    static let earlyClockInAllowance: TimeInterval = 4 * 60 * 60

    /// Total scheduled hours across the week.
    static func weeklyHours(_ schedule: [Weekday: WorkDay]) -> Double {
        Weekday.allCases.reduce(0) { $0 + (schedule[$1]?.scheduledHours ?? 0) }
    }

    /// The first working day whose end isn't after its start, which can't be saved.
    static func invalidDay(in schedule: [Weekday: WorkDay]) -> Weekday? {
        Weekday.allCases.first { day in
            guard let workDay = schedule[day], workDay.isWorking else { return false }
            return workDay.endMinutes <= workDay.startMinutes
        }
    }

    /// The scheduled shift on the schedule-local day containing `date`, or nil on a day off.
    func shift(on date: Date) -> DateInterval? {
        let calendar = calendar
        // Calendar weekday is 1 = Sunday ... 7 = Saturday.
        let weekdays: [Weekday] = [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday]
        let day = weekdays[calendar.component(.weekday, from: date) - 1]
        guard let workDay = schedule[day], workDay.isWorking, workDay.endMinutes > workDay.startMinutes,
              let start = calendar.date(bySettingHour: workDay.startMinutes / 60, minute: workDay.startMinutes % 60, second: 0, of: date),
              let end = calendar.date(bySettingHour: workDay.endMinutes / 60, minute: workDay.endMinutes % 60, second: 0, of: date)
        else { return nil }
        return DateInterval(start: start, end: end)
    }

    /// Scheduled shifts from today through the next `days - 1` days in the schedule's zone that
    /// haven't ended yet, including one in progress.
    func upcomingShifts(days: Int, now: Date = Date()) -> [DateInterval] {
        let calendar = calendar
        let today = calendar.startOfDay(for: now)
        return (0..<days).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: today).flatMap { shift(on: $0) }
        }
        .filter { $0.end > now }
    }

    /// The shift a session starting at `clockIn` belongs to, matching the server's rule.
    func shift(containingClockIn clockIn: Date) -> DateInterval? {
        guard let shift = shift(on: clockIn.addingTimeInterval(Self.earlyClockInAllowance)) ?? shift(on: clockIn)
        else { return nil }
        let earliest = shift.start.addingTimeInterval(-Self.earlyClockInAllowance)
        return clockIn >= earliest && clockIn < shift.end ? shift : nil
    }
}
