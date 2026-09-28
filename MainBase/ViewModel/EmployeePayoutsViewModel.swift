import Combine
import FirebaseAuth
import FirebaseFirestore
import Foundation

@MainActor
final class EmployeePayoutsViewModel: ObservableObject {
    @Published private(set) var hoursByMonth: [String: Double] = [:]
    /// Clock-out history per Pacific day ("yyyy-MM-dd"), earliest first, for
    /// PayoutMonthCalendarView. Like hoursByMonth, a session counts toward the day it was
    /// clocked out on.
    @Published private(set) var entriesByDay: [String: [HistoryEntry]] = [:]
    @Published private(set) var paidRecords: [String: PayoutRecord] = [:]
    @Published private(set) var isLoading = true
    @Published var alertMessage: String?

    private let db = Firestore.firestore()
    private let userId: String
    /// Every logged shift; hoursByMonth, entriesByDay and monthKeys are derived from it.
    private var entries: [HistoryEntry] = []

    init(userId: String) {
        self.userId = userId
    }

    private var userRef: DocumentReference {
        db.collection("users").document(userId)
    }

    /// Every month from the employee's first logged shift (or first paid month) through the
    /// current Pacific month, newest first. Work logged before any wage existed is included, and
    /// WageHistory prices it at the first wage.
    @Published private(set) var monthKeys: [String] = [PayoutRecord.monthKey(for: Date())]

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let historySnapshot = userRef.collection("history").getDocuments()
            async let payoutsSnapshot = userRef.collection("payouts").getDocuments()

