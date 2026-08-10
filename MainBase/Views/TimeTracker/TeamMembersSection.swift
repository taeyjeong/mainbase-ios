import SwiftUI

struct TeamMembersSection: View {
    let members: [TeamMember]
    let isLoading: Bool

    @State private var showOffline = false

    /// Online members always come first (alphabetical); offline members follow, ordered by who
    /// clocked out most recently.
    private var onlineMembers: [TeamMember] {
        members
            .filter { $0.isOnline }
            .sorted { $0.firstName.localizedCaseInsensitiveCompare($1.firstName) == .orderedAscending }
    }

    private var offlineMembers: [TeamMember] {
        members
            .filter { !$0.isOnline }
            .sorted { ($0.lastClockOut ?? .distantPast) > ($1.lastClockOut ?? .distantPast) }
    }

    private var visibleMembers: [TeamMember] {
        showOffline ? onlineMembers + offlineMembers : onlineMembers
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("TEAM (\(onlineMembers.count))")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
                    .kerning(0.6)
                Spacer()
                if !offlineMembers.isEmpty {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) { showOffline.toggle() }
                    } label: {
                        Text(showOffline ? "Hide Offline" : "Show Offline")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(AppColors.primary)
                    }
                    .buttonStyle(.plain)
                }
            }

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else if visibleMembers.isEmpty {
                Text("No one online")
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.textSecondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(visibleMembers) { member in
                            TeamMemberChip(member: member)
                        }
                    }
                }
            }
        }
    }
}

private struct TeamMemberChip: View {
    let member: TeamMember

    private var displayEmoji: String {
        member.emoji.trimmingCharacters(in: .whitespaces).isEmpty ? "👻" : member.emoji
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(displayEmoji)
                .font(.system(size: 18))

            Text(member.firstName)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(AppColors.text)
                .lineLimit(1)

            Circle()
                .fill(member.isOnline ? Color.green : Color.gray)
                .frame(width: 8, height: 8)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(AppColors.cardBackground)
                .overlay(Capsule().stroke(AppColors.border, lineWidth: 1))
        )
    }
}
