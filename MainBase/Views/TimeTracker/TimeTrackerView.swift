import SwiftUI
import Combine

struct TimeTrackerView: View {
    var onClockIn: () -> Void = {}

    @EnvironmentObject private var notificationVM: NotificationViewModel
    @EnvironmentObject private var authVM: AuthViewModel
    @EnvironmentObject private var vm: TimeTrackerViewModel
    @StateObject private var teamVM = TeamMemberViewModel()

    @State private var timerDisplay = "00:00:00"
    @State private var showingProfile = false
    @State private var showNotifications = false
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
                    TeamMembersSection(members: teamVM.members, isLoading: teamVM.isLoading)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .background(AppColors.background.ignoresSafeArea())
        .onAppear {
            teamVM.startListening()
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
        .sheet(isPresented: $showClockOutModal) {
            ClockOutSheetView(
                report: $clockOutReport,
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

    private var topBar: some View {
        HStack {
            Button { showingProfile = true } label: {
                Circle()
                    .fill(AppColors.border)
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 18))
                            .foregroundColor(AppColors.textSecondary)
                    )
            }
            .buttonStyle(.plain)

            Spacer()

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
        .padding(.top, 4)
    }

    private var clockCard: some View {
        Button(action: handleClockToggle) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(AppColors.cardBackground)
                        .frame(width: 60, height: 60)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(vm.isClockedIn ? AppColors.primary : AppColors.textSecondary)
                        .frame(width: 4, height: 28)
                        .offset(y: -4)
                }

                Text(vm.isClockedIn ? "Clocked In" : "Clocked Out")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppColors.cardBackground)

                Text(timerDisplay)
                    .font(.system(size: 52, weight: .heavy))
                    .foregroundColor(AppColors.cardBackground)
                    .monospacedDigit()
                    .kerning(2)

                if vm.isSaving {
                    ProgressView().tint(AppColors.cardBackground)
                } else {
                    Text(vm.isClockedIn ? "Tap to Clock Out" : "Tap to Clock In")
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.cardBackground.opacity(0.9))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(vm.isClockedIn ? AppColors.primary : AppColors.textSecondary)
            )
        }
        .buttonStyle(.plain)
        .disabled(vm.isSaving)
    }

    private func handleClockToggle() {
        if vm.isClockedIn {
            clockOutReport = ""
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
