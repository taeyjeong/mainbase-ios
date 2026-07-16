import SwiftUI
import FirebaseAuth

struct NotificationsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var notificationVM: NotificationViewModel

    var body: some View {
        NavigationStack {
            Group {
                if notificationVM.notifications.isEmpty {
                    emptyState
                } else {
                    notificationList
                }
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.primary)
                }
                if notificationVM.unreadCount > 0 {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Mark all read") {
                            Task {
                                if let uid = Auth.auth().currentUser?.uid {
                                    await notificationVM.markAllRead(userId: uid)
                                }
                            }
                        }
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.primary)
                    }
                }
            }
        }
    }

    private var notificationList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 8) {
                let unread = notificationVM.notifications.filter { !$0.read }
                let read = notificationVM.notifications.filter { $0.read }

                if !unread.isEmpty {
                    sectionLabel("New")
                    ForEach(unread) { WorkNotificationCard(notification: $0) }
                }
                if !read.isEmpty {
                    sectionLabel("Earlier")
                    ForEach(read) { WorkNotificationCard(notification: $0) }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12))
            .foregroundColor(AppColors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "bell.fill")
                .font(.system(size: 48))
                .foregroundColor(AppColors.primary)
            Text("No notifications")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(AppColors.text)
            Text("Clock-in updates, task assignments, and project changes will appear here.")
                .font(.system(size: 14))
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
            Spacer()
        }
    }
}

#Preview {
    NotificationsView()
        .environmentObject(NotificationViewModel())
}
