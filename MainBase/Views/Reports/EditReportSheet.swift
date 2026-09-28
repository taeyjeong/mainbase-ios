import SwiftUI

/// The owner's edit of one of their reports, presented from the Edit button on a ReportRow.
/// Only the text changes; the date, author and replies stay as they were.
struct EditReportSheet: View {
    let report: Report
    @ObservedObject var vm: ReportsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var text: String
    @State private var isSaving = false
    @State private var errorMessage: String?
    @FocusState private var isFocused: Bool

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    init(report: Report, vm: ReportsViewModel) {
        self.report = report
        self.vm = vm
        _text = State(initialValue: report.reportText)
    }

    private var trimmedText: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 8) {
                Text("Clocked out \(Self.dateFormatter.string(from: report.timestamp))")
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.textSecondary)

                TextEditor(text: $text)
                    .focused($isFocused)
                    .font(.system(size: 15))
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppColors.cardBackground)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.border, lineWidth: 1))
                    )
            }
            .padding(20)
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Edit Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save") { save() }
                            .fontWeight(.semibold)
                            .disabled(trimmedText.isEmpty || trimmedText == report.reportText)
                    }
                }
            }
            .onAppear { isFocused = true }
            .alert("Edit Report", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func save() {
        isSaving = true
        Task {
            errorMessage = await vm.updateReportText(report, to: text)
            isSaving = false
            if errorMessage == nil { dismiss() }
        }
    }
}
