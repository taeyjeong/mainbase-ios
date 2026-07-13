import SwiftUI

struct ArchivedProjectsView: View {
    @ObservedObject var vm: ProjectsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoadingArchivedProjects && vm.archivedProjects.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if vm.archivedProjects.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(vm.archivedProjects) { project in
                            ArchivedProjectRow(project: project, leadName: vm.displayName(forEmail: project.projectLead))
                                .listRowBackground(AppColors.cardBackground)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button {
                                        Task { await vm.unarchiveProject(projectId: project.id) }
                                    } label: {
                                        Label("Recover", systemImage: "arrow.uturn.backward")
                                    }
                                    .tint(.green)
                                }
                        }
                    }
                    .listStyle(.plain)
                    .listRowSeparatorTint(AppColors.border)
                    .refreshable { await vm.loadArchivedProjects() }
                }
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Archived Projects")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task { await vm.loadArchivedProjects() }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "archivebox")
                .font(.system(size: 36))
                .foregroundColor(AppColors.textSecondary)
            Text("No archived projects")
                .font(.system(size: 15))
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ArchivedProjectRow: View {
    let project: Project
    let leadName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(project.projectTitle)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppColors.text)
            if !project.projectDescription.isEmpty {
                Text(project.projectDescription)
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(2)
            }
            Text("Lead: \(leadName)")
                .font(.system(size: 13))
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    ArchivedProjectsView(vm: ProjectsViewModel())
}
