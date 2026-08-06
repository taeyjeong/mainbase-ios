import Combine
import FirebaseAuth
import FirebaseFirestore
import Foundation

@MainActor
final class ProjectMainsAdminViewModel: ObservableObject {
    @Published private(set) var mains: [ProjectMain] = []
    @Published private(set) var isLoading = true
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    func startListening() {
        guard listener == nil else { return }
        listener = db.collection("projectMains").addSnapshotListener { [weak self] snapshot, _ in
            guard let self, let documents = snapshot?.documents else { return }
            self.mains = documents.map { doc in
                let data = doc.data()
                return ProjectMain(
                    id: doc.documentID,
                    name: data["name"] as? String ?? "",
                    colorHex: data["colorHex"] as? String ?? "#999999"
                )
            }
            self.isLoading = false
        }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    func addMain(name: String, colorHex: String) async -> ProjectActionResult {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return .failure("Name is required.") }
        do {
            try await db.collection("projectMains").addDocument(data: [
                "name": trimmedName,
                "colorHex": colorHex,
                "createdAt": FieldValue.serverTimestamp(),
                "createdByEmail": Auth.auth().currentUser?.email ?? "",
            ])
            return .ok
        } catch {
            return .failure("Could not add Main right now.")
        }
    }

    deinit {
        listener?.remove()
    }
}
