import SwiftUI

/// The owner's edit of one of their reports (any past one), presented from the Edit button on a
/// ReportRow. Only the text, the project Main and the links change; the date, author and
/// replies stay as they were, and no edit time is recorded.
struct EditReportSheet: View {
    let report: Report
    @ObservedObject var vm: ReportsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var text: String
    @State private var projectMainId: String?
    @State private var links: [ReportLinkDraft]
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
        _projectMainId = State(initialValue: report.projectMainId)
        // Like the clock-out sheet, always show at least one row.
        _links = State(initialValue: report.links.isEmpty ? [ReportLinkDraft()] : report.links.map(ReportLinkDraft.init(link:)))
    }

    private var trimmedText: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var hasChanges: Bool {
        trimmedText != report.reportText
            || projectMainId != report.projectMainId
            || links.compactMap(\.firestoreValue) != report.links.map(\.firestoreValue)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Clocked out \(Self.dateFormatter.string(from: report.timestamp))")
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.textSecondary)

                    TextEditor(text: $text)
                        .focused($isFocused)
                        .font(.system(size: 15))
                        .scrollContentBackground(.hidden)
                        .padding(10)
                        .frame(minHeight: 180)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(AppColors.cardBackground)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.border, lineWidth: 1))
                        )

                    ReportProjectMainPicker(projectMains: vm.projectMains, selectedMainId: $projectMainId)
                        .padding(.top, 8)

                    ReportLinkFields(links: $links)
                        .padding(.top, 12)
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
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
                            .disabled(trimmedText.isEmpty || links.contains(where: \.isInvalid) || !hasChanges)
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
            errorMessage = await vm.updateReport(report, text: text, projectMainId: projectMainId, links: links)
            isSaving = false
            if errorMessage == nil { dismiss() }
        }
    }
}
