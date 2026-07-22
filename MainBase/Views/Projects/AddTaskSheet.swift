import SwiftUI

struct AddTaskSheet: View {
    @ObservedObject var vm: ProjectsViewModel
    let projectId: String
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var assigneeEmail = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    FormTextField(label: "Task Title", placeholder: "e.g. Share the itinerary link", text: $title)

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
            .navigationTitle("New Task")
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
        let result = await vm.submitAddTask(
            projectId: projectId,
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

struct AssigneePicker: View {
    @Binding var selection: String
    let emails: [String]
    var displayName: (String) -> String = { $0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Assignee")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(AppColors.text)
            Picker("Assignee", selection: $selection) {
                Text("Unassigned").tag("")
                ForEach(emails, id: \.self) { email in
                    Text(displayName(email)).tag(email)
                }
            }
            .pickerStyle(.menu)
            .tint(AppColors.primary)
        }
    }
}
