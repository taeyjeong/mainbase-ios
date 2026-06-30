import SwiftUI

struct ProfileSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authVM: AuthViewModel
    @StateObject private var vm = ProfileViewModel()
    @StateObject private var historyVM = HistoryViewModel()

    @State private var showSignOutConfirm = false

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 24) {
                            avatarSection
                            infoCard
                            historySection
                            saveButton
                            signOutButton
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                        .padding(.bottom, 40)
                    }
                }
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.primary)
                }
            }
        }
        .onAppear {
            vm.loadProfile()
            historyVM.startListening()
        }
        .onDisappear { historyVM.stopListening() }
        .alert("Profile", isPresented: $vm.showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.alertMessage)
        }
        .confirmationDialog("Sign out of your account?", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) { authVM.signOut() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var avatarSection: some View {
        VStack(spacing: 12) {
            Circle()
                .fill(AppColors.cardBackground)
                .frame(width: 80, height: 80)
                .overlay(Circle().stroke(AppColors.primary, lineWidth: 2))
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 36))
                        .foregroundColor(AppColors.primary)
                )

            if !vm.profile.name.isEmpty {
                Text(vm.profile.name)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(AppColors.text)
            }

            Text(vm.profile.email)
                .font(.system(size: 14))
                .foregroundColor(AppColors.textSecondary)
        }
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Personal Information")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppColors.text)
                .padding(.bottom, 16)

            fieldRow(label: "Full Name") {
                TextField("Enter your name", text: $vm.profile.name)
                    .inputFieldStyle()
            }

            fieldRow(label: "Email") {
                Text(vm.profile.email.isEmpty ? "—" : vm.profile.email)
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 50)
                    .padding(.horizontal, 16)
                    .background(AppColors.background)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.border, lineWidth: 1))
            }

            Text("Email changes are disabled. Contact support for updates.")
                .font(.system(size: 12))
                .foregroundColor(AppColors.textSecondary)
                .padding(.bottom, 16)

            fieldRow(label: "Company") {
                TextField("Enter company", text: $vm.profile.company)
                    .inputFieldStyle()
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Phone")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.text)
                    TextField("Phone number", text: $vm.profile.phone)
                        .inputFieldStyle()
                        .keyboardType(.phonePad)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Country")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.text)
                    TextField("Country", text: $vm.profile.country)
                        .inputFieldStyle()
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.cardBackground)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColors.border, lineWidth: 1))
        )
    }

    @ViewBuilder
    private func fieldRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppColors.text)
            content()
        }
        .padding(.bottom, 16)
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("History")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppColors.text)
                .padding(.bottom, 16)

            if historyVM.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else if historyVM.sections.isEmpty {
                Text("No clock-out history yet.")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(Array(historyVM.sections.enumerated()), id: \.offset) { index, section in
                    if index > 0 {
                        Divider()
                            .padding(.vertical, 12)
                    }

                    Text(section.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.bottom, 8)

                    ForEach(section.items) { entry in
                        HistoryRow(entry: entry)
                        if entry.id != section.items.last?.id {
                            Divider()
                                .padding(.vertical, 8)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.cardBackground)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColors.border, lineWidth: 1))
        )
    }

    private var saveButton: some View {
        Button(action: { vm.saveProfile() }) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(AppColors.primary)
                    .frame(height: 50)
                if vm.isSaving {
                    ProgressView().tint(.white)
                } else {
                    Text("Save Changes")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
        }
        .disabled(vm.isSaving)
        .opacity(vm.isSaving ? 0.7 : 1)
    }

    private var signOutButton: some View {
        Button {
            showSignOutConfirm = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                Text("Sign Out")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.red)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(AppColors.cardBackground)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.red.opacity(0.3), lineWidth: 1))
            )
        }
    }
}

private struct HistoryRow: View {
    let entry: HistoryEntry

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(Self.dateFormatter.string(from: entry.clockOut))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppColors.text)
                Spacer()
                Text(entry.durationFormatted)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppColors.primary)
            }

            if !entry.report.isEmpty {
                Text(entry.report)
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    ProfileSheetView()
        .environmentObject(AuthViewModel())
}
