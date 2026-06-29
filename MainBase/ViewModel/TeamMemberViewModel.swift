import Foundation
import Combine
import FirebaseFirestore

@MainActor
final class TeamMemberViewModel: ObservableObject {
    @Published private(set) var members: [TeamMember] = []
    @Published private(set) var isLoading = true

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    func startListening() {
        listener = db.collection("users")
            .order(by: "name")
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self, let snapshot else { return }
                let mapped = snapshot.documents.map { doc -> TeamMember in
                    let data = doc.data()
                    let fullName = data["name"] as? String ?? ""
                    let firstName = fullName.components(separatedBy: " ").first.flatMap { $0.isEmpty ? nil : $0 } ?? "Unknown"
                    return TeamMember(
                        id: doc.documentID,
                        firstName: firstName,
                        isOnline: data["isOnline"] as? Bool ?? false
                    )
                }
                self.members = mapped
                self.isLoading = false
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    deinit {
        listener?.remove()
    }
}
