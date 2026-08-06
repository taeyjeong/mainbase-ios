import SwiftUI

struct EditProjectSheet: View {
    @ObservedObject var vm: ProjectsViewModel
    let project: Project
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var description: String
    @State private var projectLead: String
    @State private var teamMembers: Set<String>
    @State private var selectedMainId: String
    @State private var selectedLabel: ProjectLabel
    @State private var selectedSublabels: Set<String>
    @State private var budgetText: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(vm: ProjectsViewModel, project: Project) {
        self.vm = vm
        self.project = project
        _title = State(initialValue: project.projectTitle)
        _description = State(initialValue: project.projectDescription)
        _projectLead = State(initialValue: project.projectLead)
        _teamMembers = State(initialValue: Set(project.teamMembers))
        _selectedMainId = State(initialValue: project.projectMainId ?? "")
        _selectedLabel = State(initialValue: project.label ?? .marketing)
        _selectedSublabels = State(initialValue: Set(project.sublabels))
        _budgetText = State(initialValue: project.budget.map { String($0) } ?? "")
    }

    private var leadOptions: [String] {
        Array(Set([project.projectLead] + vm.assignableUserEmails)).sorted()
    }

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

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Project Lead")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(AppColors.text)
                        Picker("Project Lead", selection: $projectLead) {
                            ForEach(leadOptions, id: \.self) { email in
                                Text(vm.displayName(forEmail: email)).tag(email)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(AppColors.primary)
                    }

                    ProjectCategoryPicker(
                        projectMains: vm.projectMains,
                        selectedMainId: $selectedMainId,
                        selectedLabel: $selectedLabel,
                        selectedSublabels: $selectedSublabels
                    )

                    FormTextField(label: "Budget", placeholder: "e.g. 5000", text: $budgetText, keyboardType: .decimalPad)

                    TeamMemberPicker(selectedEmails: $teamMembers, users: vm.assignableTeamMembers, excluding: projectLead)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundColor(.red)
                    }
                }
                .padding(20)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Edit Project")
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
        let result = await vm.submitEditProject(
            projectId: project.id,
            title: title,
            description: description,
            projectLead: projectLead,
            teamMembers: Array(teamMembers),
            projectMainId: selectedMainId,
            label: selectedLabel,
            sublabels: Array(selectedSublabels),
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
