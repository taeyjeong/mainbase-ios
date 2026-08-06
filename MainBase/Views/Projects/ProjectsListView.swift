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
                                ProjectRow(
                                    project: project,
                                    main: vm.projectMain(withId: project.projectMainId),
                                    teamMemberTag: vm.teamMemberTag(forEmail:)
                                )
                            }
                            .buttonStyle(.plain)
                            .navigationLinkIndicatorVisibility(.hidden)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
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
                    .refreshable { await vm.loadProjects() }
                }
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Projects")
            .navigationBarTitleDisplayMode(.inline)
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

private let projectCardStartDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    return formatter
}()

private struct ProjectRow: View {
    let project: Project
    let main: ProjectMain?
    let teamMemberTag: (String) -> String

    private var completedTaskCount: Int {
        project.tasks.filter { $0.isCompleted }.count
    }

    private var percentComplete: Int {
        guard !project.tasks.isEmpty else { return 0 }
        return Int((Double(completedTaskCount) / Double(project.tasks.count) * 100).rounded())
    }

    private var cardColor: Color {
        guard let main else { return AppColors.textSecondary }
        return Color(hex: main.colorHex)
    }

    private var leadersMembersLine: String {
        var parts: [String] = ["Lead: \(teamMemberTag(project.projectLead))"]
        if !project.teamMembers.isEmpty {
            parts.append(project.teamMembers.map(teamMemberTag).joined(separator: ", "))
        }
        return parts.joined(separator: " • ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(project.projectTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    Text(main?.name ?? "Unassigned")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    if let createdAt = project.createdAt {
                        Text("🗓️ \(projectCardStartDateFormatter.string(from: createdAt))")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                    Text("\(completedTaskCount)/\(project.tasks.count) tasks")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                    Text("\(percentComplete)% complete")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.22))
                        .clipShape(Capsule())
                }
            }

            Text(leadersMembersLine)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(1)
                .truncationMode(.tail)

            if !project.sublabels.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(project.sublabels, id: \.self) { sublabel in
                            Text(sublabel)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.white.opacity(0.22))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(cardColor))
    }
}

#Preview {
    ProjectsListView()
}
