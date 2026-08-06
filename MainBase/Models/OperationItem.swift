import Foundation

enum OperationItemKind: String {
    case link
    case pdf
    case image
}

struct OperationItem: Identifiable {
    let id: String
    var title: String
    var kind: OperationItemKind
    var urlString: String
    var createdByEmail: String
    var createdAt: Date?
}
