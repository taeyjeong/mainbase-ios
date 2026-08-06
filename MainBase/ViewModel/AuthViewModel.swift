import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class AuthViewModel: ObservableObject {
    private static let rememberMeKey = "remember_me"

    @Published private(set) var isSignedIn = false
    @Published private(set) var currentUserId: String?
    @Published var isLoading = false
    @Published var alertTitle = "Error"
    @Published var alertMessage = ""
    @Published var showAlert = false
    @Published var signUpSuccess = false

    private var authListener: AuthStateDidChangeListenerHandle?
    private var isFirstAuthChange = true

    init() {
        startListening()
    }

    deinit {
        if let authListener {
            Auth.auth().removeStateDidChangeListener(authListener)
        }
    }

    var savedRememberMe: Bool {
        UserDefaults.standard.string(forKey: Self.rememberMeKey) == "true"
    }

    func startListening() {
        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor [weak self] in
                guard let self else { return }

                let isFirstLoad = self.isFirstAuthChange
                self.isFirstAuthChange = false

                if user != nil, isFirstLoad {
                    let remember = UserDefaults.standard.string(forKey: Self.rememberMeKey)
                    if remember == "false" {
                        UserDefaults.standard.removeObject(forKey: Self.rememberMeKey)
                        try? Auth.auth().signOut()
                        self.isSignedIn = false
                        self.currentUserId = nil
                        return
                    }
                }

                self.isSignedIn = user != nil
                self.currentUserId = user?.uid
            }
        }
    }

    func signIn(email: String, password: String, rememberMe: Bool) {
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmedEmail.isEmpty, !password.isEmpty else {
            showError("Please enter both email and password")
            return
        }

        UserDefaults.standard.set(rememberMe ? "true" : "false", forKey: Self.rememberMeKey)

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
        countryDialCode: String,
        phoneNumber: String,
        password: String,
        confirmPassword: String,
        termsAccepted: Bool
    ) {
        let trimmedName = fullName.trimmingCharacters(in: .whitespaces)
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces).lowercased()
        let trimmedCompany = company.trimmingCharacters(in: .whitespaces)
        let trimmedPhone = phoneNumber.trimmingCharacters(in: .whitespaces)
        let trimmedDialCode = countryDialCode.trimmingCharacters(in: .whitespaces)
        let fullPhone = trimmedDialCode.isEmpty ? trimmedPhone : "\(trimmedDialCode) \(trimmedPhone)"

        if trimmedName.isEmpty { showError("Please enter your name"); return }
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

                guard let user = result?.user else { return }

                let changeRequest = user.createProfileChangeRequest()
                changeRequest.displayName = trimmedName
                changeRequest.commitChanges(completion: nil)

                let db = Firestore.firestore()
                db.collection("users").document(user.uid).setData([
                    "name": trimmedName,
                    "email": trimmedEmail,
                    "company": trimmedCompany,
                    "phone": fullPhone,
                    "country": "",
                    "isOnline": false,
                    "currentTask": "",
                    "taeList": [],
                    "admin": false,
                    "isEmployed": true,
                    "createdAt": Timestamp(date: Date())
                ]) { firestoreError in
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        if let firestoreError {
                            self.showError(firestoreError.localizedDescription)
                            return
                        }
                        self.signUpSuccess = true
                        self.alertTitle = "Success"
                        self.alertMessage = "Account created successfully!"
                        self.showAlert = true
                    }
                }
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
