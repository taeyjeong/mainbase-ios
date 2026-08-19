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
    /// The Operations tab's segmented picker is kept to these three for now — the other three
    /// (Team Collaboration Graph, Feature Tree, Roadmap Tree) render sample data too, but only
    /// via the "Add Diagram" picker's preview until they're worth a permanent tab here.
    private static let implementedKinds: [OperationsDiagramKind] = [.workflow, .userFlow, .database]

    @State private var selection: OperationsDiagramKind = .workflow

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("View", selection: $selection) {
                    ForEach(Self.implementedKinds) { kind in
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
                    case .teamGraph: TeamCollaborationGraph()
                    case .featureTree: FeatureTreeDiagram()
                    case .roadmapTree: RoadmapTreeDiagram()
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

/// The six diagram kinds offered when creating a project diagram. Only `workflow`, `userFlow`,
/// and `database` have a working view (rendered on the Operations tab); the other three are
/// listed in the "Add Diagram" picker but not yet buildable — see `AddDiagramFlowSheet`.
enum OperationsDiagramKind: String, CaseIterable, Identifiable {
    case workflow
    case userFlow
    case database
    case teamGraph
    case featureTree
    case roadmapTree

    var id: String { rawValue }

    var title: String {
        switch self {
        case .workflow: return "Workflow"
        case .userFlow: return "User Flow"
        case .database: return "Database"
        case .teamGraph: return "Team Collaboration Graph"
        case .featureTree: return "Feature Tree"
        case .roadmapTree: return "Roadmap Tree"
        }
    }

    var icon: String {
        switch self {
        case .workflow: return "arrow.triangle.branch"
        case .userFlow: return "rectangle.on.rectangle"
        case .database: return "cylinder.split.1x2"
        case .teamGraph: return "person.2.fill"
        case .featureTree: return "list.bullet.indent"
        case .roadmapTree: return "map.fill"
        }
    }

    var tint: Color {
        switch self {
        case .workflow: return AppColors.primary
        case .userFlow: return Color(hex: "#5856D6")
        case .database: return Color(hex: "#8E8E93")
        case .teamGraph: return Color(hex: "#FF9500")
        case .featureTree: return Color(hex: "#34C759")
        case .roadmapTree: return Color(hex: "#AF52DE")
        }
    }

    var blurb: String {
        switch self {
        case .workflow: return "A step-by-step automation — triggers, conditions, and actions connected by arrows."
        case .userFlow: return "How people navigate between screens in an app, from launch to their destination."
        case .database: return "An entity-relationship schema — tables, columns, and how they connect."
        case .teamGraph: return "A network of who's worked with whom, weighted by shared projects."
        case .featureTree: return "A mind map breaking a product down into features and capabilities."
        case .roadmapTree: return "A mind map of initiatives grouped by team, colored by delivery status."
        }
    }
}

#Preview {
    OperationsDiagramsView()
}