            entries = try await historySnapshot.documents.compactMap { doc in
                let data = doc.data()
                guard let clockIn = (data["clockIn"] as? Timestamp)?.dateValue(),
                      let clockOut = (data["clockOut"] as? Timestamp)?.dateValue()
                else { return nil }
                return HistoryEntry(
                    id: doc.documentID,
                    clockIn: clockIn,
                    clockOut: clockOut,
                    durationFormatted: data["durationFormatted"] as? String ?? "",
                    report: data["report"] as? String ?? "",
                    editedAt: (data["editedAt"] as? Timestamp)?.dateValue()
                )
            }
            paidRecords = Dictionary(uniqueKeysWithValues: try await payoutsSnapshot.documents.map { doc in
                (doc.documentID, PayoutRecord(id: doc.documentID, data: doc.data()))
            })
            rebuildTotals()
        } catch {
            alertMessage = "Could not load payouts right now."
        }
    }

    /// Recomputes hoursByMonth, entriesByDay and monthKeys from `entries` and paidRecords.
    private func rebuildTotals() {
        var monthHours: [String: Double] = [:]
        var dayEntries: [String: [HistoryEntry]] = [:]
        for entry in entries {
            monthHours[PayoutRecord.monthKey(for: entry.clockOut), default: 0] += entry.hours
            dayEntries[PayoutRecord.dayKey(for: entry.clockOut), default: []].append(entry)
        }
        hoursByMonth = monthHours
        entriesByDay = dayEntries.mapValues { $0.sorted { $0.clockIn < $1.clockIn } }
        // Keeps months already listed, so moving a month's only shift out of it doesn't drop the
        // row (and pop its open calendar).
        monthKeys = Self.monthKeys(from: (Array(monthHours.keys) + Array(paidRecords.keys) + monthKeys.suffix(1)).min())
    }

    /// Admin correction of one shift's clock-in/out. A paid month's numbers are frozen, so a
    /// shift in a paid month (or moved into one) can't change until that month is unmarked.
    /// The first edit keeps the employee's original times in originalClockIn/originalClockOut.
    /// Returns an error message, or nil once saved. EditShiftSheet shows it itself.
    func updateShift(_ entry: HistoryEntry, clockIn: Date, clockOut: Date) async -> String? {
        guard clockOut > clockIn else { return "Clock-out must be after clock-in." }
        guard clockOut <= Date() else { return "Clock-out can't be in the future." }
        let affectedMonths = [PayoutRecord.monthKey(for: entry.clockOut), PayoutRecord.monthKey(for: clockOut)]
        if let paid = affectedMonths.compactMap({ paidRecords[$0] }).first {
            return "\(paid.monthTitle) is marked paid. Mark it unpaid before changing its shifts."
        }

        let seconds = Int(clockOut.timeIntervalSince(clockIn))
        let durationFormatted = "\(seconds / 3600)h \((seconds % 3600) / 60)m"
        var data: [String: Any] = [
            "clockIn": Timestamp(date: clockIn),
            "clockOut": Timestamp(date: clockOut),
            "durationMs": Int64(clockOut.timeIntervalSince(clockIn) * 1000),
            "durationFormatted": durationFormatted,
            "editedAt": FieldValue.serverTimestamp(),
            "editedByEmail": Auth.auth().currentUser?.email ?? ""
        ]
        if entry.editedAt == nil {
            data["originalClockIn"] = Timestamp(date: entry.clockIn)
            data["originalClockOut"] = Timestamp(date: entry.clockOut)
        }
        do {
            try await userRef.collection("history").document(entry.id).updateData(data)
        } catch {
            return error.localizedDescription
        }

        let updated = HistoryEntry(
            id: entry.id,
            clockIn: clockIn,
            clockOut: clockOut,
            durationFormatted: durationFormatted,
            report: entry.report,
            editedAt: Date()
        )
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index] = updated
        }
        rebuildTotals()
        return nil
    }

    /// "yyyy-MM" keys from `oldestKey` through the current month, newest first.
    private static func monthKeys(from oldestKey: String?) -> [String] {
        let calendar = PayoutRecord.calendar
        let now = Date()
        let thisMonthKey = PayoutRecord.monthKey(for: now)
        guard let oldestKey, oldestKey < thisMonthKey,
              var month = PayoutRecord.monthStart(forKey: oldestKey)
        else { return [thisMonthKey] }
        var keys: [String] = []
        while PayoutRecord.monthKey(for: month) <= thisMonthKey {
            keys.append(PayoutRecord.monthKey(for: month))
            guard let next = calendar.date(byAdding: .month, value: 1, to: month) else { break }
            month = next
        }
        return keys.reversed()
    }

    /// Paid months as frozen; unpaid months estimated from history and the wage in effect
    /// that month.
    func records(using wages: WageHistory) -> [PayoutRecord] {
        monthKeys.map { record(forMonth: $0, using: wages) }
    }

    func record(forMonth key: String, using wages: WageHistory) -> PayoutRecord {
        if let paid = paidRecords[key] { return paid }
        let wage = wages.wage(forMonth: key)
        return PayoutRecord(
            id: key,
            payType: wage?.payType ?? .hourly,
            rate: wage?.rate,
            hoursWorked: hoursByMonth[key] ?? 0
        )
    }

    /// Freezes `record` with a bonus, deduction and note. Admin-only today. TODO (not
    /// implemented yet): the employee can also mark as paid; see the note on PayoutRecord.
    /// Returns an error message, or nil once saved. MarkPaidSheet shows it itself, since the
    /// screen's alert sits behind the sheet.
    func markPaid(_ record: PayoutRecord, bonus: Double, deduction: Double, note: String) async -> String? {
        guard record.basePay != nil else {
            return "Log this employee's wage before marking a month paid."
        }
        var paid = record
        paid.bonus = bonus
        paid.deduction = deduction
        paid.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        paid.paidAt = Date()

        var data = paid.firestoreData
        data["paidAt"] = FieldValue.serverTimestamp()
        data["paidByEmail"] = Auth.auth().currentUser?.email ?? ""
        do {
            try await userRef.collection("payouts").document(paid.id).setData(data)
            paidRecords[paid.id] = paid
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    func unmarkPaid(_ record: PayoutRecord) async {
        do {
            try await userRef.collection("payouts").document(record.id).delete()
            paidRecords[record.id] = nil
        } catch {
            alertMessage = error.localizedDescription
        }
    }
}
