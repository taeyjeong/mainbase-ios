import SwiftUI

/// The signed-in user's saved Gemini monthly reports, pushed from ProfileSheetView's
/// "Monthly Reports" row. Reports are made and saved from "Summarize this month" in the
/// report history (MonthlySummaryPopup).
struct MonthlyReportsView: View {
    @StateObject private var vm = SavedSummariesViewModel()

    var body: some View {
        ScrollView(showsIndicators: false) {
            Group {
                if vm.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                } else if vm.summaries.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 12) {
                        ForEach(vm.summaries) { summary in
                            NavigationLink {
                                MonthlyReportDetailView(summary: summary)
                            } label: {
                                MonthlyReportRow(summary: summary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 40)
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Monthly Reports")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { vm.startListening() }
        .onDisappear { vm.stopListening() }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 30))
                .foregroundColor(AppColors.textSecondary)
            Text("No saved reports yet")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(AppColors.text)
            Text("Filter the report history to yourself and tap \"Summarize this month\" to create one.")
                .font(.system(size: 13))
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

enum MonthlyReportFormatting {
    static let createdFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    static func createdText(_ summary: MonthlySummary) -> String {
        guard let createdAt = summary.createdAt else { return "Saving…" }
        return "Created \(createdFormatter.string(from: createdAt))"
    }
}

private struct MonthlyReportRow: View {
    let summary: MonthlySummary

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 18))
                .foregroundColor(AppColors.primary)
                .frame(width: 36, height: 36)
                .background(Circle().fill(AppColors.primary.opacity(0.1)))

            VStack(alignment: .leading, spacing: 3) {
                Text(summary.monthTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppColors.text)
                Text(MonthlyReportFormatting.createdText(summary))
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.cardBackground)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColors.border, lineWidth: 1))
        )
    }
}

struct MonthlyReportDetailView: View {
    let summary: MonthlySummary

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(summary.monthTitle)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AppColors.text)
                    Text(MonthlyReportFormatting.createdText(summary))
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.textSecondary)
                }

                Divider()

                Text(GeminiMarkdown.attributed(summary.reportText))
                    .font(.system(size: 15))
                    .foregroundColor(AppColors.text)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppColors.cardBackground)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColors.border, lineWidth: 1))
            )
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 40)
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Monthly Report")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                ShareLink(item: "\(summary.monthTitle) Report\n\n\(summary.reportText)")
            }
        }
    }
}
