import Foundation
import SwiftUI
import Combine
import FirebaseFirestore

@MainActor
final class NotificationViewModel: ObservableObject {
    @Published private(set) var notifications: [WorkNotification] = []
    @Published private(set) var unreadCount: Int = 0

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    func configure(userId: String) {
        listener?.remove()
        let q = db.collection("users").document(userId)
            .collection("notifications")
            .order(by: "createdAt", descending: true)
            .limit(to: 80)

        listener = q.addSnapshotListener { [weak self] snap, _ in
            guard let self, let docs = snap?.documents else { return }
            let items = docs.map { WorkNotification(id: $0.documentID, data: $0.data()) }
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.notifications = items
                self.unreadCount = items.filter { !$0.read }.count
            }
        }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
        notifications = []
        unreadCount = 0
    }

    func markAllRead(userId: String) async {
        let unread = notifications.filter { !$0.read }
        guard !unread.isEmpty else { return }

        notifications = notifications.map {
            var copy = $0; copy.read = true; return copy
        }
        unreadCount = 0

        let batch = db.batch()
        let col = db.collection("users").document(userId).collection("notifications")
        for n in unread {
            batch.updateData(["read": true], forDocument: col.document(n.id))
        }
        try? await batch.commit()
    }
}
