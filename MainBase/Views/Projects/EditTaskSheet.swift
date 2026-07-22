import SwiftUI

struct EditTaskSheet: View {
    @ObservedObject var vm: ProjectsViewModel
    let projectId: String
    let projectTask: ProjectTask
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var assigneeEmail: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(vm: ProjectsViewModel, projectId: String, projectTask: ProjectTask) {
        self.vm = vm
        self.projectId = projectId
        self.projectTask = projectTask
        _title = State(initialValue: projectTask.title)
        _assigneeEmail = State(initialValue: projectTask.assigneeEmail)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    FormTextField(label: "Task Title", placeholder: "Task title", text: $title)

                    AssigneePicker(selection: $assigneeEmail, emails: vm.assignableUserEmails, displayName: vm.displayName(forEmail:))

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundColor(.red)
                    }
                }
                .padding(20)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Edit Task")
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

        let result = await vm.submitEditTask(
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
