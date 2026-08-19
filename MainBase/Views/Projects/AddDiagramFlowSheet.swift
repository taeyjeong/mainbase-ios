import SwiftUI

/// The "Add Diagram" picker: lists all six diagram kinds with their icon, title, and blurb.
/// Tapping a kind opens a full-screen sample of what that kind looks like — the same view
/// rendered on the Operations tab, fully pannable and pinch-zoomable. The "Create" button on that
/// preview is disabled for now — none of these kinds has an MVVM/data layer wired up yet in
/// MainBase, so this flow previews the picker + sample UI only, not a working creation flow.
struct AddDiagramFlowSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var previewingKind: OperationsDiagramKind?

    var body: some View {
        NavigationStack {
            List {
                ForEach(OperationsDiagramKind.allCases) { kind in
                    Button {
                        previewingKind = kind
                    } label: {
                        kindRow(kind)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(AppColors.cardBackground)
                }
            }
            .listStyle(.plain)
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Add Diagram")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(item: $previewingKind) { kind in
                DiagramSamplePreviewSheet(kind: kind)
            }
        }
    }

    private func kindRow(_ kind: OperationsDiagramKind) -> some View {
        HStack(spacing: 14) {
            Image(systemName: kind.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(RoundedRectangle(cornerRadius: 10).fill(kind.tint))

            VStack(alignment: .leading, spacing: 3) {
                Text(kind.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppColors.text)
                Text(kind.blurb)
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}

/// Full-screen sample of one diagram kind — the same view rendered on the Operations tab, so it's
/// pannable and pinch-zoomable via that view's own zoom controls. The "Create" bar at the bottom is
/// a preview of where a creation flow will eventually go; it's disabled until that kind has an
/// MVVM/data layer behind it.
private struct DiagramSamplePreviewSheet: View {
    let kind: OperationsDiagramKind
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            sample
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppColors.background.ignoresSafeArea())
                .safeAreaInset(edge: .bottom) {
                    Text("Create \(kind.title)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary.opacity(0.6))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 10).fill(AppColors.textSecondary.opacity(0.15)))
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                }
                .navigationTitle(kind.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }

    @ViewBuilder
    private var sample: some View {
        switch kind {
        case .workflow: WorkflowAutomationDiagram()
        case .userFlow: UserFlowDiagram()
        case .database: DatabaseDesignDiagram()
        case .teamGraph: TeamCollaborationGraph()
        case .featureTree: FeatureTreeDiagram()
        case .roadmapTree: RoadmapTreeDiagram()
        }
    }
}

#Preview {
    AddDiagramFlowSheet()
}
