import SwiftUI

/// Composes one or more tasks (each with its own optional subtasks) in a single sitting,
/// then saves them all in order when "Save" is tapped.
struct AddTaskSheet: View {
    @ObservedObject var vm: ProjectsViewModel
    let projectId: String
    @Environment(\.dismiss) private var dismiss

    @State private var drafts: [DraftTask] = [DraftTask()]
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach($drafts) { $draft in
                        DraftTaskCard(
                            draft: $draft,
                            emails: vm.assignableUserEmails,
                            displayName: vm.displayName(forEmail:),
                            onRemove: drafts.count > 1 ? { removeDraft(draft.id) } : nil
                        )
                    }

                    Button {
                        drafts.append(DraftTask())
                    } label: {
                        Label("Add Another Task", systemImage: "plus.circle.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppColors.primary)
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

    private func removeDraft(_ id: UUID) {
        drafts.removeAll { $0.id == id }
    }

    private func handleSave() async {
        isSaving = true
        errorMessage = nil
        for draft in drafts where !draft.title.trimmingCharacters(in: .whitespaces).isEmpty {
            let result = await vm.submitAddTaskWithSubtasks(
                projectId: projectId,
                title: draft.title,
                assigneeEmail: draft.assigneeEmail,
                subtasks: draft.subtasks
            )
            if !result.success {
                errorMessage = result.error
                isSaving = false
                return
            }
        }
        isSaving = false
        dismiss()
    }
}

private struct DraftTaskCard: View {
    @Binding var draft: DraftTask
    let emails: [String]
    let displayName: (String) -> String
    let onRemove: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Task")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
                Spacer()
                if let onRemove {
                    Button(action: onRemove) {
                        Image(systemName: "trash")
                            .font(.system(size: 13))
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }

            FormTextField(label: "Task Title", placeholder: "e.g. Share the itinerary link", text: $draft.title)
            AssigneePicker(selection: $draft.assigneeEmail, emails: emails, displayName: displayName)

            VStack(alignment: .leading, spacing: 10) {
                Text("Subtasks")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.text)

                ForEach($draft.subtasks) { $subtask in
                    HStack(spacing: 8) {
                        TextField("Subtask title", text: $subtask.title)
                            .inputFieldStyle()
                        Button {
                            draft.subtasks.removeAll { $0.id == subtask.id }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                }

                Button {
                    draft.subtasks.append(DraftSubtask())
                } label: {
                    Label("Add Subtask", systemImage: "plus")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppColors.primary)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.cardBackground)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.border, lineWidth: 1))
        )
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
