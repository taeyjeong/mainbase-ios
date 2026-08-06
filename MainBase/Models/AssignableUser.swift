import Foundation

struct AssignableUser: Identifiable, Hashable {
    var id: String { email }
    let email: String
    let name: String
    let firstName: String
    let emoji: String
    let isEmployed: Bool
}
