import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var profile = UserProfile()
    @Published var isLoading = true
    @Published var isSaving = false
    @Published var alertMessage = ""
    @Published var showAlert = false

    private let db = Firestore.firestore()

    func loadProfile() {
        guard let uid = Auth.auth().currentUser?.uid else {
            isLoading = false
            return
        }

        db.collection("users").document(uid).getDocument { [weak self] snapshot, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isLoading = false
                guard let data = snapshot?.data() else { return }
                let fallbackEmail = Auth.auth().currentUser?.email ?? ""
                self.profile = UserProfile(data: data, fallbackEmail: fallbackEmail)
            }
        }
    }

    func saveProfile() {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        let trimmedName = profile.name.trimmingCharacters(in: .whitespaces)
        let trimmedCompany = profile.company.trimmingCharacters(in: .whitespaces)

        guard !trimmedName.isEmpty else {
            alertMessage = "Please enter your full name."
            showAlert = true
            return
        }
        guard !trimmedCompany.isEmpty else {
            alertMessage = "Please enter your company."
            showAlert = true
            return
        }

        isSaving = true
        db.collection("users").document(uid).updateData(profile.firestoreUpdateData) { [weak self] error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isSaving = false
                self.alertMessage = error == nil
                    ? "Profile updated successfully."
                    : error!.localizedDescription
                self.showAlert = true
            }
        }
    }
}
