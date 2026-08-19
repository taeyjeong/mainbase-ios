import SwiftUI

/// Roadmap-tree view: initiatives grouped by team, redrawn as a mind map — lanes branch from the
/// product at the center, and each lane's initiatives hang off it as leaves colored by delivery
/// status rather than by lane, so status reads at a glance. Static sample data for now.
struct RoadmapTreeDiagram: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            MindMapDiagram(title: "Roadmap Tree",
                           subtitle: "Initiatives grouped by team",
                           rootTitle: "Roadmap",
                           rootIcon: "map.fill",
                           branches: RoadmapTreeSample.branches)
            legend
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
        }
    }

    private var legend: some View {
        HStack(spacing: 16) {
            ForEach(RoadmapStatus.allCases, id: \.self) { status in
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 3).fill(status.color).frame(width: 12, height: 12)
                    Text(status.rawValue)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
    }
}

/// Delivery status of a roadmap initiative, used to tint its leaf in the tree.
enum RoadmapStatus: String, CaseIterable {
    case planned = "Planned"
    case inProgress = "In Progress"
    case shipped = "Shipped"

    var color: Color {
        switch self {
        case .planned: return Color(hex: "#8E8E93")
        case .inProgress: return Color(hex: "#FF9500")
        case .shipped: return Color(hex: "#34C759")
        }
    }
}

private struct RoadmapInitiative {
    let id: String
    let title: String
    let status: RoadmapStatus
}

private struct RoadmapLane {
    let id: String
    let name: String
    let emoji: String
    let initiatives: [RoadmapInitiative]
}

enum RoadmapTreeSample {
    /// One muted tint per lane, distinct from the `RoadmapStatus` colors so a lane's trunk
    /// never gets mistaken for a status.
    private static let laneTints: [Color] = [
        Color(hex: "#5856D6"), Color(hex: "#8E8E93"), Color(hex: "#FF2D55"), Color(hex: "#5AC8FA"),
    ]

    private static let lanes: [RoadmapLane] = [
        RoadmapLane(id: "platform", name: "Platform", emoji: "⚙️", initiatives: [
            RoadmapInitiative(id: "auth", title: "SSO Login", status: .shipped),
            RoadmapInitiative(id: "sync", title: "Offline Sync", status: .inProgress),
            RoadmapInitiative(id: "perf", title: "Startup Perf", status: .planned),
        ]),
        RoadmapLane(id: "projects", name: "Projects", emoji: "📁", initiatives: [
            RoadmapInitiative(id: "diagrams", title: "Diagram Builder", status: .inProgress),
            RoadmapInitiative(id: "budgets", title: "Budget Alerts", status: .planned),
        ]),
        RoadmapLane(id: "growth", name: "Growth", emoji: "📈", initiatives: [
            RoadmapInitiative(id: "referrals", title: "Referral Program", status: .planned),
            RoadmapInitiative(id: "onboarding", title: "Onboarding Revamp", status: .shipped),
        ]),
        RoadmapLane(id: "ops", name: "Ops", emoji: "🛠️", initiatives: [
            RoadmapInitiative(id: "scheduling", title: "Auto Scheduling", status: .inProgress),
            RoadmapInitiative(id: "reporting", title: "Report Digests", status: .planned),
        ]),
    ]

    static let branches: [MindMapBranch] = lanes.enumerated().map { index, lane in
        MindMapBranch(id: lane.id, title: lane.name, emoji: lane.emoji,
                     tint: laneTints[index % laneTints.count],
                     leaves: lane.initiatives.map { initiative in
            MindMapLeaf(id: initiative.id, title: initiative.title, tint: initiative.status.color)
        })
    }
}

#Preview {
    RoadmapTreeDiagram()
        .background(AppColors.background)
}
