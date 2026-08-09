import Combine
import PhotosUI
import SwiftUI

struct ProjectDetailView: View {
    let project: Project
    @ObservedObject var vm: ProjectsViewModel

    @State private var expandedTaskIds: Set<String> = []
    @State private var showingAddTask = false
    @State private var taskToEdit: ProjectTask?
    @State private var savingTaskIds: Set<String> = []
    @State private var savingSubtaskIds: Set<String> = []
    @State private var addingSubtaskTaskIds: Set<String> = []
    @State private var errorMessage: String?
    @State private var now = Date()
    @State private var toolbarPhotoSelection: [PhotosPickerItem] = []
    @State private var isUploadingToolbarPhotos = false
    @State private var showingChat = false
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
                    if !currentProject.projectDescription.isEmpty {
                        DescriptionText(text: currentProject.projectDescription)
                    }
                    Text("Lead: \(vm.displayName(forEmail: currentProject.projectLead))")
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.textSecondary)
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
            } header: {
                HStack {
                    Text("Tasks")
                    Spacer()
                    Button {
                        showingAddTask = true
                    } label: {
                        Text("Add Task")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppColors.primary)
                    }
                }
            }

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
                if isUploadingToolbarPhotos {
                    ProgressView()
                } else {
                    PhotosPicker(selection: $toolbarPhotoSelection, matching: .images) {
                        Image(systemName: "photo.on.rectangle")
                    }
                }
            }
        }
        .onChange(of: toolbarPhotoSelection) { _, newItems in
            guard !newItems.isEmpty else { return }
            Task { await uploadToolbarPhotos(newItems) }
        }
        .sheet(isPresented: $showingAddTask) {
            AddTaskSheet(vm: vm, projectId: project.id)
        }
        .sheet(item: $taskToEdit) { editingTask in
            EditTaskSheet(vm: vm, projectId: project.id, projectTask: editingTask)
        }
        .sheet(isPresented: $showingChat) {
            ProjectChatView(projectId: project.id, teamMembers: currentProject.teamMembers, vm: vm)
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

    private func uploadToolbarPhotos(_ items: [PhotosPickerItem]) async {
        isUploadingToolbarPhotos = true
        let images = await loadImages(from: items)
        toolbarPhotoSelection = []
        if !images.isEmpty {
            let result = await vm.addPhotos(projectId: project.id, images: images)
            if !result.success { errorMessage = result.error }
        }
        isUploadingToolbarPhotos = false
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

            AddSubtaskInlineControl(isSaving: isAddingSubtaskSaving, onAdd: onAddSubtask)
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

/// Replaces the "Add Subtask" button with a text field in place; on submit the title is handed
/// off to `onAdd` and, once saved, the control resets back to the button so another can be added.
private struct AddSubtaskInlineControl: View {
    let isSaving: Bool
    let onAdd: (String) async -> Bool

    @State private var isEditing = false
    @State private var title = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        if isEditing {
            HStack(spacing: 8) {
                TextField("Subtask title", text: $title)
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.text)
                    .focused($isFocused)
                    .submitLabel(.done)
                    .disabled(isSaving)
                    .onSubmit { Task { await submit() } }

                if isSaving {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Button("Add") { Task { await submit() } }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.primary)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)

                    Button("Cancel") {
                        isEditing = false
                        title = ""
                    }
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textSecondary)
                }
            }
            .onAppear { isFocused = true }
        } else {
            Button {
                isEditing = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                    Text("Add Subtask")
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppColors.primary)
            }
        }
    }

    private func submit() async {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return }
        let success = await onAdd(trimmedTitle)
        if success {
            title = ""
            isEditing = false
        }
    }
}
