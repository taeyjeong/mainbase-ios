import Combine
import Foundation
import FirebaseAuth
import FirebaseFirestore

/// The signed-in user's saved Gemini monthly reports (users/{uid}/monthlySummaries), newest
/// month first, for MonthlyReportsView.
@MainActor
final class SavedSummariesViewModel: ObservableObject {
    @Published private(set) var summaries: [MonthlySummary] = []
    @Published private(set) var isLoading = false

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    func startListening() {
        guard listener == nil, let uid = Auth.auth().currentUser?.uid else { return }
        isLoading = true
        listener = db.collection("users").document(uid).collection("monthlySummaries")
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self else { return }
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.summaries = (snapshot?.documents ?? []).compactMap { doc -> MonthlySummary? in
                        let data = doc.data()
                        guard let month = (data["month"] as? Timestamp)?.dateValue() else { return nil }
                        return MonthlySummary(
                            id: doc.documentID,
                            month: month,
                            monthTitle: data["monthTitle"] as? String ?? MonthGrouping.monthTitle(for: month),
                            reportText: data["reportText"] as? String ?? "",
                            // Nil only briefly, while a just-saved doc waits on its server timestamp.
                            createdAt: (data["createdAt"] as? Timestamp)?.dateValue()
                        )
                    }
                    .sorted {
                        $0.month != $1.month
                            ? $0.month > $1.month
                            : ($0.createdAt ?? .distantFuture) > ($1.createdAt ?? .distantFuture)
                    }
                    self.isLoading = false
                }
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
        summaries = []
        isLoading = false
    }
}
