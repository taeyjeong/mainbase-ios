import Foundation
import Combine
import FirebaseAuth

@MainActor
final class AuthViewModel: ObservableObject {
    @Published private(set) var isSignedIn = false
    @Published private(set) var currentUserId: String?
    @Published var isLoading = false
    @Published var alertTitle = "Error"
    @Published var alertMessage = ""
    @Published var showAlert = false
    @Published var signUpSuccess = false

    private var authListener: AuthStateDidChangeListenerHandle?

    init() {
        startListening()
    }

    deinit {
        if let authListener {
            Auth.auth().removeStateDidChangeListener(authListener)
        }
    }

    func startListening() {
        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor [weak self] in
                self?.isSignedIn = user != nil
                self?.currentUserId = user?.uid
            }
        }
    }

    func signIn(email: String, password: String) {
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmedEmail.isEmpty, !password.isEmpty else {
            showError("Please enter both email and password")
            return
        }

        isLoading = true
        Auth.auth().signIn(withEmail: trimmedEmail, password: password) { [weak self] _, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isLoading = false
                if let error {
                    self.showError(error.localizedDescription)
                }
            }
        }
    }

    func signUp(
        fullName: String,
        email: String,
        company: String,
        phoneNumber: String,
        password: String,
        confirmPassword: String,
        termsAccepted: Bool
    ) {
        let trimmedName = fullName.trimmingCharacters(in: .whitespaces)
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces).lowercased()
        let trimmedCompany = company.trimmingCharacters(in: .whitespaces)
        let trimmedPhone = phoneNumber.trimmingCharacters(in: .whitespaces)

        if trimmedName.isEmpty { showError("Please enter your full name"); return }
        if trimmedEmail.isEmpty { showError("Please enter your email address"); return }
        if !trimmedEmail.contains("@") || !trimmedEmail.contains(".") {
            showError("Please enter a valid email address"); return
        }
        if trimmedCompany.isEmpty { showError("Please enter your company"); return }
        if trimmedPhone.isEmpty { showError("Please enter your phone number"); return }
        if password.isEmpty { showError("Please enter a password"); return }
        if password.count < 6 { showError("Password must be at least 6 characters"); return }
        if password != confirmPassword { showError("Passwords do not match"); return }
        if !termsAccepted { showError("Please agree to the Terms & Conditions"); return }

        isLoading = true
        Auth.auth().createUser(withEmail: trimmedEmail, password: password) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isLoading = false
                if let error {
                    self.showError(error.localizedDescription)
                    return
                }

                let changeRequest = result?.user.createProfileChangeRequest()
                changeRequest?.displayName = trimmedName
                changeRequest?.commitChanges(completion: nil)

                self.signUpSuccess = true
                self.alertTitle = "Success"
                self.alertMessage = "Account created successfully!"
                self.showAlert = true
            }
        }
    }

    func sendPasswordReset(email: String) {
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmedEmail.isEmpty else {
            showError("Enter your email address above, then tap Forgot Password.")
            return
        }

        Auth.auth().sendPasswordReset(withEmail: trimmedEmail) { [weak self] error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let error {
                    self.showError(error.localizedDescription)
                } else {
                    self.alertTitle = "Error"
                    self.alertMessage = "Password reset email sent to \(trimmedEmail)."
                    self.showAlert = true
                }
            }
        }
    }

    func signOut() {
        try? Auth.auth().signOut()
    }

    func resetSignUpSuccess() {
        signUpSuccess = false
    }

    private func showError(_ message: String) {
        alertTitle = "Error"
        alertMessage = message
        signUpSuccess = false
        showAlert = true
    }
}
