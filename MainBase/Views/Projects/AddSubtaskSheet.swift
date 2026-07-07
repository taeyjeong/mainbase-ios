import SwiftUI

struct AddSubtaskSheet: View {
    @ObservedObject var vm: ProjectsViewModel
    let projectId: String
    let projectTask: ProjectTask
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var assigneeEmail = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    FormTextField(label: "Subtask Title", placeholder: "e.g. Choose 10 photos for a carousel", text: $title)

                    AssigneePicker(selection: $assigneeEmail, emails: vm.assignableUserEmails)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundColor(.red)
                    }
                }
                .padding(20)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("New Subtask")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save") { Task { await handleSave() } }
                    }
                }
            }
        }
    }

    private func handleSave() async {
        isSaving = true
        errorMessage = nil
        let result = await vm.submitAddSubtask(
            projectId: projectId,
            taskId: projectTask.id,
            title: title,
            assigneeEmail: assigneeEmail
        )
        isSaving = false
        if result.success {
            dismiss()
        } else {
            errorMessage = result.error
        }
    }
}
