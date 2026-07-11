import Foundation
import Combine
import FirebaseFirestore
import FirebaseFunctions

@MainActor
final class AdminEmployeesViewModel: ObservableObject {
    @Published private(set) var employees: [EmployeeEntry] = []
    @Published private(set) var isLoading = true
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    func startListening(company: String) {
        listener?.remove()
        guard !company.isEmpty else {
            employees = []
            isLoading = false
            return
        }
        isLoading = true
        listener = db.collection("users")
            .whereField("company", isEqualTo: company)
            .order(by: "name")
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self, let snapshot else { return }
                self.employees = snapshot.documents.map { doc in
                    let data = doc.data()
                    return EmployeeEntry(
                        id: doc.documentID,
                        name: data["name"] as? String ?? "Unknown",
                        isEmployed: data["isEmployed"] as? Bool ?? false
                    )
                }
                self.isLoading = false
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    func setEmployed(_ isEmployed: Bool, for userId: String) {
        Task {
            do {
                let callable = Functions.functions().httpsCallable("setEmployeeStatus")
                _ = try await callable.call([
                    "targetUserId": userId,
                    "isEmployed": isEmployed
                ])
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    deinit {
        listener?.remove()
    }
}
