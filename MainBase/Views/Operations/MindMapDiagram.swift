import SwiftUI

/// Generic two-level radial mind map: a root node at the center, branches spaced evenly around it
/// on a vertically-elongated ellipse (not a circle), and each branch's leaves fanned further out on
/// a narrow arc centered on that branch's angle. Positions are computed from branch/leaf counts
/// alone — nothing is hand-placed — so any tree of this shape can reuse it (a feature breakdown, a
/// roadmap grouped by lane, ...).
struct MindMapDiagram: View {
    let title: String
    let subtitle: String
    let rootTitle: String
    let rootIcon: String
    let branches: [MindMapBranch]

    @State private var zoom: CGFloat = 1

    private let branchRadiusX: CGFloat = 130
    private let branchRadiusY: CGFloat = 210
    private let leafRadiusX: CGFloat = 190
    private let leafRadiusY: CGFloat = 300
    /// Alternated per leaf (as a scale on both radii) so adjacent leaves on the same branch sit at
    /// different distances from the center — otherwise their labels would crowd along a single ring.
    private let leafZigzagScale: CGFloat = 0.11
    private let anglePerLeaf: CGFloat = .pi / 12 // 15°
    /// Margin around the tree's bounding box reserved for node sizes (root circle, branch/leaf
    /// bubbles) which extend past their center point.
    private let nodeMargin: CGFloat = 70

    private var slice: CGFloat { 2 * .pi / CGFloat(max(branches.count, 1)) }
    private let startAngle: CGFloat = -.pi / 2 // first branch points straight up

    private func branchAngle(_ index: Int) -> CGFloat { startAngle + slice * CGFloat(index) }

    private func rawBranchPosition(_ index: Int) -> CGPoint {
        RadialLayout.pointOnEllipse(center: .zero, radiusX: branchRadiusX, radiusY: branchRadiusY, angle: branchAngle(index))
    }

    /// A branch's leaves fan across an arc capped well inside its slice so neighboring branches'
    /// leaves never cross into it.
    private func leafArc(for leafCount: Int) -> CGFloat {
        min(slice * 0.8, anglePerLeaf * CGFloat(max(leafCount - 1, 0)))
    }

    private func rawLeafPosition(branchIndex: Int, leafIndex: Int, leafCount: Int) -> CGPoint {
        let arc = leafArc(for: leafCount)
        let angles = RadialLayout.angles(count: leafCount, startAngle: branchAngle(branchIndex) - arc / 2,
                                         angleSpan: arc, closed: false)
        let scale = 1 + (leafIndex.isMultiple(of: 2) ? -leafZigzagScale : leafZigzagScale)
        return RadialLayout.pointOnEllipse(center: .zero, radiusX: leafRadiusX * scale, radiusY: leafRadiusY * scale,
                                           angle: angles[leafIndex])
    }

    /// Every node's position relative to an arbitrary (0,0) root — used only to measure the tree's
    /// true bounding box; `offset` then shifts everything into the positive-coordinate canvas below.
    private var rawPoints: [CGPoint] {
        var points: [CGPoint] = [.zero]
        for (bi, branch) in branches.enumerated() {
            points.append(rawBranchPosition(bi))
            for li in branch.leaves.indices {
                points.append(rawLeafPosition(branchIndex: bi, leafIndex: li, leafCount: branch.leaves.count))
            }
        }
        return points
    }

    private var canvasSize: CGSize {
        guard let minX = rawPoints.map(\.x).min(), let minY = rawPoints.map(\.y).min(),
              let maxX = rawPoints.map(\.x).max(), let maxY = rawPoints.map(\.y).max() else {
            return CGSize(width: nodeMargin * 2, height: nodeMargin * 2)
        }
        return CGSize(width: maxX - minX + nodeMargin * 2, height: maxY - minY + nodeMargin * 2)
    }

    private var offset: CGPoint {
        guard let minX = rawPoints.map(\.x).min(), let minY = rawPoints.map(\.y).min() else { return .zero }
        return CGPoint(x: nodeMargin - minX, y: nodeMargin - minY)
    }

