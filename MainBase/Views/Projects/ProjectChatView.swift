import SwiftUI

/// Full-screen team chat for a project, presented from the floating message button in
/// ProjectDetailView. Uses the same clean message layout as the report chat: sender name +
/// timestamp above each message, links rendered as thumbnails, and auto-generated activity
/// entries shown as italic system lines. Pinned messages (up to 3) sit in a strip up top.
struct ProjectChatView: View {
    let projectId: String
    let teamMembers: [String]
    @ObservedObject var vm: ProjectsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var draftText = ""
    @State private var isSending = false
    @State private var errorMessage: String?

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()

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
        NavigationStack {
            VStack(spacing: 0) {
                if let teamMembersLine {
                    header(teamMembersLine)
                    Divider()
                }

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 14) {
                            if !pinnedMessages.isEmpty {
                                pinnedSection
                                Divider().padding(.vertical, 4)
                            }

                            if vm.currentChatMessages.isEmpty {
                                Text("No messages yet. Send one to start the team chat.")
                                    .font(.system(size: 13))
                                    .foregroundColor(AppColors.textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.top, 24)
                            } else {
                                ForEach(timelineMessages) { message in
                                    ProjectChatMessageRow(
                                        message: message,
                                        displayName: vm.displayName(forEmail:),
                                        formatter: Self.timeFormatter,
                                        onTogglePin: { togglePin(message) }
                                    )
                                    .id(message.id)
                                }
                            }
                        }
                        .padding(16)
                    }
                    .onChange(of: vm.currentChatMessages.count) { _, _ in
                        guard let lastId = timelineMessages.last?.id else { return }
                        withAnimation { proxy.scrollTo(lastId, anchor: .bottom) }
                    }
                }

                Divider()

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
                .padding(12)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                }
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Team Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func header(_ line: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 12))
                .foregroundColor(AppColors.textSecondary)
            Text(line)
                .font(.system(size: 13))
                .foregroundColor(AppColors.textSecondary)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(AppColors.cardBackground)
    }

    private var pinnedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 4) {
                Image(systemName: "pin.fill").font(.system(size: 10))
                Text("PINNED").font(.system(size: 11, weight: .semibold)).kerning(0.6)
            }
            .foregroundColor(AppColors.primary)

            ForEach(pinnedMessages) { message in
                ProjectChatMessageRow(
                    message: message,
                    displayName: vm.displayName(forEmail:),
                    formatter: Self.timeFormatter,
                    onTogglePin: { togglePin(message) }
                )
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12).fill(AppColors.primary.opacity(0.06))
        )
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

    private func togglePin(_ message: ProjectChatMessage) {
        Task {
            let result = await vm.togglePinMessage(projectId: projectId, message: message)
            if !result.success { errorMessage = result.error }
        }
    }
}

private struct ProjectChatMessageRow: View {
    let message: ProjectChatMessage
    let displayName: (String) -> String
    let formatter: DateFormatter
    let onTogglePin: () -> Void

    private var links: [ExtractedLink] {
        ReportTextLinks.extract(from: message.text).links
    }

    private var cleanedText: String {
        ReportTextLinks.extract(from: message.text).cleanedText
    }

    private var timestamp: String {
        message.createdAt.map { formatter.string(from: $0) } ?? ""
    }

    var body: some View {
        if message.isSystemEvent {
            HStack(alignment: .top, spacing: 6) {
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
                    HStack(spacing: 6) {
                        Text(displayName(message.senderEmail))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(AppColors.text)
                        if !timestamp.isEmpty {
                            Text(timestamp)
                                .font(.system(size: 11))
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                    if !cleanedText.isEmpty {
                        Text(cleanedText)
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.text)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    ForEach(links) { link in
                        LinkThumbnailView(url: link.url)
                    }
                }
                Spacer()
                pinButton
            }
        }
    }

    private var pinButton: some View {
        Button(action: onTogglePin) {
            Image(systemName: message.isPinned ? "pin.fill" : "pin")
                .font(.system(size: 12))
                .foregroundColor(message.isPinned ? AppColors.primary : AppColors.textSecondary)
        }
        .buttonStyle(.borderless)
    }
}
