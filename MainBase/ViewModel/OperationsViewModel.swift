import Combine
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import Foundation

@MainActor
final class OperationsViewModel: ObservableObject {
    @Published private(set) var items: [OperationItem] = []
    @Published private(set) var isLoading = true

    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    private var listener: ListenerRegistration?

    private var currentUserEmail: String {
        Auth.auth().currentUser?.email ?? ""
    }

    func startListening() {
        guard listener == nil else { return }
        listener = db.collection("operationsItems")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self, let documents = snapshot?.documents else { return }
                self.items = documents.compactMap { doc in
                    let data = doc.data()
                    guard let kindRaw = data["kind"] as? String, let kind = OperationItemKind(rawValue: kindRaw) else { return nil }
                    return OperationItem(
                        id: doc.documentID,
                        title: data["title"] as? String ?? "",
                        kind: kind,
                        urlString: data["urlString"] as? String ?? "",
                        createdByEmail: data["createdByEmail"] as? String ?? "",
                        createdAt: (data["createdAt"] as? Timestamp)?.dateValue()
                    )
                }
                self.isLoading = false
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    func addLink(urlString: String) async -> ProjectActionResult {
        let trimmed = urlString.trimmingCharacters(in: .whitespaces)
        guard let url = URL(string: trimmed), url.scheme?.hasPrefix("http") == true else {
            return .failure("Please enter a valid link.")
        }
        do {
            try await db.collection("operationsItems").addDocument(data: [
                "title": url.host ?? trimmed,
                "kind": OperationItemKind.link.rawValue,
                "urlString": trimmed,
                "createdByEmail": currentUserEmail,
                "createdAt": FieldValue.serverTimestamp(),
            ])
            return .ok
        } catch {
            return .failure("Could not add link right now.")
        }
    }

    func addFile(data: Data, fileName: String, kind: OperationItemKind) async -> ProjectActionResult {
        do {
            let ref = storage.reference().child("operations/\(UUID().uuidString)/\(fileName)")
            _ = try await ref.putDataAsync(data, metadata: nil)
            let url = try await ref.downloadURL()
            try await db.collection("operationsItems").addDocument(data: [
                "title": fileName,
                "kind": kind.rawValue,
                "urlString": url.absoluteString,
                "createdByEmail": currentUserEmail,
                "createdAt": FieldValue.serverTimestamp(),
            ])
            return .ok
        } catch {
            return .failure("Could not upload file right now.")
        }
    }

    deinit {
        listener?.remove()
    }
}
