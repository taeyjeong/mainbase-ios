import FirebaseFirestore
import Foundation

/// One month of pay for an employee. Unpaid months are estimates computed from clock-out
/// history and the wage in effect that month (WageHistory); once a month is marked paid, the
/// numbers (plus any bonus, deduction and note) are frozen at users/{uid}/payouts/{id} so
/// later wage changes don't rewrite past payouts.
///
/// TODO (not implemented yet): the employee can also mark their own month as paid (e.g. to
/// confirm they received it). Today only an admin can, from EmployeeDetailView; this needs an
/// employee-facing payouts screen and a firestore.rules change (see the payouts rule).
struct PayoutRecord: Identifiable {
    /// "yyyy-MM" of the month in US Pacific time; also the Firestore doc id.
    let id: String
    let payType: PayType
    /// Hourly rate or monthly salary in effect that month; nil if no wage has been logged.
    let rate: Double?
    let hoursWorked: Double
    /// Added on top of base pay when marking paid.
    var bonus: Double = 0
    /// Taken off base pay when marking paid.
    var deduction: Double = 0
    var note: String = ""
    var paidAt: Date?

    var isPaid: Bool { paidAt != nil }

    /// Hours × rate for hourly, the monthly salary for salary; nil if no wage is set.
    var basePay: Double? {
        guard let rate else { return nil }
        switch payType {
        case .hourly: return (rate * hoursWorked * 100).rounded() / 100
        case .salary: return rate
        }
    }

    /// Base pay + bonus − deduction.
    var amount: Double? {
        basePay.map { (($0 + bonus - deduction) * 100).rounded() / 100 }
    }

    var monthTitle: String {
        guard let monthStart = Self.monthStart(forKey: id) else { return id }
        return Self.titleFormatter.string(from: monthStart)
    }

    init(id: String, payType: PayType, rate: Double?, hoursWorked: Double) {
        self.id = id
        self.payType = payType
        self.rate = rate
        self.hoursWorked = hoursWorked
    }

    init(id: String, data: [String: Any]) {
        self.id = id
        payType = (data["payType"] as? String).flatMap(PayType.init(rawValue:)) ?? .hourly
        rate = (data["rate"] as? NSNumber)?.doubleValue
        hoursWorked = (data["hoursWorked"] as? NSNumber)?.doubleValue ?? 0
        bonus = (data["bonus"] as? NSNumber)?.doubleValue ?? 0
        deduction = (data["deduction"] as? NSNumber)?.doubleValue ?? 0
        note = data["note"] as? String ?? ""
        paidAt = (data["paidAt"] as? Timestamp)?.dateValue()
    }

    var firestoreData: [String: Any] {
        [
            "payType": payType.rawValue,
            "rate": rate as Any? ?? NSNull(),
            "hoursWorked": hoursWorked,
            "basePay": basePay as Any? ?? NSNull(),
            "bonus": bonus,
            "deduction": deduction,
            "note": note,
            "amount": amount as Any? ?? NSNull(),
        ]
    }
}

extension PayoutRecord {
    /// Months are Pacific months, matching EmploymentTerms.scheduleTimeZone.
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = EmploymentTerms.scheduleTimeZone
        return calendar
    }()

    private static let keyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM"
        return formatter
    }()

    private static let titleFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()

    static func monthKey(for date: Date) -> String {
        keyFormatter.string(from: date)
    }

    static func monthStart(forKey key: String) -> Date? {
        keyFormatter.date(from: key)
    }

    private static let dayKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    /// "yyyy-MM-dd" of the Pacific day containing `date`.
    static func dayKey(for date: Date) -> String {
        dayKeyFormatter.string(from: date)
    }
}
