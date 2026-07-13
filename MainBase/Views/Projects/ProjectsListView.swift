import SwiftUI

struct ProjectsListView: View {
    @StateObject private var vm = ProjectsViewModel()
    @State private var showingAddProject = false
    @State private var showingArchives = false
    @State private var editingProject: Project?
    @State private var projectPendingDelete: Project?

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoadingProjects && vm.projects.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if vm.projects.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(vm.projects) { project in
                            NavigationLink(value: project.id) {
                                ProjectRow(project: project)
                            }
                            .listRowBackground(AppColors.cardBackground)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                if vm.canDelete(project) {
                                    Button(role: .destructive) {
                                        projectPendingDelete = project
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }

                                if vm.canEditOrArchive(project) {
                                    Button {
                                        Task { await vm.archiveProject(projectId: project.id) }
                                    } label: {
                                        Label("Archive", systemImage: "archivebox")
                                    }
                                    .tint(.orange)

                                    Button {
                                        editingProject = project
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .listRowSeparatorTint(AppColors.border)
                    .refreshable { await vm.loadProjects() }
                }
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Projects")
            .navigationDestination(for: String.self) { projectId in
                if let project = vm.projects.first(where: { $0.id == projectId }) {
                    ProjectDetailView(project: project, vm: vm)
                }
            }
            .toolbar {
                if vm.currentUserIsAdmin {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            showingArchives = true
                        } label: {
                            Image(systemName: "archivebox")
                        }
                        .accessibilityLabel("Show Archives")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddProject = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .task { await vm.loadProjects() }
        .sheet(isPresented: $showingAddProject) {
            AddProjectSheet(vm: vm)
        }
        .sheet(item: $editingProject) { project in
            EditProjectSheet(vm: vm, project: project)
        }
        .sheet(isPresented: $showingArchives) {
            ArchivedProjectsView(vm: vm)
        }
        .confirmationDialog(
            "Delete \(projectPendingDelete?.projectTitle ?? "this project")?",
            isPresented: Binding(
                get: { projectPendingDelete != nil },
                set: { isPresented in if !isPresented { projectPendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let project = projectPendingDelete {
                    Task { await vm.deleteProject(projectId: project.id) }
                }
                projectPendingDelete = nil
            }
            Button("Cancel", role: .cancel) { projectPendingDelete = nil }
        } message: {
            Text("This will permanently delete the project and all of its tasks.")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "folder")
                .font(.system(size: 36))
                .foregroundColor(AppColors.textSecondary)
            Text("No projects yet")
                .font(.system(size: 15))
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ProjectRow: View {
    let project: Project

    private var completedTaskCount: Int {
        project.tasks.filter { $0.isCompleted }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                Text(project.projectTitle)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.text)
                Spacer()
                StatusBadge(status: project.status)
            }
            if !project.projectDescription.isEmpty {
                DescriptionText(text: project.projectDescription, lineLimit: 2)
            }
            Text("\(completedTaskCount)/\(project.tasks.count) tasks complete")
                .font(.system(size: 13))
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(.vertical, 8)
    }
}

struct StatusBadge: View {
    let status: ProjectStatus

    var body: some View {
        Text(status == .completed ? "Completed" : "In Progress")
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(status == .completed ? .white : AppColors.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(status == .completed ? AppColors.primary : AppColors.primary.opacity(0.12))
            .clipShape(Capsule())
    }
}

#Preview {
    ProjectsListView()
}
