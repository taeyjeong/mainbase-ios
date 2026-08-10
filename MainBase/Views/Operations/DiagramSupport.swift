import SwiftUI

/// Geometry + drawing helpers shared by the three Operations diagrams.
///
/// Every diagram lays its nodes out in a fixed coordinate space, draws its connectors in a `Canvas`
/// of that same size, then overlays the node views with `.position`. Because the layout is a set of
/// constants (not measured at runtime), every anchor point is deterministic and no `GeometryReader`
/// is needed to route the lines.

extension CGRect {
    init(center: CGPoint, size: CGSize) {
        self.init(x: center.x - size.width / 2,
                  y: center.y - size.height / 2,
                  width: size.width,
                  height: size.height)
    }

    var topAnchor: CGPoint { CGPoint(x: midX, y: minY) }
    var bottomAnchor: CGPoint { CGPoint(x: midX, y: maxY) }
    var leadingAnchor: CGPoint { CGPoint(x: minX, y: midY) }
    var trailingAnchor: CGPoint { CGPoint(x: maxX, y: midY) }
    var centerPoint: CGPoint { CGPoint(x: midX, y: midY) }
}

/// A smooth cubic-Bézier connector between two points, plus the tip geometry needed to cap it with
/// an arrowhead. `axis` controls which way the curve bows: `.vertical` for top-to-bottom flows,
/// `.horizontal` for left-to-right flows.
struct DiagramConnector {
    let path: Path
    let tip: CGPoint
    let tipAngle: CGFloat

    init(from start: CGPoint, to end: CGPoint, axis: Axis) {
        let control1: CGPoint
        let control2: CGPoint
        switch axis {
        case .vertical:
            let midY = (start.y + end.y) / 2
            control1 = CGPoint(x: start.x, y: midY)
            control2 = CGPoint(x: end.x, y: midY)
        case .horizontal:
            let midX = (start.x + end.x) / 2
            control1 = CGPoint(x: midX, y: start.y)
            control2 = CGPoint(x: midX, y: end.y)
        }
        var path = Path()
        path.move(to: start)
        path.addCurve(to: end, control1: control1, control2: control2)
        self.path = path
        self.tip = end
        self.tipAngle = atan2(end.y - control2.y, end.x - control2.x)
    }

    /// A point a little way back from the tip along the incoming tangent — a good spot for an
    /// edge label so it sits just off the arrowhead.
    func labelPoint(backBy distance: CGFloat) -> CGPoint {
        CGPoint(x: tip.x - distance * cos(tipAngle),
                y: tip.y - distance * sin(tipAngle))
    }
}

enum DiagramDraw {
    /// Strokes a connector and fills a triangular arrowhead at its tip.
    static func arrow(_ context: inout GraphicsContext,
                      _ connector: DiagramConnector,
                      color: Color,
                      lineWidth: CGFloat = 2,
                      dash: [CGFloat] = [],
                      arrowSize: CGFloat = 9) {
        context.stroke(connector.path,
                       with: .color(color),
                       style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round, dash: dash))
        context.fill(arrowHead(at: connector.tip, angle: connector.tipAngle, size: arrowSize),
                     with: .color(color))
    }

    /// A filled triangle pointing along `angle`, tip at `tip`.
    static func arrowHead(at tip: CGPoint, angle: CGFloat, size: CGFloat) -> Path {
        let spread = CGFloat.pi / 7
        let left = CGPoint(x: tip.x - size * cos(angle - spread),
                           y: tip.y - size * sin(angle - spread))
        let right = CGPoint(x: tip.x - size * cos(angle + spread),
                            y: tip.y - size * sin(angle + spread))
        var path = Path()
        path.move(to: tip)
        path.addLine(to: left)
        path.addLine(to: right)
        path.closeSubpath()
        return path
    }

    /// A straight relationship line with a small filled dot at each end — used by the ER diagram,
    /// which annotates cardinality with text badges rather than arrowheads.
    static func relationship(_ context: inout GraphicsContext,
                             from a: CGPoint,
                             to b: CGPoint,
                             color: Color,
                             lineWidth: CGFloat = 1.5,
                             axis: Axis) {
        let connector = DiagramConnector(from: a, to: b, axis: axis)
        context.stroke(connector.path,
                       with: .color(color),
                       style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
        for point in [a, b] {
            context.fill(Path(ellipseIn: CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6)),
                         with: .color(color))
        }
    }
}
