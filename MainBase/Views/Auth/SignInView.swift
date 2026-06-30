import SwiftUI

struct SignInView: View {
    @EnvironmentObject private var authVM: AuthViewModel

    @State private var email = ""
    @State private var password = ""
    @State private var rememberMe = false
    @State private var showPassword = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                AppLogoView()
                    .padding(.top, 48)
                    .padding(.bottom, 48)

                Text("Welcome Back!")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(AppColors.text)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 8)

                Text("Sign in to continue managing your tasks.")
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 32)

                FormTextField(
                    label: "Email Address",
                    placeholder: "john.doe@example.com",
                    text: $email,
                    keyboardType: .emailAddress,
                    autocapitalization: .none
                )
                .padding(.bottom, 16)

                SecureFormField(
                    label: "Password",
                    placeholder: "Enter your password",
                    text: $password,
                    isVisible: $showPassword
                )
                .padding(.bottom, 16)

                HStack {
                    CheckboxToggle(isOn: $rememberMe) {
                        Text("Remember Me")
                            .font(.system(size: 16))
                            .foregroundColor(AppColors.text)
                    }
                    Spacer()
                    Button("Forgot Password?") {
                        authVM.sendPasswordReset(email: email)
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppColors.primary)
                }
                .padding(.bottom, 24)

                Button(action: { authVM.signIn(email: email, password: password, rememberMe: rememberMe) }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppColors.primaryLight)
                            .frame(height: 50)
                        if authVM.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Sign In")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .disabled(authVM.isLoading)
                .opacity(authVM.isLoading ? 0.6 : 1)
                .padding(.bottom, 32)

                NavigationLink(destination: SignUpView()) {
                    HStack(spacing: 0) {
                        Text("Don't have an account? ")
                            .font(.system(size: 16))
                            .foregroundColor(AppColors.textSecondary)
                        Text("Sign Up")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(AppColors.primary)
                    }
                }
                .padding(.bottom, 32)
            }
            .padding(.horizontal, 24)
        }
        .background(AppColors.cardBackground.ignoresSafeArea())
        .alert(authVM.alertTitle, isPresented: $authVM.showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(authVM.alertMessage)
        }
        .navigationBarHidden(true)
        .onAppear {
            rememberMe = authVM.savedRememberMe
        }
    }
}

#Preview {
    NavigationStack {
        SignInView()
            .environmentObject(AuthViewModel())
    }
}
