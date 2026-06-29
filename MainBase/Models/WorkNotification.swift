import Foundation
import FirebaseFirestore

struct WorkNotification: Identifiable {
    let id: String
    let type: String
    let title: String
    let body: String
    var read: Bool
    let createdAt: Date
    let action: String?
    let actorName: String?
    let actorUserId: String?

    var isClockIn: Bool { action == "clock_in" }

    init(id: String, data: [String: Any]) {
        self.id = id
        self.type = data["type"] as? String ?? "general"
        self.title = data["title"] as? String ?? "Notification"
        self.body = data["body"] as? String ?? ""
        self.read = data["read"] as? Bool ?? false
        self.createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        self.action = data["action"] as? String
        self.actorName = data["actorName"] as? String
        self.actorUserId = data["actorUserId"] as? String
    }
}
