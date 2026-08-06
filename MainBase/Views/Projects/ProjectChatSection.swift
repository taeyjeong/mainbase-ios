import SwiftUI

/// Real-time team chat shown at the bottom of a project's detail screen. Up to 3
/// messages can be pinned by any team member; links in message text render as rich
/// thumbnails via `LinkThumbnailView`; every action a team member takes elsewhere in the
/// project (adding/completing a task or subtask, adding photos, pinning a message) shows
/// up here as an italic, timestamped activity line.
struct ProjectChatSection: View {
    let projectId: String
    let teamMembers: [String]
    @ObservedObject var vm: ProjectsViewModel

    @State private var draftText = ""
    @State private var isSending = false
    @State private var errorMessage: String?

    private var pinnedMessages: [ProjectChatMessage] {
        vm.currentChatMessages.filter { $0.isPinned }
    }

    private var timelineMessages: [ProjectChatMessage] {
        vm.currentChatMessages.filter { !$0.isPinned }
    }

    private var teamMembersLine: String? {
        guard !teamMembers.isEmpty else { return nil }
        return teamMembers.map(vm.teamMemberTag(forEmail:)).joined(separator: ", ")
    }

    var body: some View {
        Section {
            if !pinnedMessages.isEmpty {
                ForEach(pinnedMessages) { message in
                    ChatMessageRow(message: message, displayName: vm.displayName(forEmail:), isPinned: true) {
                        Task { _ = await vm.togglePinMessage(projectId: projectId, message: message) }
                    }
                    .listRowBackground(AppColors.primary.opacity(0.06))
                }
            }

            ForEach(timelineMessages) { message in
                ChatMessageRow(message: message, displayName: vm.displayName(forEmail:), isPinned: false) {
                    Task {
                        let result = await vm.togglePinMessage(projectId: projectId, message: message)
                        if !result.success { errorMessage = result.error }
                    }
                }
                .listRowBackground(AppColors.cardBackground)
            }

            if vm.currentChatMessages.isEmpty {
                Text("No messages yet.")
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.textSecondary)
                    .listRowBackground(AppColors.cardBackground)
            }

            HStack(spacing: 8) {
                TextField("Message the team\u{2026}", text: $draftText, axis: .vertical)
                    .lineLimit(1...4)
                    .inputFieldStyle()

                Button {
                    Task { await sendMessage() }
                } label: {
                    if isSending {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 26))
                            .foregroundColor(AppColors.primary)
                    }
                }
                .disabled(isSending || draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .listRowBackground(AppColors.cardBackground)

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 12))
                    .foregroundColor(.red)
                    .listRowBackground(AppColors.cardBackground)
            }
        } header: {
            HStack {
                Text("Team Chat")
                    .layoutPriority(1)
                Spacer()
                if let teamMembersLine {
                    Text(teamMembersLine)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
        }
    }

    private func sendMessage() async {
        isSending = true
        errorMessage = nil
        let result = await vm.sendChatMessage(projectId: projectId, text: draftText)
        isSending = false
        if result.success {
            draftText = ""
        } else {
            errorMessage = result.error
        }
    }
}

private let chatTimeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "h:mm"
    return formatter
}()

private func chatTimeString(from date: Date) -> String {
    let time = chatTimeFormatter.string(from: date)
    let period = Calendar.current.component(.hour, from: date) < 12 ? "am" : "pm"
    let tz = TimeZone.current.abbreviation(for: date) ?? ""
    return "\(time)\(period) \(tz)".trimmingCharacters(in: .whitespaces)
}

private struct ChatMessageRow: View {
    let message: ProjectChatMessage
    let displayName: (String) -> String
    let isPinned: Bool
    let onTogglePin: () -> Void

    private var links: [ExtractedLink] {
        ReportTextLinks.extract(from: message.text).links
    }

    private var cleanedText: String {
        ReportTextLinks.extract(from: message.text).cleanedText
    }

    private var timestamp: String {
        message.createdAt.map(chatTimeString(from:)) ?? ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if message.isSystemEvent {
                HStack(alignment: .top) {
                    Text("\(timestamp) \(message.text)")
                        .font(.system(size: 12))
                        .italic()
                        .foregroundColor(AppColors.textSecondary)
                    Spacer()
                    pinButton
                }
            } else {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        (Text("\(displayName(message.senderEmail)): ").fontWeight(.semibold) + Text(cleanedText))
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.text)

                        ForEach(links) { link in
                            LinkThumbnailView(url: link.url)
                        }
                    }
                    Spacer()
                    pinButton
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var pinButton: some View {
        Button(action: onTogglePin) {
            Image(systemName: isPinned ? "pin.fill" : "pin")
                .font(.system(size: 12))
                .foregroundColor(isPinned ? AppColors.primary : AppColors.textSecondary)
        }
        .buttonStyle(.borderless)
    }
}
