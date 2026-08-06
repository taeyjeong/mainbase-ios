import Foundation

struct ReportChatMessage: Identifiable {
    let id: String
    let text: String
    let senderId: String
    let senderName: String
    let createdAt: Date?
}
