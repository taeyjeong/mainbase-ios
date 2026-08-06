import Foundation

struct ProjectExpense: Identifiable {
    let id: String
    var name: String
    var type: String
    var amount: Double
    var createdByEmail: String
    var createdAt: Date?
}
