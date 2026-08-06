import Foundation

struct ProjectChatMessage: Identifiable {
    let id: String
    var text: String
    var senderEmail: String
    var createdAt: Date?
    var isPinned: Bool
    /// True for auto-generated activity log entries (task completed, photo added, message
    /// pinned, etc.) rendered in italics inline with the regular chat, rather than a message
    /// someone typed.
    var isSystemEvent: Bool
}
