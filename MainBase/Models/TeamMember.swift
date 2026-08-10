import Foundation

struct TeamMember: Identifiable {
    let id: String
    let firstName: String
    let isOnline: Bool
    let emoji: String
    let lastClockOut: Date?
}
