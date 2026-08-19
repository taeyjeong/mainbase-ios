import SwiftUI

/// The "Diagrams" section on a project's detail screen. There's no diagram data model or MVVM
/// layer wired up in MainBase yet, so this only exposes the "Add Diagram" picker (see
/// `AddDiagramFlowSheet`) — there are no saved diagrams to list.
struct ProjectDiagramsSection: View {
    @Binding var showingAddDiagram: Bool

    var body: some View {
        Section {
            Text("No diagrams yet — tap Add Diagram to create one.")
                .font(.system(size: 13))
                .foregroundColor(AppColors.textSecondary)
                .padding(.vertical, 10)
                .listRowBackground(AppColors.cardBackground)
        } header: {
            HStack {
                Text("Diagrams")
                Spacer()
                Button {
                    showingAddDiagram = true
                } label: {
                    Text("Add Diagram")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppColors.primary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
