import Foundation

struct Report: Identifiable {
    let id: String
    let userId: String
    let name: String
    let reportText: String
    let timestamp: Date
    let messageCount: Int
}
