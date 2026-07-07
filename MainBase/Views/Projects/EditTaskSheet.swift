import SwiftUI

struct EditTaskSheet: View {
    @ObservedObject var vm: ProjectsViewModel
    let projectId: String
    let projectTask: ProjectTask
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var assigneeEmail: String
    @State private var requiresLink: Bool
    @State private var proofLink: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(vm: ProjectsViewModel, projectId: String, projectTask: ProjectTask) {
        self.vm = vm
        self.projectId = projectId
        self.projectTask = projectTask
        _title = State(initialValue: projectTask.title)
        _assigneeEmail = State(initialValue: projectTask.assigneeEmail)
        _requiresLink = State(initialValue: projectTask.requiresLink)
        _proofLink = State(initialValue: projectTask.proofLink)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    FormTextField(label: "Task Title", placeholder: "Task title", text: $title)

                    AssigneePicker(selection: $assigneeEmail, emails: vm.assignableUserEmails)

                    CheckboxToggle(isOn: $requiresLink) {
                        Text("Requires a proof link to complete")
                            .font(.system(size: 15))
                            .foregroundColor(AppColors.text)
                    }

                    if requiresLink {
                        FormTextField(
                            label: "Proof Link",
                            placeholder: "https://...",
                            text: $proofLink,
                            keyboardType: .URL,
                            autocapitalization: .none
                        )
                    }

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

        let detailsResult = await vm.submitEditTask(
            projectId: projectId,
            taskId: projectTask.id,
            title: title,
            requiresLink: requiresLink,
            assigneeEmail: assigneeEmail
        )
        guard detailsResult.success else {
            isSaving = false
            errorMessage = detailsResult.error
            return
        }

        if proofLink.trimmingCharacters(in: .whitespaces) != projectTask.proofLink {
            let linkResult = await vm.submitTaskLink(projectId: projectId, taskId: projectTask.id, proofLink: proofLink)
            isSaving = false
            if linkResult.success {
                dismiss()
            } else {
                errorMessage = linkResult.error
            }
            return
        }

        isSaving = false
        dismiss()
    }
}