    private var center: CGPoint { offset }

    private func branchPosition(_ index: Int) -> CGPoint {
        let raw = rawBranchPosition(index)
        return CGPoint(x: raw.x + offset.x, y: raw.y + offset.y)
    }

    private func leafPosition(branchIndex: Int, leafIndex: Int, leafCount: Int) -> CGPoint {
        let raw = rawLeafPosition(branchIndex: branchIndex, leafIndex: leafIndex, leafCount: leafCount)
        return CGPoint(x: raw.x + offset.x, y: raw.y + offset.y)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            heading.padding([.horizontal, .top], 20)
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

    private var diagram: some View {
        ZStack {
            Canvas { context, _ in
                for (bi, branch) in branches.enumerated() {
                    let branchPoint = branchPosition(bi)
                    let trunk = DiagramConnector(radialFrom: center, to: branchPoint)
                    context.stroke(trunk.path, with: .color(branch.tint.opacity(0.55)),
                                   style: StrokeStyle(lineWidth: 2.5, lineCap: .round))

                    for (li, leaf) in branch.leaves.enumerated() {
                        let leafPoint = leafPosition(branchIndex: bi, leafIndex: li, leafCount: branch.leaves.count)
                        let twig = DiagramConnector(radialFrom: branchPoint, to: leafPoint, bow: 0.12)
                        context.stroke(twig.path, with: .color((leaf.tint ?? branch.tint).opacity(0.45)),
                                       style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                    }
                }
            }
            .frame(width: canvasSize.width, height: canvasSize.height)

            ForEach(Array(branches.enumerated()), id: \.element.id) { bi, branch in
                ForEach(Array(branch.leaves.enumerated()), id: \.element.id) { li, leaf in
                    leafBubble(leaf, tint: branch.tint)
                        .position(leafPosition(branchIndex: bi, leafIndex: li, leafCount: branch.leaves.count))
                }
            }

            ForEach(Array(branches.enumerated()), id: \.element.id) { bi, branch in
                branchBubble(branch).position(branchPosition(bi))
            }

            rootBubble.position(center)
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
    }

    private var rootBubble: some View {
        VStack(spacing: 3) {
            Image(systemName: rootIcon).font(.system(size: 20, weight: .semibold))
            Text(rootTitle)
                .font(.system(size: 12, weight: .bold))
                .lineLimit(1)
        }
        .foregroundColor(.white)
        .frame(width: 94, height: 94)
        .background(Circle().fill(AppColors.primary))
        .overlay(Circle().stroke(AppColors.primary.opacity(0.25), lineWidth: 7))
    }

    private func branchBubble(_ branch: MindMapBranch) -> some View {
        HStack(spacing: 6) {
            if let emoji = branch.emoji {
                Text(emoji).font(.system(size: 13))
            }
            Text(branch.title)
                .font(.system(size: 12, weight: .bold))
                .lineLimit(1)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(RoundedRectangle(cornerRadius: 10).fill(branch.tint))
        .fixedSize()
    }

    private func leafBubble(_ leaf: MindMapLeaf, tint: Color) -> some View {
        let color = leaf.tint ?? tint
        return Text(leaf.title)
            .font(.system(size: 10.5, weight: .medium))
            .foregroundColor(AppColors.text)
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .frame(width: 92)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 8).fill(AppColors.cardBackground))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.5), lineWidth: 1.25))
    }
}

/// A top-level branch of the mind map — a subject area radiating from the root, colored
/// consistently with its own leaves.
struct MindMapBranch: Identifiable {
    let id: String
    let title: String
    var emoji: String? = nil
    let tint: Color
    let leaves: [MindMapLeaf]
}

/// A leaf node at the end of a branch. `tint` overrides the branch color when a leaf carries its
/// own meaning (e.g. a roadmap initiative colored by delivery status rather than by lane).
struct MindMapLeaf: Identifiable {
    let id: String
    let title: String
    var tint: Color? = nil
}
