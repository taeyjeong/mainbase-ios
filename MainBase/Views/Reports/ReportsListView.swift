import SwiftUI

struct ReportsListView: View {
    @StateObject private var vm = ReportsViewModel()

    var body: some View {
        VStack(spacing: 0) {
            Text("Reports")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppColors.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 16)
                .background(AppColors.background)

            if vm.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if vm.reports.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 36))
                        .foregroundColor(AppColors.textSecondary)
                    Text("No reports yet")
                        .font(.system(size: 15))
                        .foregroundColor(AppColors.textSecondary)
                }
                Spacer()
            } else {
                List(vm.reports) { report in
                    ReportRow(report: report)
                        .listRowBackground(AppColors.cardBackground)
                        .listRowSeparatorTint(AppColors.border)
                }
                .listStyle(.plain)
            }
        }
        .background(AppColors.background.ignoresSafeArea())
        .onAppear { vm.startListening() }
    }
}

private struct ReportRow: View {
    let report: Report

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                Text(report.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.text)
                Spacer()
                Text(Self.formatter.string(from: report.timestamp))
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textSecondary)
            }
            Text(report.reportText)
                .font(.system(size: 14))
                .foregroundColor(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    ReportsListView()
}
