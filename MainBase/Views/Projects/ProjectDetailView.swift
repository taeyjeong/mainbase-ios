import Combine
import PhotosUI
import SwiftUI

struct ProjectDetailView: View {
    let project: Project
    @ObservedObject var vm: ProjectsViewModel

    @State private var expandedTaskIds: Set<String> = []
    @State private var taskToEdit: ProjectTask?
    @State private var savingTaskIds: Set<String> = []
    @State private var savingSubtaskIds: Set<String> = []
    @State private var addingSubtaskTaskIds: Set<String> = []
    @State private var isAddingTask = false
    @State private var isEditingDescription = false
    @State private var descriptionDraft = ""
    @State private var isSavingDescription = false
    @State private var errorMessage: String?
    @State private var now = Date()
    @State private var showingGallery = false
    @State private var showingChat = false
    @State private var showingAddDiagram = false
    @Environment(\.colorScheme) private var colorScheme

    private let clockTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private var currentProject: Project {
        vm.projects.first(where: { $0.id == project.id }) ?? project
    }

    private var detailBackgroundColor: Color {
        guard let main = vm.projectMain(withId: currentProject.projectMainId) else {
            return AppColors.background
        }
        let mainColor = Color(hex: main.colorHex)
        return colorScheme == .dark ? mainColor.darkened(by: 0.75) : mainColor.lightened(by: 0.85)
    }

