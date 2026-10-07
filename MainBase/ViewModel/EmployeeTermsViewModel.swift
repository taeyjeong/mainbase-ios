import Combine
import FirebaseAuth
import FirebaseFirestore
import Foundation

@MainActor
final class EmployeeTermsViewModel: ObservableObject {
    @Published var terms = EmploymentTerms()
    @Published private(set) var isLoading = true
    /// Whether an admin has ever saved terms; until then `terms` holds the editor defaults.
    @Published private(set) var hasSavedTerms = false
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
                hasSavedTerms = true
            }
        } catch {
            alertMessage = "Could not load pay notes and schedule right now."
        }
    }

    func save() async {
        if let invalidDay = EmploymentTerms.invalidDay(in: terms.schedule) {
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
            hasSavedTerms = true
            alertMessage = "Pay notes and schedule saved."
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    /// The employee's own edit (EditMyScheduleSheet). Writes only the schedule and its time
    /// zone, merged into the terms doc so the admin's pay notes are untouched; firestore.rules
    /// limits owners to these fields. Returns an error message, or nil once saved.
    func saveSchedule(_ schedule: [Weekday: WorkDay], timeZoneId: String) async -> String? {
        if let invalidDay = EmploymentTerms.invalidDay(in: schedule) {
            return "\(invalidDay.displayName)'s end time must be after its start time."
        }
        isSaving = true
        defer { isSaving = false }
        var updated = terms
        updated.schedule = schedule
        updated.timeZoneId = timeZoneId
        do {
            try await termsRef.setData([
                "schedule": updated.firestoreData["schedule"] ?? [:],
                "timeZone": updated.timeZoneId,
                "updatedAt": FieldValue.serverTimestamp(),
                "updatedByEmail": Auth.auth().currentUser?.email ?? "",
            ], merge: true)
            terms = updated
            hasSavedTerms = true
            return nil
        } catch {
            return "Could not save your schedule right now."
        }
    }
}
