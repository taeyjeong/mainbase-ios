import Combine
import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class HistoryViewModel: ObservableObject {
    @Published private(set) var sections: [MonthSection<HistoryEntry>] = []
    @Published private(set) var isLoading = false

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    func startListening() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        guard listener == nil else { return }

        isLoading = true
        listener = db.collection("users").document(uid).collection("history")
            .order(by: "clockOut", descending: true)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self else { return }
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    let entries = (snapshot?.documents ?? []).compactMap { doc -> HistoryEntry? in
                        let data = doc.data()
                        guard
                            let clockIn = (data["clockIn"] as? Timestamp)?.dateValue(),
                            let clockOut = (data["clockOut"] as? Timestamp)?.dateValue()
                        else { return nil }
                        return HistoryEntry(
                            id: doc.documentID,
                            clockIn: clockIn,
                            clockOut: clockOut,
                            durationFormatted: data["durationFormatted"] as? String ?? "",
                            report: data["report"] as? String ?? ""
                        )
                    }
                    self.sections = MonthGrouping.group(entries) { $0.clockOut }
                    self.isLoading = false
                }
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
        sections = []
        isLoading = false
    }
}
