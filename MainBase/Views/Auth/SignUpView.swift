import SwiftUI

struct SignUpView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authVM: AuthViewModel

    @State private var fullName = ""
    @State private var email = ""
    @State private var company = ""
    @State private var countryDialCode = "+1"
    @State private var phoneNumber = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showPassword = false
    @State private var showConfirmPassword = false
    @State private var termsAccepted = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 20))
                            .foregroundColor(AppColors.text)
                            .padding(8)
                    }
                    Spacer()
                    Text("Create Account")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(AppColors.text)
                    Spacer()
                    Color.clear.frame(width: 40, height: 40)
                }
                .padding(.top, 8)
                .padding(.bottom, 16)

                Text("Join MainBase")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(AppColors.text)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 8)

                Text("Create your account to start managing your tasks")
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 24)

                FormTextField(label: "Full Name", placeholder: "John Doe", text: $fullName)
                    .padding(.bottom, 16)

                FormTextField(
                    label: "Email Address",
                    placeholder: "john.doe@example.com",
                    text: $email,
                    keyboardType: .emailAddress,
                    autocapitalization: .none
                )
                .padding(.bottom, 16)

                FormTextField(label: "Company", placeholder: "Your company name", text: $company)
                    .padding(.bottom, 16)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Phone Number")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppColors.text)
                    HStack(spacing: 8) {
                        Text(countryDialCode)
                            .font(.system(size: 16))
                            .foregroundColor(AppColors.text)
                            .inputFieldStyle()

                        TextField("123 456 7890", text: $phoneNumber)
                            .keyboardType(.phonePad)
                            .inputFieldStyle()
                    }
                }
                .padding(.bottom, 16)

                SecureFormField(
                    label: "Password",
                    placeholder: "Enter your password",
                    text: $password,
                    isVisible: $showPassword
                )
                .padding(.bottom, 16)

                SecureFormField(
                    label: "Confirm Password",
                    placeholder: "Confirm your password",
                    text: $confirmPassword,
                    isVisible: $showConfirmPassword
                )
                .padding(.bottom, 16)

                CheckboxToggle(isOn: $termsAccepted) {
                    (Text("I agree to the ")
                        .foregroundColor(AppColors.text)
                     + Text("Terms & Conditions")
                        .foregroundColor(AppColors.primary)
                        .fontWeight(.medium))
                        .font(.system(size: 16))
                        .multilineTextAlignment(.leading)
                }
                .padding(.bottom, 24)

                Button(action: handleSignUp) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppColors.primaryLight)
                            .frame(height: 50)
                        if authVM.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Sign Up")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .disabled(authVM.isLoading)
                .opacity(authVM.isLoading ? 0.6 : 1)
                .padding(.bottom, 32)

                Button(action: { dismiss() }) {
                    HStack(spacing: 0) {
                        Text("Already have an account? ")
                            .font(.system(size: 16))
                            .foregroundColor(AppColors.textSecondary)
                        Text("Sign In")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(AppColors.primary)
                    }
                }
                .padding(.bottom, 32)
            }
            .padding(.horizontal, 24)
        }
        .background(AppColors.cardBackground.ignoresSafeArea())
        .navigationBarHidden(true)
        .alert(authVM.alertTitle, isPresented: $authVM.showAlert) {
            Button("OK", role: .cancel) {
                if authVM.signUpSuccess {
                    authVM.resetSignUpSuccess()
                }
            }
        } message: {
            Text(authVM.alertMessage)
        }
    }

    private func handleSignUp() {
        authVM.signUp(
            fullName: fullName,
            email: email,
            company: company,
            countryDialCode: countryDialCode,
            phoneNumber: phoneNumber,
            password: password,
            confirmPassword: confirmPassword,
            termsAccepted: termsAccepted
        )
    }
}

#Preview {
    NavigationStack {
        SignUpView()
            .environmentObject(AuthViewModel())
    }
}
