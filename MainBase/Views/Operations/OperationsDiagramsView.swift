import SwiftUI

// MARK: - ⚠️ MOCK DATA REMINDER
// This Operations tab (this file plus DiagramSupport, WorkflowAutomationDiagram,
// UserFlowDiagram, and DatabaseDesignDiagram) was copied over from the Meili app. Every
// diagram here renders STATIC SAMPLE DATA — see the `WorkflowSample`, `UserFlowSample`, and
// `SchemaSample` enums in the sibling files. Real MainBase data will replace these mocks later;
// swap those sample enums for live data sources when that work happens.

/// The Operations tab. Hosts three connected-line diagrams — a workflow automation graph, an app
/// user flow, and a database schema — switched between with a segmented picker. Each diagram is
/// static sample data that draws its own nodes and routes connectors between them.
struct OperationsDiagramsView: View {
    @State private var selection: OperationsDiagramKind = .workflow

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("View", selection: $selection) {
                    ForEach(OperationsDiagramKind.allCases) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 8)

                Divider().overlay(AppColors.border)

                Group {
                    switch selection {
                    case .workflow: WorkflowAutomationDiagram()
                    case .userFlow: UserFlowDiagram()
                    case .database: DatabaseDesignDiagram()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Operations")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

/// The three diagram views selectable in the Operations tab.
enum OperationsDiagramKind: String, CaseIterable, Identifiable {
    case workflow
    case userFlow
    case database

    var id: String { rawValue }

    var title: String {
        switch self {
        case .workflow: return "Workflow"
        case .userFlow: return "User Flow"
        case .database: return "Database"
        }
    }
}

#Preview {
    OperationsDiagramsView()
}