    var body: some View {
        List {
            Section {
                ProjectPhotoCarousel(projectId: project.id, photoURLs: currentProject.photoURLs, vm: vm)
                    .listRowInsets(EdgeInsets())
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    if isEditingDescription {
                        TextField("Description", text: $descriptionDraft, axis: .vertical)
                            .font(.system(size: 15))
                            .lineLimit(3...8)
                            .inputFieldStyle()
                        HStack(spacing: 16) {
                            Spacer()
                            Button("Cancel") { isEditingDescription = false }
                                .buttonStyle(.borderless)
                                .foregroundColor(AppColors.textSecondary)
                            if isSavingDescription {
                                ProgressView().scaleEffect(0.8)
                            } else {
                                Button("Save") { Task { await saveDescription() } }
                                    .buttonStyle(.borderless)
                                    .foregroundColor(AppColors.primary)
                            }
                        }
                        .font(.system(size: 14, weight: .semibold))
                    } else if currentProject.projectDescription.isEmpty {
                        if canEditProject {
                            Text("Add a description…")
                                .font(.system(size: 15))
                                .foregroundColor(AppColors.textSecondary)
                        }
                    } else {
                        DescriptionText(text: currentProject.projectDescription)
                    }

                    Text("Lead: \(vm.displayName(forEmail: currentProject.projectLead))")
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    guard canEditProject, !isEditingDescription else { return }
                    descriptionDraft = currentProject.projectDescription
                    isEditingDescription = true
                }
                .listRowBackground(AppColors.cardBackground)
            }

            ProjectBudgetSection(projectId: project.id, budget: currentProject.budget, vm: vm)

            Section {
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
                        isAddingSubtaskSaving: addingSubtaskTaskIds.contains(projectTask.id),
                        onToggleExpanded: { toggleExpanded(projectTask.id) },
                        onToggleComplete: { isCompleted in
                            performTaskAction(taskId: projectTask.id) {
                                await vm.submitToggleTaskCompletion(projectId: project.id, taskId: projectTask.id, isCompleted: isCompleted)
                            }
                        },
                        onAddSubtask: { title in
                            await performAddSubtask(taskId: projectTask.id, title: title)
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
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            performTaskAction(taskId: projectTask.id) {
                                await vm.submitDeleteTask(projectId: project.id, taskId: projectTask.id)
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }

                        if vm.canManage(projectId: project.id, assigneeEmail: projectTask.assigneeEmail) {
                            Button {
                                taskToEdit = projectTask
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                    }
                }

                QuickAddRow(placeholder: "New task", isSaving: isAddingTask) { title in
                    await addTaskInline(title)
                }
                .listRowBackground(AppColors.cardBackground)
            } header: {
                HStack {
                    Text("Tasks")
                    Spacer()
                }
            }

            ProjectDiagramsSection(showingAddDiagram: $showingAddDiagram)
        }
        .listStyle(.plain)
        .overlay(alignment: .bottomTrailing) {
            Button {
                showingChat = true
            } label: {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.white)
                    .frame(width: 58, height: 58)
                    .background(Circle().fill(AppColors.primary))
                    .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 20)
            .accessibilityLabel("Open team chat")
        }
        .onReceive(clockTimer) { now = $0 }
        .background(detailBackgroundColor.ignoresSafeArea())
        .navigationTitle(currentProject.projectTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingGallery = true
                } label: {
                    Image(systemName: "photo.stack")
                }
                .accessibilityLabel("View all photos")
            }
        }
        .sheet(item: $taskToEdit) { editingTask in
            EditTaskSheet(vm: vm, projectId: project.id, projectTask: editingTask)
        }
        .sheet(isPresented: $showingChat) {
            ProjectChatView(projectId: project.id, teamMembers: currentProject.teamMembers, vm: vm)
        }
        .sheet(isPresented: $showingGallery) {
            ProjectPhotoGalleryView(projectId: project.id, vm: vm)
        }
        .sheet(isPresented: $showingAddDiagram) {
            AddDiagramFlowSheet()
        }
        .alert("Error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .onAppear {
            vm.startChatListener(projectId: project.id)
            vm.startExpensesListener(projectId: project.id)
        }
        .onDisappear {
            vm.stopChatListener()
            vm.stopExpensesListener()
        }
    }

    private var canEditProject: Bool {
        vm.canEditOrArchive(currentProject)
    }

    private func saveDescription() async {
        isSavingDescription = true
        let result = await vm.updateProjectDescription(projectId: project.id, description: descriptionDraft)
        isSavingDescription = false
        if result.success {
            isEditingDescription = false
        } else {
            errorMessage = result.error
        }
    }

    private func addTaskInline(_ title: String) async -> Bool {
        isAddingTask = true
        let result = await vm.submitAddTask(projectId: project.id, title: title, assigneeEmail: "")
        isAddingTask = false
        if !result.success { errorMessage = result.error }
        return result.success
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

    /// Adds a subtask inline, unassigned, and expands the task's subtask list so the
    /// newly added one is immediately visible.
    private func performAddSubtask(taskId: String, title: String) async -> Bool {
        addingSubtaskTaskIds.insert(taskId)
        let result = await vm.submitAddSubtask(projectId: project.id, taskId: taskId, title: title, assigneeEmail: "")
        addingSubtaskTaskIds.remove(taskId)
        if result.success {
            expandedTaskIds.insert(taskId)
        } else {
            errorMessage = result.error
        }
        return result.success
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
    let isAddingSubtaskSaving: Bool
    let onToggleExpanded: () -> Void
    let onToggleComplete: (Bool) -> Void
    let onAddSubtask: (String) async -> Bool
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
                    if !projectTask.subtasks.isEmpty {
                        Button(action: onToggleExpanded) {
                            Text(isExpanded ? "Hide subtasks (\(projectTask.subtasks.count))" : "Show subtasks (\(projectTask.subtasks.count))")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(AppColors.primary)
                        }
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    if let durationText {
                        Text(durationText)
                            .font(.system(size: 11))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    if !projectTask.assigneeEmail.isEmpty {
                        Text(displayName(projectTask.assigneeEmail))
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }

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

            QuickAddRow(placeholder: "Add subtask", isSaving: isAddingSubtaskSaving, onAdd: onAddSubtask)
                .padding(.leading, 28)
        }
        .padding(.vertical, 6)
    }

    private var durationText: String? {
        guard let createdAt = projectTask.createdAt else { return nil }
        if projectTask.isCompleted {
            guard let completedAt = projectTask.completedAt else { return nil }
            return "Took \(DurationFormatting.daysHours(from: createdAt, to: completedAt))"
        } else {
            guard now.timeIntervalSince(createdAt) >= taskTimerRevealThreshold else { return nil }
            return "\(DurationFormatting.daysHours(from: createdAt, to: now)) since created"
        }
    }
}

/// The live "since created" counter only appears once a task/subtask has been open this long,
/// so brand-new items don't show noisy timers. Completed items' "Took Xd Yh" summary always shows.
private let taskTimerRevealThreshold: TimeInterval = 3 * 24 * 3600

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
            guard now.timeIntervalSince(createdAt) >= taskTimerRevealThreshold else { return nil }
            return "\(DurationFormatting.daysHours(from: createdAt, to: now)) since created"
        }
    }
}

/// A compact, always-visible "type a title and tap +" row for adding tasks and subtasks inline —
/// no sheet. The Add button uses `.borderless` so its tap registers reliably inside a `List` row
/// (a plain Button there can otherwise fail to fire). Clears itself once `onAdd` reports success.
struct QuickAddRow: View {
    let placeholder: String
    var isSaving: Bool = false
    let onAdd: (String) async -> Bool

    @State private var text = ""

    private var trimmed: String { text.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        HStack(spacing: 8) {
            TextField(placeholder, text: $text)
                .font(.system(size: 14))
                .foregroundColor(AppColors.text)
                .submitLabel(.done)
                .disabled(isSaving)
                .onSubmit(submit)

            if isSaving {
                ProgressView().scaleEffect(0.7)
            } else {
                Button(action: submit) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(trimmed.isEmpty ? AppColors.textSecondary.opacity(0.4) : AppColors.primary)
                }
                .buttonStyle(.borderless)
                .disabled(trimmed.isEmpty)
            }
        }
    }

    private func submit() {
        let value = trimmed
        guard !value.isEmpty, !isSaving else { return }
        Task {
            let success = await onAdd(value)
            if success { text = "" }
        }
    }
}
