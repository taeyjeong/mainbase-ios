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

    /// An organic curve that bows sideways relative to the line it connects, rather than the
    /// strictly top-to-bottom or left-to-right S-curve of `init(from:to:axis:)`. Used by the mind
    /// map, whose branches radiate outward in every direction, so a single fixed axis can't tell
    /// which way each curve should bow.
    init(radialFrom start: CGPoint, to end: CGPoint, bow: CGFloat = 0.2) {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = max(hypot(dx, dy), 0.001)
        let mid = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
        let control = CGPoint(x: mid.x - dy / length * length * bow,
                              y: mid.y + dx / length * length * bow)
        var path = Path()
        path.move(to: start)
        path.addQuadCurve(to: end, control: control)
        self.path = path
        self.tip = end
        self.tipAngle = atan2(end.y - control.y, end.x - control.x)
    }
}

/// Places points evenly around a circle or ellipse — used to lay out nodes with no inherent
/// hierarchy (a peer network) or the branches/leaves of a radial mind map.
enum RadialLayout {
    static func angles(count: Int, startAngle: CGFloat, angleSpan: CGFloat = 2 * .pi,
                       closed: Bool = true) -> [CGFloat] {
        guard count > 0 else { return [] }
        if count == 1 {
            return [closed ? startAngle : startAngle + angleSpan / 2]
        }
        let divisor = CGFloat(closed ? count : count - 1)
        return (0..<count).map { startAngle + angleSpan * CGFloat($0) / divisor }
    }

    /// With independent X/Y radii — used to squash a ring or radial fan into a
    /// vertically-elongated oval (taller than wide) instead of a perfect circle, so diagrams read
    /// top-to-bottom on a phone rather than spreading equally in every direction.
    static func pointOnEllipse(center: CGPoint, radiusX: CGFloat, radiusY: CGFloat, angle: CGFloat) -> CGPoint {
        CGPoint(x: center.x + radiusX * cos(angle), y: center.y + radiusY * sin(angle))
    }
}

/// Wraps a fixed-size diagram canvas in a scrollable, pinch-zoomable container with a small
/// +/− control cluster. Shared by the Operations diagrams so zooming behaves identically across
/// them: the node/connector layout stays in its own fixed coordinate space and only the rendered
/// canvas is scaled, so lines and cards never re-flow.
struct ZoomableCanvas: ViewModifier {
    @Binding var zoom: CGFloat
    let canvasSize: CGSize

    private let range: ClosedRange<CGFloat> = 0.5...2.5
    private let step: CGFloat = 0.25
    @GestureState private var gestureScale: CGFloat = 1

    func body(content: Content) -> some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView([.horizontal, .vertical], showsIndicators: false) {
                content
                    .scaleEffect(zoom * gestureScale, anchor: .topLeading)
                    .frame(width: canvasSize.width * zoom * gestureScale,
                           height: canvasSize.height * zoom * gestureScale,
                           alignment: .topLeading)
                    .padding(20)
            }
            .gesture(
                MagnificationGesture()
                    .updating($gestureScale) { value, state, _ in state = value }
                    .onEnded { value in setZoom(zoom * value) }
            )

            controls
        }
    }

    private var controls: some View {
        HStack(spacing: 0) {
            zoomButton("minus") { setZoom(zoom - step) }
            Divider().frame(height: 20).overlay(AppColors.border)
            zoomButton("plus") { setZoom(zoom + step) }
        }
        .background(RoundedRectangle(cornerRadius: 10).fill(AppColors.cardBackground))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppColors.border, lineWidth: 1))
        .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
        .padding(16)
    }

    private func zoomButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppColors.primary)
                .frame(width: 40, height: 36)
        }
    }

    private func setZoom(_ value: CGFloat) {
        withAnimation(.easeOut(duration: 0.15)) {
            zoom = min(max(value, range.lowerBound), range.upperBound)
        }
    }
}

extension View {
    /// Makes a fixed-size diagram canvas scrollable and pinch/tap zoomable.
    func zoomableCanvas(zoom: Binding<CGFloat>, canvasSize: CGSize) -> some View {
        modifier(ZoomableCanvas(zoom: zoom, canvasSize: canvasSize))
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
