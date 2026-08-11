import SwiftUI

struct AddProjectSheet: View {
    @ObservedObject var vm: ProjectsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var description = ""
    @State private var selectedMainId = ""
    @State private var selectedSublabels: Set<String> = []
    @State private var teamMembers: Set<String> = []
    @State private var budgetText = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    FormTextField(label: "Project Title", placeholder: "e.g. Summer Content Push", text: $title)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(AppColors.text)
                        TextField("Optional description", text: $description, axis: .vertical)
                            .lineLimit(3...6)
                            .inputFieldStyle()
                    }

                    ProjectCategoryPicker(
                        projectMains: vm.projectMains,
                        selectedMainId: $selectedMainId,
                        selectedSublabels: $selectedSublabels
                    )

                    FormTextField(label: "Budget", placeholder: "e.g. 5000", text: $budgetText, keyboardType: .decimalPad)

                    TeamMemberPicker(selectedEmails: $teamMembers, users: vm.assignableTeamMembers, excluding: vm.currentUserEmail)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundColor(.red)
                    }
                }
                .padding(20)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("New Project")
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
            .onAppear {
                if selectedMainId.isEmpty {
                    selectedMainId = vm.projectMains.first?.id ?? ""
                }
            }
        }
    }

    private func handleSave() async {
        isSaving = true
        errorMessage = nil
        let result = await vm.submitProject(
            title: title,
            description: description,
            projectMainId: selectedMainId,
            sublabels: Array(selectedSublabels),
            teamMembers: Array(teamMembers),
            budget: Double(budgetText)
        )
        isSaving = false
        if result.success {
            dismiss()
        } else {
            errorMessage = result.error
        }
    }
}
