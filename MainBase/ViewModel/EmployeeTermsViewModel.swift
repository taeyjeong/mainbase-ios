import Combine
import FirebaseAuth
import FirebaseFirestore
import Foundation

@MainActor
final class EmployeeTermsViewModel: ObservableObject {
    @Published var terms = EmploymentTerms()
    @Published private(set) var isLoading = true
    @Published private(set) var isSaving = false
    @Published var alertMessage: String?

    private let db = Firestore.firestore()
    private let userId: String

    init(userId: String) {
        self.userId = userId
    }

    private var termsRef: DocumentReference {
        db.collection("users").document(userId).collection("employment").document("terms")
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let snapshot = try await termsRef.getDocument()
            if let data = snapshot.data() {
                terms = EmploymentTerms(data: data)
            }
        } catch {
            alertMessage = "Could not load pay notes and schedule right now."
        }
    }

    func save() async {
        if let invalidDay = Weekday.allCases.first(where: { day in
            guard let workDay = terms.schedule[day], workDay.isWorking else { return false }
            return workDay.endMinutes <= workDay.startMinutes
        }) {
            alertMessage = "\(invalidDay.displayName)'s end time must be after its start time."
            return
        }
        isSaving = true
        defer { isSaving = false }
        var data = terms.firestoreData
        data["updatedAt"] = FieldValue.serverTimestamp()
        data["updatedByEmail"] = Auth.auth().currentUser?.email ?? ""
        do {
            try await termsRef.setData(data)
            alertMessage = "Pay notes and schedule saved."
        } catch {
            alertMessage = error.localizedDescription
        }
    }
}
