import SwiftUI

struct ProfileSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authVM: AuthViewModel
    @StateObject private var vm = ProfileViewModel()
    @StateObject private var historyVM = HistoryViewModel()
    @StateObject private var adminVM = AdminEmployeesViewModel()

    @State private var showSignOutConfirm = false
    @State private var selectedHistoryUserId: String?
    @State private var isEditingEmoji = false
    @State private var showFlowMap = false
    @AppStorage("appearancePreference") private var appearancePreference = AppearancePreference.system.rawValue

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
                            appearanceSection
                            flowMapButton
                            if vm.profile.admin {
                                clockNotificationSection
                                adminSection
                                ManageProjectMainsView()
                            }
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
        .onDisappear {
            historyVM.stopListening()
            adminVM.stopListening()
        }
        .onChange(of: vm.isLoading) { _, isLoading in
            guard !isLoading, vm.profile.admin else { return }
            adminVM.startListening(company: vm.profile.company)
        }
        .onChange(of: selectedHistoryUserId) { _, userId in
            historyVM.startListening(userId: userId)
        }
        .alert("Profile", isPresented: $vm.showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.alertMessage)
        }
        .alert("Employees", isPresented: Binding(
            get: { adminVM.errorMessage != nil },
            set: { if !$0 { adminVM.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(adminVM.errorMessage ?? "")
        }
        .confirmationDialog("Sign out of your account?", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) { authVM.signOut() }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showFlowMap) {
            AppFlowMapView()
        }
    }

    private var avatarSection: some View {
        VStack(spacing: 12) {
            Button {
                isEditingEmoji = true
            } label: {
                ZStack(alignment: .bottomTrailing) {
                    Circle()
                        .fill(AppColors.cardBackground)
                        .frame(width: 80, height: 80)
                        .overlay(Circle().stroke(AppColors.primary, lineWidth: 2))
                        .overlay(
                            Group {
                                if vm.profile.emoji.isEmpty {
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 36))
                                        .foregroundColor(AppColors.primary)
                                } else {
                                    Text(vm.profile.emoji)
                                        .font(.system(size: 40))
                                }
                            }
                        )
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(AppColors.primary)
                        .background(Circle().fill(AppColors.cardBackground))
                }
            }
            .buttonStyle(.plain)

            let fullName = [vm.profile.name, vm.profile.surname]
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            if !fullName.isEmpty {
                Text(fullName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(AppColors.text)
            }

            Text(vm.profile.email)
                .font(.system(size: 14))
                .foregroundColor(AppColors.textSecondary)
        }
        .alert("Choose an emoji", isPresented: $isEditingEmoji) {
            TextField("Emoji", text: $vm.profile.emoji)
                .onChange(of: vm.profile.emoji) { _, newValue in
                    vm.profile.emoji = String(newValue.suffix(1))
                }
            Button("Done") {}
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Tap the field and switch to your emoji keyboard.")
        }
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Personal Information")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppColors.text)
                .padding(.bottom, 16)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Name")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.text)
                    TextField("Enter your name", text: $vm.profile.name)
                        .inputFieldStyle()
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Surname")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.text)
                    TextField("Enter your surname", text: $vm.profile.surname)
                        .inputFieldStyle()
                }
            }
            .padding(.bottom, 16)

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

            fieldRow(label: "Phone") {
                PhoneNumberField(fullPhone: $vm.profile.phone)
            }

            fieldRow(label: "Country") {
                CountryDropdown(selectedCountry: $vm.profile.country, placeholder: "Select country")
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

    private var flowMapButton: some View {
        Button {
            showFlowMap = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "map")
                    .font(.system(size: 18))
                    .foregroundColor(AppColors.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("App Flow Map")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.text)
                    Text("See how every screen connects")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppColors.cardBackground)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColors.border, lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Appearance")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppColors.text)

            Picker("Appearance", selection: $appearancePreference) {
                Text("System").tag(AppearancePreference.system.rawValue)
                Text("Light").tag(AppearancePreference.light.rawValue)
                Text("Dark").tag(AppearancePreference.dark.rawValue)
            }
            .pickerStyle(.segmented)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.cardBackground)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColors.border, lineWidth: 1))
        )
    }

    private var clockNotificationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Clock Notifications")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppColors.text)

            Picker("Clock Notifications", selection: $vm.profile.clockNotificationPreference) {
                ForEach(ClockNotificationPreference.allCases, id: \.self) { preference in
                    Text(preference.displayName).tag(preference)
                }
            }
            .pickerStyle(.segmented)

            Text("As an admin, choose whether you hear about every coworker clock-in/out, or none at all — regardless of your own clock status.")
                .font(.system(size: 12))
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.cardBackground)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColors.border, lineWidth: 1))
        )
    }

    private var adminSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Employees")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppColors.text)
                .padding(.bottom, 16)

            if adminVM.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else if adminVM.employees.isEmpty {
                Text("No employees found.")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textSecondary)
            } else {
                ForEach(Array(adminVM.employees.enumerated()), id: \.element.id) { index, employee in
                    if index > 0 {
                        Divider()
                            .padding(.vertical, 8)
                    }
                    HStack {
                        Text(employee.name)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppColors.text)
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { employee.isEmployed },
                            set: { adminVM.setEmployed($0, for: employee.id) }
                        ))
                        .labelsHidden()
                        .tint(AppColors.primary)
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

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("History")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.text)

                if vm.profile.admin {
                    Spacer()
                    Picker("View history for", selection: $selectedHistoryUserId) {
                        Text("Me").tag(String?.none)
                        ForEach(adminVM.employees) { employee in
                            Text(employee.name).tag(Optional(employee.id))
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(AppColors.primary)
                }
            }
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
