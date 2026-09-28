import SwiftUI

/// Admin-only screen, pushed from ProfileSheetView's "Admin Tools" button. Collects everything
/// only admins can see: clock notification preference, employee list (tap through to
/// EmployeeDetailView for pay and schedule), employee history, archived projects, and project mains.
struct AdminToolsView: View {
    @ObservedObject var profileVM: ProfileViewModel
    @StateObject private var adminVM = AdminEmployeesViewModel()
    @StateObject private var projectsVM = ProjectsViewModel()

    @State private var showArchivedProjects = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                clockNotificationSection
                employeesSection
                employeeHistoryButton
                archivedProjectsButton
                ManageProjectMainsView()
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 40)
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Admin Tools")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            adminVM.startListening(company: profileVM.profile.company)
        }
        .onDisappear {
            adminVM.stopListening()
        }
        .onChange(of: profileVM.profile.clockNotificationPreference) { _, _ in
            profileVM.saveClockNotificationPreference()
        }
        .alert("Employees", isPresented: Binding(
            get: { adminVM.errorMessage != nil },
            set: { if !$0 { adminVM.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(adminVM.errorMessage ?? "")
        }
        .sheet(isPresented: $showArchivedProjects) {
            ArchivedProjectsView(vm: projectsVM)
        }
    }

    private var clockNotificationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Clock Notifications")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppColors.text)

            Picker("Clock Notifications", selection: $profileVM.profile.clockNotificationPreference) {
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

    private var employeesSection: some View {
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
                        NavigationLink {
                            EmployeeDetailView(employee: employee)
                        } label: {
                            HStack(spacing: 6) {
                                Text(employee.name)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(AppColors.text)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(AppColors.textSecondary)
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
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

    private var employeeHistoryButton: some View {
        NavigationLink {
            EmployeeHistoryView(adminVM: adminVM)
        } label: {
            ProfileNavRow(
                icon: "clock.arrow.circlepath",
                title: "Employee History",
                subtitle: "Any employee's past clock-outs and reports"
            )
        }
        .buttonStyle(.plain)
    }

    private var archivedProjectsButton: some View {
        Button {
            showArchivedProjects = true
        } label: {
            ProfileNavRow(
                icon: "archivebox",
                title: "Archived Projects",
                subtitle: "View and restore archived projects"
            )
        }
        .buttonStyle(.plain)
    }
}
