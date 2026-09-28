import Combine
import FirebaseAuth
import FirebaseFirestore
import Foundation

@MainActor
final class EmployeePayoutsViewModel: ObservableObject {
    static let monthsShown = 6

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

    init(userId: String) {
        self.userId = userId
    }

    private var userRef: DocumentReference {
        db.collection("users").document(userId)
    }

    /// Keys of the months shown, newest first, starting with the current Pacific month.
    private var monthKeys: [String] {
        let calendar = PayoutRecord.calendar
        let thisMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) ?? Date()
        return (0..<Self.monthsShown).compactMap { offset in
            calendar.date(byAdding: .month, value: -offset, to: thisMonth).map(PayoutRecord.monthKey(for:))
        }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        guard let oldestKey = monthKeys.last, let oldestStart = PayoutRecord.monthStart(forKey: oldestKey) else { return }
        do {
            async let historySnapshot = userRef.collection("history")
                .whereField("clockOut", isGreaterThanOrEqualTo: Timestamp(date: oldestStart))
                .getDocuments()
            async let payoutsSnapshot = userRef.collection("payouts").getDocuments()

            var monthHours: [String: Double] = [:]
            var dayEntries: [String: [HistoryEntry]] = [:]
            for doc in try await historySnapshot.documents {
                let data = doc.data()
                guard let clockIn = (data["clockIn"] as? Timestamp)?.dateValue(),
                      let clockOut = (data["clockOut"] as? Timestamp)?.dateValue()
                else { continue }
                let entry = HistoryEntry(
                    id: doc.documentID,
                    clockIn: clockIn,
                    clockOut: clockOut,
                    durationFormatted: data["durationFormatted"] as? String ?? "",
                    report: data["report"] as? String ?? ""
                )
                monthHours[PayoutRecord.monthKey(for: clockOut), default: 0] += entry.hours
                dayEntries[PayoutRecord.dayKey(for: clockOut), default: []].append(entry)
            }
            hoursByMonth = monthHours
            entriesByDay = dayEntries.mapValues { $0.sorted { $0.clockIn < $1.clockIn } }

            paidRecords = Dictionary(uniqueKeysWithValues: try await payoutsSnapshot.documents.map { doc in
                (doc.documentID, PayoutRecord(id: doc.documentID, data: doc.data()))
            })
        } catch {
            alertMessage = "Could not load payouts right now."
        }
    }

    /// Paid months as frozen; unpaid months estimated from history and the wage in effect
    /// that month.
    func records(using wages: WageHistory) -> [PayoutRecord] {
        monthKeys.map { key in
            if let paid = paidRecords[key] { return paid }
            let wage = wages.wage(forMonth: key)
            return PayoutRecord(
                id: key,
                payType: wage?.payType ?? .hourly,
                rate: wage?.rate,
                hoursWorked: hoursByMonth[key] ?? 0
            )
        }
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
