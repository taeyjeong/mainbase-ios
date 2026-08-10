import SwiftUI
import Combine

struct TimeTrackerView: View {
    var onClockIn: () -> Void = {}

    @EnvironmentObject private var notificationVM: NotificationViewModel
    @EnvironmentObject private var authVM: AuthViewModel
    @EnvironmentObject private var vm: TimeTrackerViewModel
    @StateObject private var teamVM = TeamMemberViewModel()
    @StateObject private var projectsVM = ProjectsViewModel()

    @State private var timerDisplay = "00:00:00"
    @State private var showingProfile = false
    @State private var showNotifications = false
    @State private var showingSchedule = false
    @State private var showClockOutModal = false
    @State private var clockOutReport = ""
    @State private var showEmptyReportAlert = false

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 16)
                .background(AppColors.background)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    clockCard
                    if vm.isAdmin || vm.isClockedIn {
                        TeamMembersSection(members: teamVM.members, isLoading: teamVM.isLoading)
                    }
                    ReportsListView()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .background(AppColors.background.ignoresSafeArea())
        .onAppear {
            teamVM.startListening()
            Task { await projectsVM.loadProjects() }
        }
        .onReceive(ticker) { now in
            guard vm.isClockedIn, let start = vm.clockInTime else { return }
            timerDisplay = vm.formattedElapsed(from: start, now: now)
        }
        .onChange(of: vm.isClockedIn) { _, isClockedIn in
            if !isClockedIn { timerDisplay = "00:00:00" }
        }
        .sheet(isPresented: $showingProfile) {
            ProfileSheetView()
                .environmentObject(authVM)
        }
        .sheet(isPresented: $showNotifications) {
            NotificationsView()
                .environmentObject(notificationVM)
        }
        .sheet(isPresented: $showingSchedule) {
            ScheduleView()
        }
        .sheet(isPresented: $showClockOutModal) {
            ClockOutSheetView(
                report: $clockOutReport,
                completedTasks: completedTasksToday,
                onCancel: {
                    showClockOutModal = false
                    clockOutReport = ""
                },
                onSubmit: handleSubmitClockOut
            )
        }
        .alert("Report required", isPresented: $showEmptyReportAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please describe what you worked on before clocking out.")
        }
    }

    private var currentUserEmoji: String {
        (teamVM.members.first { $0.id == authVM.currentUserId }?.emoji ?? "")
            .trimmingCharacters(in: .whitespaces)
    }

    private var topBar: some View {
        HStack {
            Button { showingProfile = true } label: {
                Circle()
                    .fill(AppColors.border)
                    .frame(width: 36, height: 36)
                    .overlay(
                        Group {
                            if currentUserEmoji.isEmpty {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(AppColors.textSecondary)
                            } else {
                                Text(currentUserEmoji)
                                    .font(.system(size: 18))
                            }
                        }
                    )
            }
            .buttonStyle(.plain)

            Spacer()

            HStack(spacing: 16) {
                Button { showingSchedule = true } label: {
                    Image(systemName: "calendar")
                        .font(.system(size: 20))
                        .foregroundColor(AppColors.text)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Schedule")

                Button { showNotifications = true } label: {
                    Image(systemName: "bell")
                        .font(.system(size: 20))
                        .foregroundColor(AppColors.text)
                        .overlay(alignment: .topTrailing) {
                            if notificationVM.unreadCount > 0 {
                                Circle()
                                    .fill(.red)
                                    .frame(width: 8, height: 8)
                                    .offset(x: 3, y: -3)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 4)
    }

    private var clockCard: some View {
        Button(action: handleClockToggle) {
            HStack(spacing: 12) {
                Image(systemName: vm.isClockedIn ? "stop.circle.fill" : "play.circle.fill")
                    .font(.system(size: 28))

                VStack(alignment: .leading, spacing: 2) {
                    Text(vm.isClockedIn ? "Clock Out" : "Clock In")
                        .font(.system(size: 18, weight: .bold))
                    Text(vm.isClockedIn ? "You're on the clock" : "Ready when you are")
                        .font(.system(size: 13))
                        .opacity(0.9)
                }

                Spacer()

                if vm.isSaving {
                    ProgressView().tint(vm.isClockedIn ? .white : AppColors.primary)
                } else {
                    Text(vm.isClockedIn ? timerDisplay : "00:00:00")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                }
            }
            .foregroundColor(vm.isClockedIn ? .white : AppColors.text)
            .padding(18)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(vm.isClockedIn ? Color.green : AppColors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(vm.isClockedIn ? Color.clear : AppColors.border, lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(vm.isSaving)
    }

    /// Top-level tasks the current user marked complete today, across all their projects, shown
    /// as a checklist on the clock-out sheet.
    private var completedTasksToday: [CompletedTaskItem] {
        let email = projectsVM.currentUserEmail.trimmingCharacters(in: .whitespaces).lowercased()
        guard !email.isEmpty else { return [] }
        let calendar = Calendar.current
        return projectsVM.projects.flatMap { project in
            project.tasks.compactMap { task -> CompletedTaskItem? in
                guard task.isCompleted,
                      task.assigneeEmail.trimmingCharacters(in: .whitespaces).lowercased() == email,
                      let completedAt = task.completedAt,
                      calendar.isDateInToday(completedAt) else { return nil }
                return CompletedTaskItem(
                    id: task.id,
                    projectTitle: project.projectTitle,
                    taskTitle: task.title
                )
            }
        }
    }

    private func handleClockToggle() {
        if vm.isClockedIn {
            clockOutReport = ""
            Task { await projectsVM.loadProjects() }
            showClockOutModal = true
        } else {
            Task {
                await vm.clockIn()
                onClockIn()
            }
        }
    }

    private func handleSubmitClockOut() {
        let report = clockOutReport.trimmingCharacters(in: .whitespaces)
        guard !report.isEmpty else {
            showEmptyReportAlert = true
            return
        }
        showClockOutModal = false
        clockOutReport = ""
        Task { await vm.clockOut(report: report) }
    }
}

#Preview {
    TimeTrackerView()
        .environmentObject(NotificationViewModel())
        .environmentObject(AuthViewModel())
        .environmentObject(TimeTrackerViewModel())
}
