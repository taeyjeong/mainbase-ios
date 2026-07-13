import SwiftUI

struct ProjectDetailView: View {
    let project: Project
    @ObservedObject var vm: ProjectsViewModel

    @State private var expandedTaskIds: Set<String> = []
    @State private var showingAddTask = false
    @State private var taskToEdit: ProjectTask?
    @State private var taskForSubtask: ProjectTask?

    private var currentProject: Project {
        vm.projects.first(where: { $0.id == project.id }) ?? project
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    if !currentProject.projectDescription.isEmpty {
                        DescriptionText(text: currentProject.projectDescription)
                    }
                    Text("Lead: \(vm.displayName(forEmail: currentProject.projectLead))")
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.textSecondary)
                    if !currentProject.teamMembers.isEmpty {
                        Text("Team: \(currentProject.teamMembers.map(vm.displayName(forEmail:)).joined(separator: ", "))")
                            .font(.system(size: 13))
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                .listRowBackground(AppColors.cardBackground)
            }

            Section("Tasks") {
                ForEach(currentProject.tasks) { projectTask in
                    TaskRow(
                        projectTask: projectTask,
                        isExpanded: expandedTaskIds.contains(projectTask.id),
                        isSaving: vm.isSavingTask,
                        onToggleExpanded: { toggleExpanded(projectTask.id) },
                        onToggleComplete: { isCompleted in
                            Task {
                                await vm.submitToggleTaskCompletion(projectId: project.id, taskId: projectTask.id, isCompleted: isCompleted)
                            }
                        },
                        onEdit: { taskToEdit = projectTask },
                        onAddSubtask: { taskForSubtask = projectTask },
                        onDelete: {
                            Task { await vm.submitDeleteTask(projectId: project.id, taskId: projectTask.id) }
                        },
                        onToggleSubtask: { subtask, isCompleted in
                            Task {
                                await vm.submitCompleteSubtask(projectId: project.id, taskId: projectTask.id, subtaskId: subtask.id, isCompleted: isCompleted)
                            }
                        },
                        onDeleteSubtask: { subtask in
                            Task {
                                await vm.submitDeleteSubtask(projectId: project.id, taskId: projectTask.id, subtaskId: subtask.id)
                            }
                        }
                    )
                    .listRowBackground(AppColors.cardBackground)
                }
            }
        }
        .listStyle(.plain)
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle(currentProject.projectTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddTask = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddTask) {
            AddTaskSheet(vm: vm, projectId: project.id)
        }
        .sheet(item: $taskToEdit) { editingTask in
            EditTaskSheet(vm: vm, projectId: project.id, projectTask: editingTask)
        }
        .sheet(item: $taskForSubtask) { parentTask in
            AddSubtaskSheet(vm: vm, projectId: project.id, projectTask: parentTask)
        }
    }

    private func toggleExpanded(_ taskId: String) {
        if expandedTaskIds.contains(taskId) {
            expandedTaskIds.remove(taskId)
        } else {
            expandedTaskIds.insert(taskId)
        }
    }
}

private struct TaskRow: View {
    let projectTask: ProjectTask
    let isExpanded: Bool
    let isSaving: Bool
    let onToggleExpanded: () -> Void
    let onToggleComplete: (Bool) -> Void
    let onEdit: () -> Void
    let onAddSubtask: () -> Void
    let onDelete: () -> Void
    let onToggleSubtask: (ProjectSubtask, Bool) -> Void
    let onDeleteSubtask: (ProjectSubtask) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                CheckboxToggle(isOn: Binding(get: { projectTask.isCompleted }, set: onToggleComplete)) {
                    EmptyView()
                }
                .disabled(isSaving)

                VStack(alignment: .leading, spacing: 4) {
                    Text(projectTask.title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(AppColors.text)
                        .strikethrough(projectTask.isCompleted)
                    if !projectTask.assigneeEmail.isEmpty {
                        Text(projectTask.assigneeEmail)
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    if !projectTask.subtasks.isEmpty {
                        Button(action: onToggleExpanded) {
                            Text(isExpanded ? "Hide subtasks (\(projectTask.subtasks.count))" : "Show subtasks (\(projectTask.subtasks.count))")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(AppColors.primary)
                        }
                    }
                }

                Spacer()

                Menu {
                    Button("Edit", action: onEdit)
                    Button("Add Subtask", action: onAddSubtask)
                    Button("Delete", role: .destructive, action: onDelete)
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(projectTask.subtasks) { subtask in
                        SubtaskRow(
                            subtask: subtask,
                            onToggle: { onToggleSubtask(subtask, $0) },
                            onDelete: { onDeleteSubtask(subtask) }
                        )
                    }
                }
                .padding(.leading, 28)
            }
        }
        .padding(.vertical, 6)
    }
}

private struct SubtaskRow: View {
    let subtask: ProjectSubtask
    let onToggle: (Bool) -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            CheckboxToggle(isOn: Binding(get: { subtask.isCompleted }, set: onToggle)) {
                Text(subtask.title)
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.text)
                    .strikethrough(subtask.isCompleted)
            }
            Spacer()
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textSecondary)
            }
        }
    }
}
