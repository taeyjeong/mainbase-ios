import FirebaseFirestore
import Foundation

enum PayType: String, CaseIterable {
    case hourly
    case salary

    var displayName: String {
        switch self {
        case .hourly: return "Hourly"
        case .salary: return "Salary"
        }
    }

    var rateLabel: String {
        switch self {
        case .hourly: return "Hourly rate"
        case .salary: return "Monthly salary"
        }
    }

    var rateUnit: String {
        switch self {
        case .hourly: return "/ hour"
        case .salary: return "/ month"
        }
    }
}

/// One entry in an employee's wage log, stored at users/{uid}/wageHistory/{id}. Logged by an
/// admin from EmployeeDetailView; entries are never edited, only added (or an upcoming one
/// cancelled), so the log is a record of every wage the employee has had.
struct WageChange: Identifiable, Equatable {
    /// "yyyy-MM" Pacific month the wage starts on the 1st of; also the Firestore doc id, so
    /// there's at most one change per month (logging again before it starts replaces it).
    let id: String
    let payType: PayType
    /// Dollars per hour for hourly, dollars per month for salary.
    let rate: Double
    /// When the admin logged the change.
    let changedAt: Date
    let changedByEmail: String

    init(id: String, payType: PayType, rate: Double, changedAt: Date, changedByEmail: String) {
        self.id = id
        self.payType = payType
        self.rate = rate
        self.changedAt = changedAt
        self.changedByEmail = changedByEmail
    }

    init?(id: String, data: [String: Any]) {
        guard let payType = (data["payType"] as? String).flatMap(PayType.init(rawValue:)),
              let rate = (data["rate"] as? NSNumber)?.doubleValue
        else { return nil }
        self.id = id
        self.payType = payType
        self.rate = rate
        changedAt = (data["changedAt"] as? Timestamp)?.dateValue() ?? Date()
        changedByEmail = data["changedByEmail"] as? String ?? ""
    }

    var firestoreData: [String: Any] {
        [
            "payType": payType.rawValue,
            "rate": rate,
            "effectiveMonth": id,
            "changedAt": Timestamp(date: changedAt),
            "changedByEmail": changedByEmail,
        ]
    }

    /// "Hourly · $25.00 / hour"
    var summary: String {
        "\(payType.displayName) · \(rate.formatted(.currency(code: "USD"))) \(payType.rateUnit)"
    }

    /// "Oct 1, 2026", the 1st of the effective month.
    var effectiveDateText: String {
        guard let date = PayoutRecord.monthStart(forKey: id) else { return id }
        return Self.effectiveDateFormatter.string(from: date)
    }

    private static let effectiveDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = PayoutRecord.calendar
        formatter.timeZone = PayoutRecord.calendar.timeZone
        formatter.dateStyle = .medium
        return formatter
    }()
}

/// An employee's wage log, oldest first, with the rules for which wage applies when.
///
/// - The first wage applies right away: from the month it's logged, and to every earlier month,
///   so payouts before it was logged still have a wage.
/// - Every later change (salary → hourly, salary → new salary, hourly → salary, hourly → new
///   hourly) starts on the 1st of the month after it's logged.
struct WageHistory {
    let changes: [WageChange]

    init(_ changes: [WageChange]) {
        self.changes = changes.sorted { $0.id < $1.id }
    }

    var isEmpty: Bool { changes.isEmpty }

    /// The wage in effect for a "yyyy-MM" month. "yyyy-MM" keys sort chronologically as strings.
    func wage(forMonth monthKey: String) -> WageChange? {
        changes.last(where: { $0.id <= monthKey }) ?? changes.first
    }

    func current(now: Date = Date()) -> WageChange? {
        wage(forMonth: PayoutRecord.monthKey(for: now))
    }

    /// A logged change that hasn't started yet.
    func upcoming(now: Date = Date()) -> WageChange? {
        let thisMonth = PayoutRecord.monthKey(for: now)
        return changes.last(where: { $0.id > thisMonth })
    }

    /// The month a wage logged at `now` starts: this month for the first wage, next month after that.
    func effectiveMonth(forChangeAt now: Date = Date()) -> String {
        guard !changes.isEmpty,
              let nextMonth = PayoutRecord.calendar.date(byAdding: .month, value: 1, to: now)
        else { return PayoutRecord.monthKey(for: now) }
        return PayoutRecord.monthKey(for: nextMonth)
    }
}
