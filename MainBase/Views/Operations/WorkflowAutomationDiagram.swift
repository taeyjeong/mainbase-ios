import SwiftUI

/// Workflow-automation view: a Zapier-style node graph where each step is a rounded "square" and
/// the steps are wired together with curved connectors and arrowheads. Static sample data — a lead
/// intake automation that branches on a condition and merges back into a logging step.
struct WorkflowAutomationDiagram: View {
    private let nodes = WorkflowSample.nodes
    private let edges = WorkflowSample.edges

    private let canvasSize = CGSize(width: 380, height: 590)
    private let lineColor = AppColors.textSecondary.opacity(0.55)

    private func node(_ id: String) -> WorkflowNode { nodes.first { $0.id == id }! }

    var body: some View {
        ScrollView([.horizontal, .vertical], showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                heading
                legend
                diagram
            }
            .padding(20)
        }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Lead Intake Automation")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(AppColors.text)
            Text("6 steps · runs on every form submission")
                .font(.system(size: 13))
                .foregroundColor(AppColors.textSecondary)
        }
    }

    private var legend: some View {
        HStack(spacing: 16) {
            ForEach(WorkflowNode.Kind.allCases, id: \.self) { kind in
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 3).fill(kind.color).frame(width: 12, height: 12)
                    Text(kind.label)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
    }

    private var diagram: some View {
        ZStack(alignment: .topLeading) {
            Canvas { context, _ in
                for edge in edges {
                    let connector = DiagramConnector(from: node(edge.from).rect.bottomAnchor,
                                                     to: node(edge.to).rect.topAnchor,
                                                     axis: .vertical)
                    DiagramDraw.arrow(&context, connector, color: lineColor)
                }
            }
            .frame(width: canvasSize.width, height: canvasSize.height)

            ForEach(edges.filter { $0.label != nil }) { edge in
                let mid = midpoint(from: node(edge.from).rect.bottomAnchor,
                                   to: node(edge.to).rect.topAnchor)
                Text(edge.label ?? "")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(AppColors.background))
                    .overlay(Capsule().stroke(AppColors.border, lineWidth: 1))
                    .position(mid)
            }

            ForEach(nodes) { node in
                nodeCard(node).position(node.center)
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
    }

    private func midpoint(from a: CGPoint, to b: CGPoint) -> CGPoint {
        CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
    }

    private func nodeCard(_ node: WorkflowNode) -> some View {
        HStack(spacing: 10) {
            Image(systemName: node.icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 34, height: 34)
                .background(RoundedRectangle(cornerRadius: 8).fill(node.kind.color))
            VStack(alignment: .leading, spacing: 2) {
                Text(node.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppColors.text)
                    .lineLimit(1)
                Text(node.subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .frame(width: node.size.width, height: node.size.height)
        .background(RoundedRectangle(cornerRadius: 12).fill(AppColors.cardBackground))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(node.kind.color.opacity(0.5), lineWidth: 1.5))
    }
}

/// One step in the workflow graph.
struct WorkflowNode: Identifiable {
    enum Kind: CaseIterable {
        case trigger, condition, action

        var color: Color {
            switch self {
            case .trigger: return Color(hex: "#34C759")
            case .condition: return Color(hex: "#FF9500")
            case .action: return AppColors.primary
            }
        }
        var label: String {
            switch self {
            case .trigger: return "Trigger"
            case .condition: return "Condition"
            case .action: return "Action"
            }
        }
    }

    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let kind: Kind
    let center: CGPoint

    var size: CGSize { CGSize(width: 156, height: 58) }
    var rect: CGRect { CGRect(center: center, size: size) }
}

/// A directed connection between two workflow nodes, optionally labeled (e.g. a branch outcome).
struct WorkflowEdge: Identifiable {
    let id = UUID()
    let from: String
    let to: String
    var label: String? = nil
}

/// Static sample data for the workflow-automation diagram.
enum WorkflowSample {
    static let nodes: [WorkflowNode] = [
        WorkflowNode(id: "trigger", title: "New Submission", subtitle: "Typeform",
                     icon: "square.and.pencil", kind: .trigger, center: CGPoint(x: 190, y: 46)),
        WorkflowNode(id: "filter", title: "Qualified Lead?", subtitle: "Filter · score ≥ 70",
                     icon: "arrow.triangle.branch", kind: .condition, center: CGPoint(x: 190, y: 156)),
        WorkflowNode(id: "crm", title: "Create Contact", subtitle: "HubSpot",
                     icon: "person.crop.circle.badge.plus", kind: .action, center: CGPoint(x: 100, y: 286)),
        WorkflowNode(id: "nurture", title: "Add to Nurture", subtitle: "Mailchimp",
                     icon: "envelope", kind: .action, center: CGPoint(x: 280, y: 286)),
        WorkflowNode(id: "slack", title: "Notify Sales", subtitle: "Slack",
                     icon: "bell.badge", kind: .action, center: CGPoint(x: 100, y: 396)),
        WorkflowNode(id: "log", title: "Log to Sheet", subtitle: "Google Sheets",
                     icon: "tablecells", kind: .action, center: CGPoint(x: 190, y: 516)),
    ]

    static let edges: [WorkflowEdge] = [
        WorkflowEdge(from: "trigger", to: "filter"),
        WorkflowEdge(from: "filter", to: "crm", label: "Yes"),
        WorkflowEdge(from: "filter", to: "nurture", label: "No"),
        WorkflowEdge(from: "crm", to: "slack"),
        WorkflowEdge(from: "slack", to: "log"),
        WorkflowEdge(from: "nurture", to: "log"),
    ]
}

#Preview {
    WorkflowAutomationDiagram()
        .background(AppColors.background)
}
