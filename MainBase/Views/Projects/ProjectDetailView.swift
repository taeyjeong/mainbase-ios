import Combine
import SwiftUI

struct ProjectDetailView: View {
    let project: Project
    @ObservedObject var vm: ProjectsViewModel

    @State private var expandedTaskIds: Set<String> = []
    @State private var showingAddTask = false
    @State private var taskToEdit: ProjectTask?
    @State private var taskForSubtask: ProjectTask?
    @State private var savingTaskIds: Set<String> = []
    @State private var savingSubtaskIds: Set<String> = []
    @State private var errorMessage: String?
    @State private var now = Date()

    private let clockTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

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
                        now: now,
                        displayName: vm.displayName(forEmail:),
                        canManageTask: vm.canManage(projectId: project.id, assigneeEmail: projectTask.assigneeEmail),
                        canManageSubtask: { vm.canManage(projectId: project.id, assigneeEmail: $0.assigneeEmail) },
                        isExpanded: expandedTaskIds.contains(projectTask.id),
                        isSaving: savingTaskIds.contains(projectTask.id),
                        savingSubtaskIds: savingSubtaskIds,
                        onToggleExpanded: { toggleExpanded(projectTask.id) },
                        onToggleComplete: { isCompleted in
                            performTaskAction(taskId: projectTask.id) {
                                await vm.submitToggleTaskCompletion(projectId: project.id, taskId: projectTask.id, isCompleted: isCompleted)
                            }
                        },
                        onEdit: { taskToEdit = projectTask },
                        onAddSubtask: { taskForSubtask = projectTask },
                        onDelete: {
                            performTaskAction(taskId: projectTask.id) {
                                await vm.submitDeleteTask(projectId: project.id, taskId: projectTask.id)
                            }
                        },
                        onToggleSubtask: { subtask, isCompleted in
                            performSubtaskAction(subtaskId: subtask.id) {
                                await vm.submitCompleteSubtask(projectId: project.id, taskId: projectTask.id, subtaskId: subtask.id, isCompleted: isCompleted)
                            }
                        },
                        onDeleteSubtask: { subtask in
                            performSubtaskAction(subtaskId: subtask.id) {
                                await vm.submitDeleteSubtask(projectId: project.id, taskId: projectTask.id, subtaskId: subtask.id)
                            }
                        }
                    )
                    .listRowBackground(AppColors.cardBackground)
                }
            }
        }
        .listStyle(.plain)
        .onReceive(clockTimer) { now = $0 }
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
        .alert("Error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func toggleExpanded(_ taskId: String) {
        if expandedTaskIds.contains(taskId) {
            expandedTaskIds.remove(taskId)
        } else {
            expandedTaskIds.insert(taskId)
        }
    }

    private func performTaskAction(taskId: String, action: @escaping () async -> ProjectActionResult) {
        savingTaskIds.insert(taskId)
        Task {
            let result = await action()
            savingTaskIds.remove(taskId)
            if !result.success {
                errorMessage = result.error
            }
        }
    }

    private func performSubtaskAction(subtaskId: String, action: @escaping () async -> ProjectActionResult) {
        savingSubtaskIds.insert(subtaskId)
        Task {
            let result = await action()
            savingSubtaskIds.remove(subtaskId)
            if !result.success {
                errorMessage = result.error
            }
        }
    }
}

private struct TaskRow: View {
    let projectTask: ProjectTask
    let now: Date
    let displayName: (String) -> String
    let canManageTask: Bool
    let canManageSubtask: (ProjectSubtask) -> Bool
    let isExpanded: Bool
    let isSaving: Bool
    let savingSubtaskIds: Set<String>
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
                .disabled(isSaving || !canManageTask)

                VStack(alignment: .leading, spacing: 4) {
                    Text(projectTask.title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(AppColors.text)
                        .strikethrough(projectTask.isCompleted)
                    if !projectTask.assigneeEmail.isEmpty {
                        Text(displayName(projectTask.assigneeEmail))
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    if let durationText = durationText {
                        Text(durationText)
                            .font(.system(size: 11))
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
                    if canManageTask {
                        Button("Edit", action: onEdit)
                    }
                    Button("Delete", role: .destructive, action: onDelete)
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            Button(action: onAddSubtask) {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                    Text("Add Subtask")
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppColors.primary)
            }
            .padding(.leading, 28)

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(projectTask.subtasks) { subtask in
                        SubtaskRow(
                            subtask: subtask,
                            now: now,
                            displayName: displayName,
                            canComplete: canManageSubtask(subtask),
                            isSaving: savingSubtaskIds.contains(subtask.id),
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

    private var durationText: String? {
        guard let createdAt = projectTask.createdAt else { return nil }
        if projectTask.isCompleted {
            guard let completedAt = projectTask.completedAt else { return nil }
            return "Took \(DurationFormatting.daysHours(from: createdAt, to: completedAt))"
        } else {
            return "\(DurationFormatting.daysHours(from: createdAt, to: now)) since created"
        }
    }
}

private struct SubtaskRow: View {
    let subtask: ProjectSubtask
    let now: Date
    let displayName: (String) -> String
    let canComplete: Bool
    let isSaving: Bool
    let onToggle: (Bool) -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            CheckboxToggle(isOn: Binding(get: { subtask.isCompleted }, set: onToggle)) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(subtask.title)
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.text)
                        .strikethrough(subtask.isCompleted)
                    if !subtask.assigneeEmail.isEmpty {
                        Text(displayName(subtask.assigneeEmail))
                            .font(.system(size: 11))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    if let durationText = durationText {
                        Text(durationText)
                            .font(.system(size: 11))
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
            .disabled(isSaving || !canComplete)
            Spacer()
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textSecondary)
            }
        }
    }

    private var durationText: String? {
        guard let createdAt = subtask.createdAt else { return nil }
        if subtask.isCompleted {
            guard let completedAt = subtask.completedAt else { return nil }
            return "Took \(DurationFormatting.daysHours(from: createdAt, to: completedAt))"
        } else {
            return "\(DurationFormatting.daysHours(from: createdAt, to: now)) since created"
        }
    }
}
