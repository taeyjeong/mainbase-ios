import Foundation

struct ProjectMain: Identifiable, Hashable {
    let id: String
    var name: String
    var colorHex: String
}

extension ProjectMain {
    init(id: String, data: [String: Any]) {
        self.init(
            id: id,
            name: data["name"] as? String ?? "",
            colorHex: data["colorHex"] as? String ?? "#999999"
        )
    }
}
