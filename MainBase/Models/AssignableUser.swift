import Foundation

struct AssignableUser: Identifiable, Hashable {
    var id: String { email }
    let email: String
    let name: String
    let isEmployed: Bool
}
