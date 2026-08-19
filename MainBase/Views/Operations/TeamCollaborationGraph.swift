import SwiftUI

/// Team-collaboration view: an undirected network of teammates, drawn in a vertically-elongated
/// ring (an oval, not a circle) with a line between any two people who've shared a project —
/// thicker and more opaque the more projects they've shared. Static sample data for now.
struct TeamCollaborationGraph: View {
    var title = "Team Collaboration"
    var subtitle = "Who's worked together, weighted by shared projects"
    var people = CollaborationSample.people
    var edges = CollaborationSample.edges

    @State private var zoom: CGFloat = 1

    private let ringRadiusX: CGFloat = 140
    private let ringRadiusY: CGFloat = 260
    private let nodeRadius: CGFloat = 32
    /// Room below each avatar circle for its name label, included in the canvas bounding box.
    private let labelMargin: CGFloat = 24
    /// A floor on canvas width so a very small team (e.g. two people, who'd otherwise land directly
    /// above/below each other) doesn't collapse into an unreadably narrow strip.
    private let minCanvasWidth: CGFloat = 220

    /// Positions around the ellipse relative to an arbitrary (0,0) center — not yet placed inside a
    /// canvas. `positions` shifts these into the tight, positive-coordinate canvas below.
    private var rawPositions: [String: CGPoint] {
        let angles = RadialLayout.angles(count: people.count, startAngle: -.pi / 2)
        let points = angles.map { RadialLayout.pointOnEllipse(center: .zero, radiusX: ringRadiusX, radiusY: ringRadiusY, angle: $0) }
        return Dictionary(uniqueKeysWithValues: zip(people.map(\.id), points))
    }

    /// Sized to the ring's own bounding box (node diameter + label below each avatar), so a small
    /// team's compact graph doesn't sit lost in an oversized canvas.
    private var canvasSize: CGSize {
        let points = Array(rawPositions.values)
        guard let minX = points.map(\.x).min(), let minY = points.map(\.y).min(),
              let maxX = points.map(\.x).max(), let maxY = points.map(\.y).max() else {
            return CGSize(width: minCanvasWidth, height: minCanvasWidth)
        }
        return CGSize(width: max(maxX - minX + nodeRadius * 2, minCanvasWidth),
                      height: maxY - minY + nodeRadius * 2 + labelMargin)
    }

    private var positions: [String: CGPoint] {
        let points = Array(rawPositions.values)
        guard let minX = points.map(\.x).min(), let minY = points.map(\.y).min() else { return rawPositions }
        let offsetX = max(nodeRadius, (canvasSize.width - (points.map(\.x).max()! - minX)) / 2) - minX
        let offsetY = nodeRadius - minY
        return rawPositions.mapValues { CGPoint(x: $0.x + offsetX, y: $0.y + offsetY) }
    }

    private func person(_ id: String) -> TeamPerson { people.first { $0.id == id }! }

