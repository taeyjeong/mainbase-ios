import SwiftUI

struct ReportsListView: View {
    @StateObject private var vm = ReportsViewModel()

    var body: some View {
        VStack(spacing: 0) {
            header

            if vm.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if vm.reportSections.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 36))
                        .foregroundColor(AppColors.textSecondary)
                    Text(vm.selectedUserId == nil ? "No reports yet" : "No reports for this person")
                        .font(.system(size: 15))
                        .foregroundColor(AppColors.textSecondary)
                }
                Spacer()
            } else {
                List {
                    ForEach(Array(vm.reportSections.enumerated()), id: \.offset) { _, section in
                        Section {
                            ForEach(section.items) { report in
                                ReportRow(report: report)
                                    .listRowBackground(AppColors.cardBackground)
                            }
                        } header: {
                            Text(section.title)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(AppColors.textSecondary)
                                .textCase(nil)
                        }
                    }
                }
                .listStyle(.plain)
                .listRowSeparatorTint(AppColors.border)
            }
        }
        .background(AppColors.background.ignoresSafeArea())
        .onAppear { vm.startListening() }
        .onDisappear { vm.stopListening() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reports")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppColors.text)

            if !vm.availablePeople.isEmpty {
                HStack {
                    Text("Filter")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)

                    Picker("Filter by person", selection: $vm.selectedUserId) {
                        Text("All people").tag(String?.none)
                        ForEach(vm.availablePeople, id: \.id) { person in
                            Text(person.name).tag(Optional(person.id))
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(AppColors.primary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 16)
        .background(AppColors.background)
    }
}

private struct ReportRow: View {
    let report: Report

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
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
