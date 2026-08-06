import SwiftUI
import FirebaseFirestore

struct WorkNotificationCard: View {
    let notification: WorkNotification

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            iconView
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(notification.title)
                        .font(.system(size: 15, weight: notification.read ? .regular : .semibold))
                        .foregroundColor(AppColors.text)
                        .lineLimit(1)
                    Spacer()
                    Text(timeAgo(from: notification.createdAt))
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary)
                }
                if !notification.body.isEmpty {
                    Text(notification.body)
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(notification.read ? AppColors.cardBackground : AppColors.primary.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            notification.read ? AppColors.border : AppColors.primary.opacity(0.2),
                            lineWidth: 1
                        )
                )
        )
    }

    private var iconView: some View {
        ZStack {
            Circle()
                .fill(iconTint)
                .frame(width: 36, height: 36)
            Image(systemName: iconName)
                .font(.system(size: 16))
                .foregroundColor(.white)
        }
    }

    private var iconTint: Color {
        switch notification.notificationType {
        case .clockEvent:
            return notification.isClockIn ? AppColors.primary : AppColors.textSecondary.opacity(0.4)
        case .taskAssigned, .subtaskAssigned:
            return AppColors.primary
        case .addedToProject:
            return AppColors.primary
        case .taskCompleted, .subtaskCompleted:
            return AppColors.primary
        case .chatMessage, .reportMessage:
            return AppColors.primary
        case nil:
            return AppColors.textSecondary.opacity(0.4)
        }
    }

    private var iconName: String {
        switch notification.notificationType {
        case .clockEvent:
            return notification.isClockIn ? "arrow.right.circle.fill" : "xmark.circle.fill"
        case .taskAssigned, .subtaskAssigned:
            return "checklist"
        case .addedToProject:
            return "person.crop.circle.badge.plus"
        case .taskCompleted, .subtaskCompleted:
            return "checkmark.circle.fill"
        case .chatMessage, .reportMessage:
            return "bubble.left.fill"
        case nil:
            return "bell.fill"
        }
    }

    private func timeAgo(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        let minutes = Int(interval) / 60
        let hours = minutes / 60
        let days = hours / 24
        if days > 0 { return "\(days)d ago" }
        if hours > 0 { return "\(hours)h ago" }
        if minutes > 0 { return "\(minutes)m ago" }
        return "Just now"
    }
}

#Preview {
    WorkNotificationCard(
        notification: WorkNotification(
            id: "1",
            data: [
                "title": "Alex clocked in",
                "body": "Started their shift",
                "read": false,
                "action": "clock_in",
                "createdAt": Timestamp(date: Date())
            ]
        )
    )
    .padding()
}