    /// The point on a node's own circle facing the other node, so the line stops at the avatar's
    /// edge instead of running underneath it.
    private func anchor(from center: CGPoint, toward other: CGPoint) -> CGPoint {
        let dx = other.x - center.x, dy = other.y - center.y
        let length = max(hypot(dx, dy), 0.001)
        return CGPoint(x: center.x + dx / length * nodeRadius, y: center.y + dy / length * nodeRadius)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            heading.padding([.horizontal, .top], 20)
            legend.padding(.horizontal, 20)
            diagram.zoomableCanvas(zoom: $zoom, canvasSize: canvasSize)
        }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(AppColors.text)
            Text(subtitle)
                .font(.system(size: 13))
                .foregroundColor(AppColors.textSecondary)
        }
    }

    private var legend: some View {
        HStack(spacing: 18) {
            HStack(spacing: 6) {
                Rectangle().fill(AppColors.textSecondary.opacity(0.35)).frame(width: 20, height: 1.5)
                Text("1 project").font(.system(size: 12, weight: .medium)).foregroundColor(AppColors.textSecondary)
            }
            HStack(spacing: 6) {
                Rectangle().fill(AppColors.textSecondary.opacity(0.8)).frame(width: 20, height: 3)
                Text("2+ projects").font(.system(size: 12, weight: .medium)).foregroundColor(AppColors.textSecondary)
            }
        }
    }

    private var diagram: some View {
        ZStack {
            Canvas { context, _ in
                for edge in edges {
                    let a = positions[edge.from]!
                    let b = positions[edge.to]!
                    DiagramDraw.relationship(&context,
                                             from: anchor(from: a, toward: b),
                                             to: anchor(from: b, toward: a),
                                             color: AppColors.textSecondary.opacity(edge.weight >= 2 ? 0.8 : 0.35),
                                             lineWidth: edge.weight >= 2 ? 3 : 1.5,
                                             axis: .horizontal)
                }
            }
            .frame(width: canvasSize.width, height: canvasSize.height)

            ForEach(people) { person in
                personBubble(person).position(positions[person.id]!)
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
    }

    private func personBubble(_ person: TeamPerson) -> some View {
        VStack(spacing: 6) {
            Text(person.emoji)
                .font(.system(size: 28))
                .frame(width: nodeRadius * 2, height: nodeRadius * 2)
                .background(Circle().fill(person.tint.opacity(0.18)))
                .overlay(Circle().stroke(person.tint, lineWidth: 2))
            Text(person.firstName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(AppColors.text)
        }
    }
}

/// A teammate node in the collaboration graph.
struct TeamPerson: Identifiable {
    let id: String
    let firstName: String
    let emoji: String
    let tint: Color
}

/// An undirected connection between two teammates, weighted by how many projects they share.
struct CollaborationEdge: Identifiable {
    let id = UUID()
    let from: String
    let to: String
    let weight: Int
}

/// Static sample data: eight teammates and how many projects each pair has shared.
enum CollaborationSample {
    static let people: [TeamPerson] = [
        TeamPerson(id: "alex", firstName: "Alex", emoji: "🌵", tint: Color(hex: "#007AFF")),
        TeamPerson(id: "chloe", firstName: "Chloe", emoji: "🎨", tint: Color(hex: "#FF3B30")),
        TeamPerson(id: "sarah", firstName: "Sarah", emoji: "☕️", tint: Color(hex: "#34C759")),
        TeamPerson(id: "priya", firstName: "Priya", emoji: "🌸", tint: Color(hex: "#AF52DE")),
        TeamPerson(id: "nora", firstName: "Nora", emoji: "🌺", tint: Color(hex: "#FF9500")),
        TeamPerson(id: "marcus", firstName: "Marcus", emoji: "🚀", tint: Color(hex: "#5856D6")),
        TeamPerson(id: "hannah", firstName: "Hannah", emoji: "🎿", tint: Color(hex: "#00B8A9")),
        TeamPerson(id: "diego", firstName: "Diego", emoji: "⚽️", tint: Color(hex: "#5AC8FA")),
    ]

    static let edges: [CollaborationEdge] = [
        CollaborationEdge(from: "sarah", to: "alex", weight: 1),
        CollaborationEdge(from: "sarah", to: "chloe", weight: 2),
        CollaborationEdge(from: "sarah", to: "priya", weight: 1),
        CollaborationEdge(from: "sarah", to: "diego", weight: 1),
        CollaborationEdge(from: "alex", to: "chloe", weight: 2),
        CollaborationEdge(from: "alex", to: "priya", weight: 1),
        CollaborationEdge(from: "alex", to: "nora", weight: 2),
        CollaborationEdge(from: "alex", to: "marcus", weight: 1),
        CollaborationEdge(from: "alex", to: "hannah", weight: 1),
        CollaborationEdge(from: "chloe", to: "priya", weight: 1),
        CollaborationEdge(from: "chloe", to: "nora", weight: 1),
        CollaborationEdge(from: "chloe", to: "diego", weight: 1),
        CollaborationEdge(from: "nora", to: "priya", weight: 1),
        CollaborationEdge(from: "marcus", to: "hannah", weight: 2),
        CollaborationEdge(from: "marcus", to: "diego", weight: 1),
    ]
}

#Preview {
    TeamCollaborationGraph()
        .background(AppColors.background)
}
