import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class TeamMemberViewModel: ObservableObject {
    @Published private(set) var members: [TeamMember] = []
    @Published private(set) var isLoading = true

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    func startListening() {
        guard let uid = Auth.auth().currentUser?.uid else {
            isLoading = false
            return
        }
        listener = db.collection("users")
            .order(by: "name")
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self, let snapshot else { return }
                let docs = snapshot.documents
                let currentCompany = docs.first(where: { $0.documentID == uid })?.data()["company"] as? String ?? ""
                let mapped = docs.compactMap { doc -> TeamMember? in
                    let data = doc.data()
                    let company = data["company"] as? String ?? ""
                    let isEmployed = data["isEmployed"] as? Bool ?? false
                    guard company == currentCompany, isEmployed else { return nil }
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
