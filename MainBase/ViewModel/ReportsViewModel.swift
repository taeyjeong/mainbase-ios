import Combine
import Foundation
import FirebaseAuth
import FirebaseFirestore

struct ReportActionResult {
    let success: Bool
    let error: String?

    static let ok = ReportActionResult(success: true, error: nil)
    static func failure(_ message: String) -> ReportActionResult {
        ReportActionResult(success: false, error: message)
    }
}

@MainActor
final class ReportsViewModel: ObservableObject {
    @Published private(set) var reports: [Report] = []
    @Published private(set) var isLoading = false
    @Published var selectedUserId: String?
    @Published var selectedMonth: Date = MonthGrouping.startOfMonth(for: Date())
    @Published private(set) var currentReportChatMessages: [ReportChatMessage] = []

    private let db = Firestore.firestore()
    private var usersListener: ListenerRegistration?
    private var reportListeners: [String: ListenerRegistration] = [:]
    private var reportsByUser: [String: [Report]] = [:]
    private var userNames: [String: String] = [:]
    private var reportChatListener: ListenerRegistration?

    private var currentUserId: String? { Auth.auth().currentUser?.uid }

    private var currentUserName: String {
        guard let currentUserId else { return "Unknown" }
        return userNames[currentUserId] ?? "Unknown"
    }

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
                                timestamp: $0.timestamp,
                                messageCount: $0.messageCount
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
                    let messageCount = data["messageCount"] as? Int ?? 0
                    return Report(
                        id: doc.documentID,
                        userId: userId,
                        name: name,
                        reportText: reportText,
                        timestamp: ts.dateValue(),
                        messageCount: messageCount
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

    var selectedMonthTitle: String {
        MonthGrouping.monthTitle(for: selectedMonth)
    }

    var reportsForSelectedMonth: [Report] {
        let calendar = Calendar.current
        return filteredReports
            .filter { calendar.isDate($0.timestamp, equalTo: selectedMonth, toGranularity: .month) }
            .sorted { $0.timestamp > $1.timestamp }
    }

    var canGoToNextMonth: Bool {
        let calendar = Calendar.current
        return !calendar.isDate(selectedMonth, equalTo: Date(), toGranularity: .month)
    }

    var canGoToPreviousMonth: Bool {
        guard let earliest = filteredReports.map(\.timestamp).min() else { return false }
        let earliestMonth = MonthGrouping.startOfMonth(for: earliest)
        return selectedMonth > earliestMonth
    }

    func goToPreviousMonth() {
        guard canGoToPreviousMonth,
              let previous = Calendar.current.date(byAdding: .month, value: -1, to: selectedMonth) else { return }
        selectedMonth = MonthGrouping.startOfMonth(for: previous)
    }

    func goToNextMonth() {
        guard canGoToNextMonth,
              let next = Calendar.current.date(byAdding: .month, value: 1, to: selectedMonth) else { return }
        selectedMonth = MonthGrouping.startOfMonth(for: next)
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

    // MARK: - Chat

    /// A report's chatroom has no Firestore data of its own until the first message is sent —
    /// opening the sheet just attaches a listener to a subcollection that may not exist yet.
    func startReportChatListener(report: Report) {
        stopReportChatListener()
        reportChatListener = db.collection("users").document(report.userId)
            .collection("reports").document(report.id)
            .collection("chatMessages")
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self, let documents = snapshot?.documents else { return }
                self.currentReportChatMessages = documents.map { doc in
                    let data = doc.data()
                    return ReportChatMessage(
                        id: doc.documentID,
                        text: data["text"] as? String ?? "",
                        senderId: data["senderId"] as? String ?? "",
                        senderName: data["senderName"] as? String ?? "Unknown",
                        createdAt: (data["createdAt"] as? Timestamp)?.dateValue()
                    )
                }
            }
    }

    func stopReportChatListener() {
        reportChatListener?.remove()
        reportChatListener = nil
        currentReportChatMessages = []
    }

    func sendReportChatMessage(_ text: String, on report: Report) async -> ReportActionResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failure("Message can't be empty.") }
        guard let currentUserId else { return .failure("You need to be signed in to chat.") }
        do {
            try await db.collection("users").document(report.userId)
                .collection("reports").document(report.id)
                .collection("chatMessages").addDocument(data: [
                    "text": trimmed,
                    "senderId": currentUserId,
                    "senderName": currentUserName,
                    "createdAt": FieldValue.serverTimestamp(),
                ])
            return .ok
        } catch {
            return .failure("Could not send message right now.")
        }
    }
}
