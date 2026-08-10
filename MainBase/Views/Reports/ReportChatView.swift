import SwiftUI

/// Chatroom for a single report. No Firestore data exists for this chat until the first
/// message is sent — opening this screen just attaches a listener, it never creates anything.
struct ReportChatView: View {
    let report: Report
    @ObservedObject var vm: ReportsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var draftText = ""
    @State private var isSending = false
    @State private var errorMessage: String?

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()

    private static let daySeparatorFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter
    }()

    /// Whether a day divider should precede the message at `index` — shown above the first
    /// message of each calendar day. Messages awaiting a server timestamp (nil `createdAt`)
    /// don't trigger a divider.
    private func shouldShowDateSeparator(at index: Int) -> Bool {
        let messages = vm.currentReportChatMessages
        guard let current = messages[index].createdAt else { return false }
        guard index > 0 else { return true }
        guard let previous = messages[index - 1].createdAt else { return true }
        return !Calendar.current.isDate(current, inSameDayAs: previous)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                reportHeader

                Divider()

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 14) {
                            if vm.currentReportChatMessages.isEmpty {
                                Text("No messages yet. Send one to start this report's chat.")
                                    .font(.system(size: 13))
                                    .foregroundColor(AppColors.textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.top, 24)
                            } else {
                                ForEach(Array(vm.currentReportChatMessages.enumerated()), id: \.element.id) { index, message in
                                    if shouldShowDateSeparator(at: index), let createdAt = message.createdAt {
                                        dateSeparator(createdAt)
                                    }
                                    ReportChatMessageRow(message: message, formatter: Self.timeFormatter)
                                        .id(message.id)
                                }
                            }
                        }
                        .padding(16)
                    }
                    .onChange(of: vm.currentReportChatMessages.count) { _, _ in
                        guard let lastId = vm.currentReportChatMessages.last?.id else { return }
                        withAnimation { proxy.scrollTo(lastId, anchor: .bottom) }
                    }
                }

                Divider()

                HStack(spacing: 8) {
                    TextField("Message\u{2026}", text: $draftText, axis: .vertical)
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
            .navigationTitle("\(report.name)'s Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear { vm.startReportChatListener(report: report) }
            .onDisappear { vm.stopReportChatListener() }
        }
    }

    private func dateSeparator(_ date: Date) -> some View {
        Text(Self.daySeparatorFormatter.string(from: date))
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(AppColors.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
    }

    private var reportHeader: some View {
        let parsed = ReportTextLinks.extract(from: report.reportText)

        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                Text(report.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.text)
                Spacer()
                Text(Self.timeFormatter.string(from: report.timestamp))
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textSecondary)
            }
            if !parsed.cleanedText.isEmpty {
                Text(parsed.cleanedText)
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ReportLinksGrid(links: parsed.links)
        }
        .padding(16)
        .background(AppColors.cardBackground)
    }

    private func sendMessage() async {
        isSending = true
        errorMessage = nil
        let result = await vm.sendReportChatMessage(draftText, on: report)
        isSending = false
        if result.success {
            draftText = ""
        } else {
            errorMessage = result.error
        }
    }
}

private struct ReportChatMessageRow: View {
    let message: ReportChatMessage
    let formatter: DateFormatter

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(message.senderName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppColors.text)
                if let createdAt = message.createdAt {
                    Text(formatter.string(from: createdAt))
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            Text(message.text)
                .font(.system(size: 14))
                .foregroundColor(AppColors.text)
        }
    }
}

#Preview {
    ReportChatView(
        report: Report(id: "1", userId: "u1", name: "Jordan", emoji: "🦊", reportText: "Sample report", timestamp: Date(), messageCount: 0),
        vm: ReportsViewModel()
    )
}
