import SwiftUI

struct TeamMembersSection: View {
    let members: [TeamMember]
    let isLoading: Bool

    private let columns = [GridItem(.adaptive(minimum: 90), spacing: 8)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Team")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)
                .kerning(0.6)
                .textCase(.uppercase)

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else if members.isEmpty {
                Text("No team members")
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.textSecondary)
            } else {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(members) { member in
                        TeamMemberChip(member: member)
                    }
                }
            }
        }
    }
}

private struct TeamMemberChip: View {
    let member: TeamMember

    var body: some View {
        HStack(spacing: 6) {
            Text(member.firstName)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppColors.text)
                .lineLimit(1)
            Spacer(minLength: 0)
            Circle()
                .fill(member.isOnline ? Color.green : Color.red)
                .frame(width: 7, height: 7)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(AppColors.border, lineWidth: 1)
        )
    }
}
