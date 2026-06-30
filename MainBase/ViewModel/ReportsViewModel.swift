import Combine
import Foundation
import FirebaseFirestore

@MainActor
final class ReportsViewModel: ObservableObject {
    @Published private(set) var reports: [Report] = []
    @Published private(set) var isLoading = false
    @Published var selectedUserId: String?

    private let db = Firestore.firestore()
    private var usersListener: ListenerRegistration?
    private var reportListeners: [String: ListenerRegistration] = [:]
    private var reportsByUser: [String: [Report]] = [:]
    private var userNames: [String: String] = [:]

    func startListening() {
        guard usersListener == nil else { return }
        isLoading = true
        usersListener = db.collection("users").addSnapshotListener { [weak self] snapshot, _ in
            guard let self, let snapshot else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                let docs = snapshot.documents
                let currentUserIds = Set(docs.map { $0.documentID })

                for doc in docs {
                    self.userNames[doc.documentID] = doc.data()["name"] as? String ?? "Unknown"
                }

                for userId in self.reportListeners.keys where !currentUserIds.contains(userId) {
                    self.reportListeners[userId]?.remove()
                    self.reportListeners.removeValue(forKey: userId)
                    self.reportsByUser.removeValue(forKey: userId)
                    self.userNames.removeValue(forKey: userId)
                }

                for doc in docs {
                    let userId = doc.documentID
                    if self.reportListeners[userId] == nil {
                        self.attachReportsListener(userId: userId)
                    } else {
                        let name = self.userNames[userId] ?? "Unknown"
                        self.reportsByUser[userId] = (self.reportsByUser[userId] ?? []).map {
                            Report(
                                id: $0.id,
                                userId: userId,
                                name: name,
                                reportText: $0.reportText,
                                timestamp: $0.timestamp
                            )
                        }
                        self.rebuild()
                    }
                }

                self.isLoading = false
            }
        }
    }

    private func attachReportsListener(userId: String) {
        let ref = db.collection("users").document(userId).collection("reports")
        reportListeners[userId] = ref.addSnapshotListener { [weak self] snapshot, _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                let name = self.userNames[userId] ?? "Unknown"
                let entries = (snapshot?.documents ?? []).compactMap { doc -> Report? in
                    let data = doc.data()
                    guard let ts = data["timestamp"] as? Timestamp else { return nil }
                    let reportText = data["reportText"] as? String ?? ""
                    guard !reportText.isEmpty else { return nil }
                    return Report(
                        id: doc.documentID,
                        userId: userId,
                        name: name,
                        reportText: reportText,
                        timestamp: ts.dateValue()
                    )
                }
                self.reportsByUser[userId] = entries
                self.rebuild()
            }
        }
    }

    var availablePeople: [(id: String, name: String)] {
        userNames
            .map { (id: $0.key, name: $0.value) }
            .filter { id, _ in !(reportsByUser[id]?.isEmpty ?? true) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var filteredReports: [Report] {
        guard let selectedUserId else { return reports }
        return reports.filter { $0.userId == selectedUserId }
    }

    var reportSections: [MonthSection<Report>] {
        MonthGrouping.group(filteredReports) { $0.timestamp }
    }

    private func rebuild() {
        reports = reportsByUser.values.flatMap { $0 }.sorted { $0.timestamp > $1.timestamp }
    }

    func stopListening() {
        usersListener?.remove()
        usersListener = nil
        reportListeners.values.forEach { $0.remove() }
        reportListeners.removeAll()
        reportsByUser.removeAll()
        userNames.removeAll()
        reports = []
        isLoading = false
    }
}
