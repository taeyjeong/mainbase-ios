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
    /// Choices for a report's project Main (EditReportSheet) and its tag on each row.
    @Published private(set) var projectMains: [ProjectMain] = []

    private let db = Firestore.firestore()
    private var usersListener: ListenerRegistration?
    private var reportListeners: [String: ListenerRegistration] = [:]
    private var reportsByUser: [String: [Report]] = [:]
    private var userNames: [String: String] = [:]
    private var userEmojis: [String: String] = [:]
    private var reportChatListener: ListenerRegistration?
    private var projectMainsListener: ListenerRegistration?

    private var currentUserId: String? { Auth.auth().currentUser?.uid }

    private var currentUserName: String {
        guard let currentUserId else { return "Unknown" }
        return userNames[currentUserId] ?? "Unknown"
    }

    func startListening() {
        guard usersListener == nil else { return }
        isLoading = true
        projectMainsListener = db.collection("projectMains").addSnapshotListener { [weak self] snapshot, _ in
            guard let self, let documents = snapshot?.documents else { return }
            Task { @MainActor [weak self] in
                self?.projectMains = documents
                    .map { ProjectMain(id: $0.documentID, data: $0.data()) }
                    .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            }
        }
        usersListener = db.collection("users").addSnapshotListener { [weak self] snapshot, _ in
            guard let self, let snapshot else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                let docs = snapshot.documents
                let currentUserIds = Set(docs.map { $0.documentID })

                for doc in docs {
                    let name = doc.data()["name"] as? String ?? "Unknown"
                    let surname = doc.data()["surname"] as? String ?? ""
                    self.userNames[doc.documentID] = formattedDisplayName(name: name, surname: surname)
                    self.userEmojis[doc.documentID] = doc.data()["emoji"] as? String ?? ""
                }

                for userId in self.reportListeners.keys where !currentUserIds.contains(userId) {
                    self.reportListeners[userId]?.remove()
                    self.reportListeners.removeValue(forKey: userId)
                    self.reportsByUser.removeValue(forKey: userId)
                    self.userNames.removeValue(forKey: userId)
                    self.userEmojis.removeValue(forKey: userId)
                }

                for doc in docs {
                    let userId = doc.documentID
                    if self.reportListeners[userId] == nil {
                        self.attachReportsListener(userId: userId)
                    } else {
                        let name = self.userNames[userId] ?? "Unknown"
                        let emoji = self.userEmojis[userId] ?? ""
                        self.reportsByUser[userId] = (self.reportsByUser[userId] ?? []).map {
                            Report(
                                id: $0.id,
                                userId: userId,
                                name: name,
                                emoji: emoji,
                                reportText: $0.reportText,
                                timestamp: $0.timestamp,
                                messageCount: $0.messageCount,
                                projectMainId: $0.projectMainId,
                                links: $0.links
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
                let emoji = self.userEmojis[userId] ?? ""
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
                        emoji: emoji,
                        reportText: reportText,
                        timestamp: ts.dateValue(),
                        messageCount: messageCount,
                        projectMainId: data["projectMainId"] as? String,
                        links: ReportLink.list(from: data["links"])
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

    /// The filter is set to the signed-in user, which offers "Summarize this month".
    var isFilteredToCurrentUser: Bool {
        guard let selectedUserId else { return false }
        return selectedUserId == currentUserId
    }

    func canEdit(_ report: Report) -> Bool {
        report.userId == currentUserId
    }

    func projectMain(withId id: String?) -> ProjectMain? {
        guard let id else { return nil }
        return projectMains.first { $0.id == id }
    }

    /// The owner's edit of their own report, of any age: its text, its one project Main (nil
    /// clears it) and its links (`links` are the edit sheet's rows; blank ones are dropped,
    /// and none left removes the field). No edit time is recorded; the date, author and replies stay as they
    /// were. A text change also updates the matching clock-out history entry (same clock-out
    /// time, or its original time if an admin corrected the shift) so History shows the same
    /// text. Returns an error message, or nil once saved.
    func updateReport(_ report: Report, text: String, projectMainId: String?, links: [ReportLinkDraft]) async -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Your report can't be empty." }
        guard canEdit(report) else { return "You can only edit your own reports." }
        guard !links.contains(where: \.isInvalid) else { return "Fix or clear the invalid link." }
        let linkValues = links.compactMap(\.firestoreValue)
        let textChanged = trimmed != report.reportText
        let linksChanged = linkValues != report.links.map(\.firestoreValue)
        guard textChanged || linksChanged || projectMainId != report.projectMainId else { return nil }

        let userRef = db.collection("users").document(report.userId)
        do {
            try await userRef.collection("reports").document(report.id).updateData([
                "reportText": trimmed,
                "projectMainId": projectMainId ?? FieldValue.delete(),
                "links": linkValues.isEmpty ? FieldValue.delete() : linkValues,
            ])
        } catch {
            return "Could not save your report right now."
        }
        guard textChanged else { return nil }

        // Best effort: the report is already saved, so a history mismatch shouldn't fail the edit.
        let timestamp = Timestamp(date: report.timestamp)
        let history = userRef.collection("history")
        var matches = (try? await history.whereField("clockOut", isEqualTo: timestamp).getDocuments())?.documents ?? []
        if matches.isEmpty {
            matches = (try? await history.whereField("originalClockOut", isEqualTo: timestamp).getDocuments())?.documents ?? []
        }
        for doc in matches {
            try? await doc.reference.updateData(["report": trimmed])
        }
        return nil
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
        projectMainsListener?.remove()
        projectMainsListener = nil
        reportListeners.values.forEach { $0.remove() }
        reportListeners.removeAll()
        reportsByUser.removeAll()
        userNames.removeAll()
        userEmojis.removeAll()
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
            // messageCount on the report is incremented server-side by onReportChatMessageCreated;
            // firestore.rules don't let clients write it.
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
