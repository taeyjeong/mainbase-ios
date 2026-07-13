import SwiftUI

struct TeamMemberPicker: View {
    @Binding var selectedEmails: Set<String>
    let users: [AssignableUser]
    var excluding: String = ""

    private var availableUsers: [AssignableUser] {
        users.filter { $0.email.caseInsensitiveCompare(excluding) != .orderedSame }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Team Members")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(AppColors.text)
            if availableUsers.isEmpty {
                Text("No other active employees available")
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.textSecondary)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(availableUsers) { user in
                        CheckboxToggle(isOn: Binding(
                            get: { selectedEmails.contains(user.email) },
                            set: { isOn in
                                if isOn {
                                    selectedEmails.insert(user.email)
                                } else {
                                    selectedEmails.remove(user.email)
                                }
                            }
                        )) {
                            Text(user.name)
                                .font(.system(size: 14))
                                .foregroundColor(AppColors.text)
                        }
                    }
                }
            }
        }
    }
}
