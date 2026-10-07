import Combine
import FirebaseAuth
import FirebaseFirestore
import Foundation

@MainActor
final class WageHistoryViewModel: ObservableObject {
    @Published private(set) var history = WageHistory([])
    @Published private(set) var isLoading = true
    @Published private(set) var isSaving = false
    @Published var alertMessage: String?

    private let db = Firestore.firestore()
    private let userId: String

    init(userId: String) {
        self.userId = userId
    }

    private var userRef: DocumentReference {
        db.collection("users").document(userId)
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let snapshot = try await userRef.collection("wageHistory").getDocuments()
            history = WageHistory(snapshot.documents.compactMap { WageChange(id: $0.documentID, data: $0.data()) })
            if history.isEmpty {
                await migrateLegacyWage()
            }
        } catch {
            alertMessage = "Could not load wage history right now."
        }
    }

    /// Before the wage log existed, pay was a single payType/payRate on employment/terms. Log
    /// that as the first wage so existing employees keep their pay.
    private func migrateLegacyWage() async {
        guard let data = try? await userRef.collection("employment").document("terms").getDocument().data(),
              let payType = (data["payType"] as? String).flatMap(PayType.init(rawValue:)),
              let rate = (data["payRate"] as? NSNumber)?.doubleValue, rate > 0
        else { return }
        let firstWage = WageChange(
            id: history.effectiveMonth(),
            payType: payType,
            rate: rate,
            currency: .usd,
            changedAt: (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date(),
            changedByEmail: data["updatedByEmail"] as? String ?? ""
        )
        try? await userRef.collection("wageHistory").document(firstWage.id).setData(firstWage.firestoreData)
        history = WageHistory([firstWage])
    }

    /// Logs a new wage starting per WageHistory's rules. Returns true if it was saved.
    func logNewWage(payType: PayType, rate: Double?, currency: PayCurrency) async -> Bool {
        guard let rate, rate > 0 else {
            alertMessage = "Enter the new \(payType.rateLabel.lowercased())."
            return false
        }
        let now = Date()
        let latest = history.upcoming(now: now) ?? history.current(now: now)
        if let latest, latest.payType == payType, latest.rate == rate, latest.currency == currency {
            alertMessage = "That's already the wage from \(latest.effectiveDateText)."
            return false
        }

        let change = WageChange(
            id: history.effectiveMonth(forChangeAt: now),
            payType: payType,
            rate: rate,
            currency: currency,
            changedAt: now,
            changedByEmail: Auth.auth().currentUser?.email ?? ""
        )
        isSaving = true
        defer { isSaving = false }
        do {
            try await userRef.collection("wageHistory").document(change.id).setData(change.firestoreData)
            history = WageHistory(history.changes.filter { $0.id != change.id } + [change])
            return true
        } catch {
            alertMessage = error.localizedDescription
            return false
        }
    }

    /// Removes a change that hasn't started yet. Changes already in effect stay in the log.
    func cancelUpcoming(_ change: WageChange) async {
        guard change.id > PayoutRecord.monthKey(for: Date()) else { return }
        do {
            try await userRef.collection("wageHistory").document(change.id).delete()
            history = WageHistory(history.changes.filter { $0.id != change.id })
        } catch {
            alertMessage = error.localizedDescription
        }
    }
}
