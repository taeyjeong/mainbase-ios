import SwiftUI

/// The Projects2 tab: one button per wheel style, each pushing a `ProjectWheelView` in that style.
struct Projects2View: View {
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    ForEach(WheelStyle.allCases) { style in
                        NavigationLink {
                            ProjectWheelView(style: style)
                        } label: {
                            styleRow(style)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Projects2")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func styleRow(_ style: WheelStyle) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(style.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.text)
                Text(style.summary)
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.cardBackground)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColors.border, lineWidth: 1))
        )
        .contentShape(Rectangle())
    }
}

/// A hub with five spokes, 72° apart, each ending in a satellite 2/3 the hub's size showing one
/// area of work, drawn in `style`. Swipe around the hub to spin it either way, or tap a satellite
/// to spin it to the bottom; the wheel always snaps to one of five positions, with one satellite
/// pointing straight down. Nothing is selected at first; once a swipe settles or a satellite is
/// tapped, the bottom satellite is selected: the wheel shrinks, that satellite grows, the others
/// fade, and a branch draws out below to the area's sub-areas; tapping a sub-area opens a smaller
/// branch of its subjects. Tapping the hub closes it all.
private struct ProjectWheelView: View {
    let style: WheelStyle

    @State private var rotation: Angle = .zero
    /// Finger angle around the hub at the previous drag update; nil between drags.
    @State private var lastDragAngle: Angle?
    /// The selected area, always the one pointing straight down; nil at first, while dragging,
    /// and after the hub is tapped.
    @State private var selectedArea: Int?
    /// The sub-area whose subjects are open below the branch; cleared whenever the area changes.
    @State private var selectedChild: Int?
    /// Showing the whole map — every area, sub-area, and subject at once — instead of the wheel.
    @State private var showsFullMap = false

    private static let selectedWheelScale: CGFloat = 0.65

    var body: some View {
        Group {
            if showsFullMap {
                FullWheelMap(style: style, onTapHub: { openFromMap(area: nil, child: nil) },
                             onTapArea: { openFromMap(area: $0, child: nil) },
                             onTapChild: { openFromMap(area: $0, child: $1) })
                    .transition(.opacity)
            } else {
                wheel
                    .padding(16)
                    .transition(.opacity)
            }
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle(style.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) { showsFullMap.toggle() }
                } label: {
                    Image(systemName: showsFullMap ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                }
                .accessibilityLabel(showsFullMap ? "Close full map" : "Show full map")
            }
        }
    }

    private var wheel: some View {
        GeometryReader { geo in
            // Sized so the shrunken wheel plus the branch below it still fit.
            let side = min(geo.size.width, geo.size.height * 0.85)
            let metrics = WheelMetrics(side: side)
            let wheelScale = selectedArea == nil ? 1 : Self.selectedWheelScale
            let branchTop = metrics.selectedTitleBottom * Self.selectedWheelScale + metrics.branchGap
            // Centered on its own; once an area is selected, the shrunken wheel moves up under the
            // heading with the branch below it.
            let topInset = selectedArea == nil ? max(0, (geo.size.height - side) / 2) : 0

            ZStack(alignment: .top) {
                HubWheel(style: style, side: side, rotation: rotation, highlighted: selectedArea, onTapArea: spinToBottom, onTapHub: closeSelection)
                    .contentShape(Rectangle())
                    .gesture(spinGesture(center: CGPoint(x: side / 2, y: side / 2)))
                    .scaleEffect(wheelScale, anchor: .top)

                if let selectedArea {
                    AreaBranch(area: selectedArea, style: style, metrics: metrics, width: geo.size.width, selectedChild: $selectedChild)
                        .id(selectedArea)
                        .transition(.opacity)
                        .padding(.top, branchTop)
                }
            }
            .padding(.top, topInset)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
        }
    }

    /// Closes the full map and opens the wheel on whatever was tapped there: an area spins to the
    /// bottom and opens its branch, and a sub-area (or one of its subjects) also opens its
    /// subjects. The hub closes everything.
    private func openFromMap(area: Int?, child: Int?) {
        withAnimation(.easeInOut(duration: 0.25)) { showsFullMap = false }
        guard let area else { return closeSelection() }
        spinToBottom(area)
        selectedChild = child
    }

    /// Rotates by however far the finger travels around the hub, so swiping clockwise spins
    /// clockwise and vice versa. On release, the swipe's predicted end adds a fling, then the wheel
    /// snaps to the nearest of the five positions and selects the satellite pointing down.
    private func spinGesture(center: CGPoint) -> some Gesture {
        // A small minimum distance leaves taps to the hub's and satellites' buttons.
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                if selectedArea != nil { closeSelection() }
                // Too close to the hub, the angle jumps wildly — ignore those points.
                guard let current = angle(of: value.location, around: center) else { return }
                if let last = lastDragAngle ?? angle(of: value.startLocation, around: center) {
                    rotation += normalized(current - last)
                }
                lastDragAngle = current
            }
            .onEnded { value in
                lastDragAngle = nil
                var target = rotation
                if let end = angle(of: value.location, around: center),
                   let predicted = angle(of: value.predictedEndLocation, around: center) {
                    target += normalized(predicted - end)
                }
                let step = Wheel.spokeSpacing.degrees
                let steps = Int((target.degrees / step).rounded())
                withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                    rotation = .degrees(Double(steps) * step)
                }
                // Each clockwise step brings the previous area to the bottom.
                let count = Wheel.areas.count
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                    selectedArea = ((-steps % count) + count) % count
                }
            }
    }

    /// Spins the shorter way round until satellite `index` points straight down, and selects it.
    private func spinToBottom(_ index: Int) {
        if selectedArea != index { selectedChild = nil }
        let bottomRotation = -Wheel.spokeSpacing * Double(index)
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            rotation += normalized(bottomRotation - rotation)
        }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            selectedArea = index
        }
    }

    /// Clears the selection: the branch fades, the wheel and satellites return to full size.
    private func closeSelection() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            selectedArea = nil
            selectedChild = nil
        }
    }

    private func angle(of point: CGPoint, around center: CGPoint) -> Angle? {
        let dx = point.x - center.x
        let dy = point.y - center.y
        guard dx * dx + dy * dy > 20 * 20 else { return nil }
        return .radians(atan2(dy, dx))
    }

    /// Wraps an angle delta into (-180°, 180°] so crossing the ±180° seam doesn't spin a full turn.
    private func normalized(_ delta: Angle) -> Angle {
        var degrees = delta.degrees.truncatingRemainder(dividingBy: 360)
        if degrees > 180 { degrees -= 360 }
        if degrees <= -180 { degrees += 360 }
        return .degrees(degrees)
    }
}

// MARK: - Wheel geometry

private enum Wheel {
    typealias Node = (title: String, icon: String)

    struct Area {
        let title: String
        let icon: String
        /// Shown on the branch below the wheel when this area is selected.
        let children: [SubArea]
    }

    struct SubArea {
        let title: String
        let icon: String
        /// Shown on a second, smaller branch below this sub-area when it's tapped.
        let subjects: [Node]
    }

    /// One satellite per spoke, in clockwise order starting from the bottom.
    static let areas: [Area] = [
        Area(title: "Design", icon: "paintbrush.pointed.fill", children: [
            SubArea(title: "Branding", icon: "paintpalette.fill", subjects: [
                ("Logo", "seal.fill"), ("Color", "swatchpalette.fill"), ("Typography", "textformat"), ("Guidelines", "book.fill"),
            ]),
            SubArea(title: "UI/UX", icon: "rectangle.on.rectangle", subjects: [
                ("User Flow", "arrow.triangle.branch"), ("Info Architecture", "list.bullet.indent"), ("User Journey", "map.fill"),
            ]),
            SubArea(title: "Research", icon: "magnifyingglass", subjects: [
                ("Interviews", "mic.fill"), ("Surveys", "list.bullet.clipboard"), ("Usability", "hand.tap.fill"), ("Competitors", "binoculars.fill"),
            ]),
        ]),
        Area(title: "Develop", icon: "hammer.fill", children: [
            SubArea(title: "Site/App", icon: "apps.iphone", subjects: [
                ("Website", "globe"), ("iOS", "iphone"), ("Android", "candybarphone"), ("Web App", "macwindow"),
            ]),
            SubArea(title: "API", icon: "curlybraces", subjects: [
                ("REST", "arrow.left.arrow.right"), ("GraphQL", "point.3.connected.trianglepath.dotted"), ("Auth", "key.fill"), ("Webhooks", "bolt.horizontal.fill"),
            ]),
            SubArea(title: "Cloud", icon: "cloud.fill", subjects: [
                ("Hosting", "server.rack"), ("Database", "cylinder.split.1x2.fill"), ("Storage", "externaldrive.fill"), ("CI/CD", "arrow.triangle.2.circlepath"),
            ]),
        ]),
        Area(title: "Marketing", icon: "megaphone.fill", children: [
            SubArea(title: "Content", icon: "doc.richtext.fill", subjects: [
                ("Blog", "text.alignleft"), ("Video", "video.fill"), ("Email", "envelope.fill"), ("Podcast", "mic.fill"),
            ]),
            SubArea(title: "Social", icon: "bubble.left.and.bubble.right.fill", subjects: [
                ("Meta", "infinity"), ("Pinterest", "pin.fill"), ("TikTok", "music.note"),
                ("Reddit", "bubble.left.fill"), ("X", "xmark"), ("LinkedIn", "briefcase.fill"),
            ]),
            SubArea(title: "Campaigns", icon: "target", subjects: [
                ("Paid Ads", "dollarsign.square.fill"), ("SEO", "magnifyingglass"), ("Launches", "paperplane.fill"), ("Events", "ticket.fill"),
            ]),
        ]),
        Area(title: "Operations", icon: "gearshape.2.fill", children: [
            SubArea(title: "Staff", icon: "person.2.fill", subjects: [
                ("Hiring", "person.badge.plus"), ("Onboarding", "figure.wave"), ("Payroll", "banknote.fill"), ("Scheduling", "calendar"),
            ]),
            SubArea(title: "Legal", icon: "building.columns.fill", subjects: [
                ("Contracts", "signature"), ("Compliance", "checkmark.shield.fill"), ("Licenses", "rosette"), ("Policies", "doc.text.fill"),
            ]),
            SubArea(title: "Finance", icon: "dollarsign.circle.fill", subjects: [
                ("Revenue", "arrow.up.right.circle.fill"), ("Expense", "arrow.down.right.circle.fill"),
            ]),
        ]),
        Area(title: "Growth", icon: "chart.line.uptrend.xyaxis", children: [
            SubArea(title: "Training", icon: "graduationcap.fill", subjects: [
                ("Courses", "play.rectangle.fill"), ("Workshops", "person.3.fill"), ("Playbooks", "book.closed.fill"),
            ]),
            SubArea(title: "Mentoring", icon: "person.fill.checkmark", subjects: [
                ("1:1s", "person.2.wave.2.fill"), ("Coaching", "figure.mind.and.body"), ("Peer Review", "text.bubble.fill"),
            ]),
            SubArea(title: "Analytics", icon: "chart.bar.fill", subjects: [
                ("Traffic", "chart.line.uptrend.xyaxis"), ("Conversion", "target"), ("Retention", "arrow.clockwise.circle.fill"), ("KPIs", "gauge.with.dots.needle.67percent"),
            ]),
        ]),
    ]
    static let spokeSpacing = Angle.degrees(72)
    /// How much the selected satellite grows.
    static let selectedSatelliteScale: CGFloat = 1.3

    /// Spoke `index`'s direction, starting straight down and stepping clockwise.
    static func direction(for index: Int) -> Angle {
        .degrees(90) + spokeSpacing * Double(index)
    }

    /// Long titles (Marketing, Operations) shrink a little so they don't crowd their neighbors.
    static func labelScale(for title: String) -> CGFloat {
        title.count > 7 ? 0.7 : 1
    }
}

/// Sizes shared by the wheel and the branch, all proportional to the wheel's `side`.
private struct WheelMetrics {
    let side: CGFloat

    var hubRadius: CGFloat { side * 0.12 }
    var satelliteRadius: CGFloat { hubRadius * 2 / 3 }
    var labelSize: CGFloat { side * 0.036 }
    /// Leaves room under the bottom satellite for its title.
    var orbit: CGFloat { side / 2 - satelliteRadius - side * 0.1 }
    var outlineWidth: CGFloat { max(1, side * 0.007) }
    /// Space left between a line's end and the shape it points at.
    var lineGap: CGFloat { side * 0.012 }

    /// Bottom of the selected (bottom, enlarged) satellite's title, measured from the wheel's top
    /// at full scale.
    var selectedTitleBottom: CGFloat {
        side / 2 + orbit + (satelliteRadius + labelSize * 1.6) * Wheel.selectedSatelliteScale
    }

    // The branch below the wheel: an elbowed stem down to a row of child nodes. Tapping a child
    // shrinks that row and hangs a second, smaller row of its subjects below it the same way.
    var branchGap: CGFloat { side * 0.03 }
    /// How small the child row gets while one of its subjects rows is open.
    var compactChildScale: CGFloat { 0.7 }
    var childTier: BranchTier {
        BranchTier(radius: satelliteRadius * 0.85, labelSize: labelSize * 0.85, top: 0)
    }
    /// Starts just under the shrunken children's (one-line) titles.
    var subjectTier: BranchTier {
        let child = childTier
        let shrunkenTitleBottom = child.nodeY - child.radius + (child.radius * 2 + child.labelSize * 1.8) * compactChildScale
        return BranchTier(radius: child.radius * 0.6, labelSize: labelSize * 0.72, top: shrunkenTitleBottom + lineGap)
    }
    var branchHeight: CGFloat { subjectTier.bottom }

    func lineWidth(for style: WheelStyle) -> CGFloat {
        max(1.2, side * 0.008) * style.spokeWeight
    }
}

/// Draws the hub, spokes, and satellites in `style`, fitted to a `side`×`side` square. Shapes and
/// icons counter-rotate so they stay upright while the spokes turn. The hub and satellites are
/// buttons.
private struct HubWheel: View {
    let style: WheelStyle
    let side: CGFloat
    var rotation: Angle = .zero
    /// When set, this satellite grows and every other one fades back.
    var highlighted: Int?
    var onTapArea: (Int) -> Void
    var onTapHub: () -> Void

    private var metrics: WheelMetrics { WheelMetrics(side: side) }
    private var satelliteRadius: CGFloat { metrics.satelliteRadius }
    private var labelSize: CGFloat { metrics.labelSize }
    private var orbit: CGFloat { metrics.orbit }

    var body: some View {
        ZStack {
            ForEach(Wheel.areas.indices, id: \.self) { index in
                Spoke(
                    direction: Wheel.direction(for: index),
                    rotationDegrees: rotation.degrees,
                    satelliteScale: scale(for: index),
                    hubShape: style.hubShape,
                    satelliteShape: style.satelliteShape,
                    metrics: metrics
                )
                .stroke(style.spokeColor, style: style.spokePattern.strokeStyle(width: metrics.lineWidth(for: style)))
            }

            ForEach(Wheel.areas.indices, id: \.self) { index in
                satellite(index)
                    .scaleEffect(scale(for: index))
                    .opacity(highlighted == nil || highlighted == index ? 1 : 0.3)
                    .rotationEffect(-rotation)
                    .offset(offset(for: index))
            }

            Button(action: onTapHub) {
                style.node(style.hubShape, radius: metrics.hubRadius, fill: style.hubFill, outline: style.hubOutline, metrics: metrics)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
            .rotationEffect(-rotation)
        }
        .frame(width: side, height: side)
        .rotationEffect(rotation)
    }

    private func scale(for index: Int) -> CGFloat {
        highlighted == index ? Wheel.selectedSatelliteScale : 1
    }

    private func satellite(_ index: Int) -> some View {
        let area = Wheel.areas[index]
        return Button { onTapArea(index) } label: {
            style.node(style.satelliteShape, radius: satelliteRadius, fill: style.satelliteFill, outline: style.satelliteOutline, metrics: metrics)
                .overlay {
                    Image(systemName: area.icon)
                        .font(.system(size: satelliteRadius * 0.8, weight: .semibold))
                        .foregroundStyle(style.iconColor)
                }
                .overlay(alignment: .top) {
                    Text(area.title)
                        .font(.system(size: labelSize * Wheel.labelScale(for: area.title), weight: .semibold))
                        .foregroundStyle(style.labelColor)
                        .fixedSize()
                        .offset(y: satelliteRadius * 2 + labelSize * 0.4)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(area.title)
    }

    private func offset(for index: Int) -> CGSize {
        let radians = Wheel.direction(for: index).radians
        return CGSize(width: cos(radians) * orbit, height: sin(radians) * orbit)
    }
}

/// One spoke, running from the hub's edge to its satellite's edge (less a small gap each end) so
/// it never crosses a shape — even a faded one. Shapes stay upright on screen while the spoke
/// turns, so where it meets each edge depends on the current rotation; rotation and the
/// satellite's scale are animatable so the ends track the shapes mid-spin and mid-grow.
private struct Spoke: Shape {
    let direction: Angle
    var rotationDegrees: Double
    var satelliteScale: CGFloat
    let hubShape: WheelShape
    let satelliteShape: WheelShape
    let metrics: WheelMetrics

    var animatableData: AnimatablePair<Double, CGFloat> {
        get { AnimatablePair(rotationDegrees, satelliteScale) }
        set { rotationDegrees = newValue.first; satelliteScale = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        let onScreen = direction + .degrees(rotationDegrees)
        let start = hubShape.edgeDistance(radius: metrics.hubRadius, angle: onScreen) + metrics.lineGap
        let end = metrics.orbit
            - satelliteShape.edgeDistance(radius: metrics.satelliteRadius * satelliteScale, angle: onScreen)
            - metrics.lineGap
        guard end > start else { return Path() }
        let unit = CGPoint(x: cos(direction.radians), y: sin(direction.radians))
        return Path { path in
            path.move(to: CGPoint(x: rect.midX + unit.x * start, y: rect.midY + unit.y * start))
            path.addLine(to: CGPoint(x: rect.midX + unit.x * end, y: rect.midY + unit.y * end))
        }
    }
}

/// One row of a branch: its nodes' size, plus where its stem starts and its nodes sit, measured
/// from the branch's top.
private struct BranchTier {
    let radius: CGFloat
    let labelSize: CGFloat
    let top: CGFloat

    var elbowY: CGFloat { top + radius * 1.4 }
    var nodeY: CGFloat { elbowY + radius * 2.2 }
    /// Below the nodes' titles, leaving room for a title that wraps to two lines.
    var bottom: CGFloat { nodeY + radius + labelSize * 3 }
}

/// The selected area's sub-areas, hanging below the wheel. Tapping a sub-area shrinks the row and
/// opens a smaller row of its subjects below it; tapping it again closes them. Recreated (via
/// `.id`) per area, so every new selection replays the animation.
private struct AreaBranch: View {
    let area: Int
    let style: WheelStyle
    let metrics: WheelMetrics
    let width: CGFloat

    /// The tapped sub-area, whose subjects hang below it; nil until one is tapped.
    @Binding var selectedChild: Int?

    private var children: [Wheel.SubArea] { Wheel.areas[area].children }

    var body: some View {
        ZStack(alignment: .topLeading) {
            BranchRow(nodes: children.map { ($0.title, $0.icon) }, tier: metrics.childTier, stemX: width / 2, width: width,
                      style: style, metrics: metrics, appearDelay: 0.2, selected: selectedChild, onTap: toggle)

            if let selectedChild {
                let stemX = BranchRow.x(for: selectedChild, of: children.count, radius: metrics.childTier.radius, under: width / 2, width: width)
                BranchRow(nodes: children[selectedChild].subjects, tier: metrics.subjectTier, stemX: stemX, width: width,
                          style: style, metrics: metrics, appearDelay: 0.05)
                    .id(selectedChild)
                    .transition(.opacity)
            }
        }
        .frame(width: width, height: metrics.branchHeight, alignment: .topLeading)
    }

    private func toggle(_ index: Int) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            selectedChild = selectedChild == index ? nil : index
        }
    }
}

/// One row of nodes hanging below `stemX` like an org chart: a stem drops from the tier's top,
/// then elbows out to each node, stopping short of it. On appear the lines draw themselves, then
/// the nodes pop in at their ends, one after another. The row centers under the stem, nudged in
/// to stay on screen. With `onTap` the nodes are buttons; once one is `selected`, every node
/// shrinks toward its top edge (so the lines still meet it) and the others fade back.
private struct BranchRow: View {
    let nodes: [Wheel.Node]
    let tier: BranchTier
    let stemX: CGFloat
    let width: CGFloat
    let style: WheelStyle
    let metrics: WheelMetrics
    /// When the lines start drawing; the nodes follow.
    let appearDelay: Double
    var selected: Int?
    var onTap: ((Int) -> Void)?

    @State private var isDrawn = false

    static func spacing(of count: Int, radius: CGFloat, width: CGFloat) -> CGFloat {
        min(width / CGFloat(count), radius * 6)
    }

    static func x(for index: Int, of count: Int, radius: CGFloat, under stemX: CGFloat, width: CGFloat) -> CGFloat {
        let spacing = spacing(of: count, radius: radius, width: width)
        let half = spacing * CGFloat(count) / 2
        let center = min(max(stemX, half), width - half)
        return center + (CGFloat(index) - CGFloat(count - 1) / 2) * spacing
    }

    private var spacing: CGFloat { Self.spacing(of: nodes.count, radius: tier.radius, width: width) }

    private func x(for index: Int) -> CGFloat {
        Self.x(for: index, of: nodes.count, radius: tier.radius, under: stemX, width: width)
    }

    private func fade(_ index: Int) -> Double {
        selected == nil || selected == index ? 1 : 0.3
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(nodes.indices, id: \.self) { index in
                line(to: index)
                    .trim(from: 0, to: isDrawn ? 1 : 0)
                    .stroke(style.spokeColor, style: style.spokePattern.strokeStyle(width: metrics.lineWidth(for: style)))
                    .opacity(fade(index))
                    .animation(.easeOut(duration: 0.45).delay(appearDelay), value: isDrawn)
            }

            ForEach(nodes.indices, id: \.self) { index in
                node(index)
                    .scaleEffect(selected == nil ? 1 : metrics.compactChildScale, anchor: .top)
                    .opacity(fade(index))
                    .scaleEffect(isDrawn ? 1 : 0.2)
                    .opacity(isDrawn ? 1 : 0)
                    .animation(.spring(response: 0.35, dampingFraction: 0.65).delay(appearDelay + 0.35 + 0.07 * Double(index)), value: isDrawn)
                    .position(x: x(for: index), y: tier.nodeY)
            }
        }
        .frame(width: width, height: tier.bottom, alignment: .topLeading)
        .onAppear { isDrawn = true }
    }

    /// Stem down from the tier's top, a rounded elbow across, then down to just above the node.
    private func line(to index: Int) -> Path {
        let start = CGPoint(x: stemX, y: tier.top)
        let edge = style.satelliteShape.edgeDistance(radius: tier.radius, angle: .degrees(-90))
        let end = CGPoint(x: x(for: index), y: tier.nodeY - edge - metrics.lineGap)
        let corner = min(tier.radius * 0.5, abs(end.x - start.x) / 2)
        return Path { path in
            path.move(to: start)
            if corner > 0 {
                path.addArc(tangent1End: CGPoint(x: start.x, y: tier.elbowY), tangent2End: CGPoint(x: end.x, y: tier.elbowY), radius: corner)
                path.addArc(tangent1End: CGPoint(x: end.x, y: tier.elbowY), tangent2End: end, radius: corner)
            }
            path.addLine(to: end)
        }
    }

    @ViewBuilder
    private func node(_ index: Int) -> some View {
        if let onTap {
            Button { onTap(index) } label: { nodeBody(index) }
                .buttonStyle(.plain)
                .accessibilityLabel(nodes[index].title)
        } else {
            nodeBody(index)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(nodes[index].title)
        }
    }

    private func nodeBody(_ index: Int) -> some View {
        let item = nodes[index]
        return style.node(style.satelliteShape, radius: tier.radius, fill: style.satelliteFill, outline: style.satelliteOutline, metrics: metrics)
            .overlay {
                Image(systemName: item.icon)
                    .font(.system(size: tier.radius * 0.75, weight: .semibold))
                    .foregroundStyle(style.iconColor)
            }
            .overlay(alignment: .top) {
                Text(item.title)
                    .font(.system(size: tier.labelSize, weight: .semibold))
                    .foregroundStyle(style.labelColor)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(width: spacing - 4)
                    .fixedSize(horizontal: false, vertical: true)
                    .offset(y: tier.radius * 2 + tier.labelSize * 0.4)
            }
    }
}

// MARK: - Full map

/// Every area, sub-area, and subject at once, as a radial tree around the hub: areas on the inner
/// ring, sub-areas on the middle ring, subjects on the outer ring with their titles running
/// outward. Drag to pan in any direction, pinch or use the buttons to zoom. Tapping any node hands
/// it back to the wheel (`onTapChild` for a sub-area or one of its subjects).
private struct FullWheelMap: View {
    let style: WheelStyle
    var onTapHub: () -> Void
    var onTapArea: (Int) -> Void
    var onTapChild: (_ area: Int, _ child: Int) -> Void

    private typealias Layout = FullMapLayout
    private var metrics: WheelMetrics { Layout.metrics }

    var body: some View {
        MapViewport(canvasSize: Layout.canvasSize) {
            ZStack(alignment: .topLeading) {
                Layout.links
                    .stroke(style.spokeColor, style: style.spokePattern.strokeStyle(width: metrics.lineWidth(for: style) * 0.6))

                Button(action: onTapHub) {
                    style.node(style.hubShape, radius: metrics.hubRadius, fill: style.hubFill, outline: style.hubOutline, metrics: metrics)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
                .position(Layout.center)

                ForEach(Layout.nodes) { node in
                    Button { tap(node) } label: { nodeView(node) }
                        .buttonStyle(.plain)
                        .accessibilityLabel(node.title)
                        .position(node.point)

                    if node.level == .subject {
                        Button { tap(node) } label: { radialTitle(node) }
                            .buttonStyle(.plain)
                            .accessibilityHidden(true)
                            .rotationEffect(.radians(node.readsLeftward ? node.angle + .pi : node.angle))
                            .position(Layout.point(ring: node.ring + Layout.radius(node.level) + Layout.titleGap + Layout.titleWidth / 2, angle: node.angle))
                    }
                }
            }
            .frame(width: Layout.canvasSize.width, height: Layout.canvasSize.height)
        }
    }

    private func tap(_ node: FullMapLayout.Node) {
        if let child = node.child { onTapChild(node.area, child) } else { onTapArea(node.area) }
    }

    private func nodeView(_ node: FullMapLayout.Node) -> some View {
        let radius = Layout.radius(node.level)
        return style.node(style.satelliteShape, radius: radius, fill: style.satelliteFill, outline: style.satelliteOutline, metrics: metrics)
            .overlay {
                Image(systemName: node.icon)
                    .font(.system(size: radius * 0.75, weight: .semibold))
                    .foregroundStyle(style.iconColor)
            }
            .overlay {
                if node.level != .subject {
                    // On the side the parent's line comes in from, so the children's lines fanning
                    // out the other way stay clear; the backing keeps it legible over that one line.
                    let size = Layout.labelSize(node.level)
                    Text(node.title)
                        .font(.system(size: size, weight: .semibold))
                        .foregroundStyle(style.labelColor)
                        .fixedSize()
                        .padding(.horizontal, size * 0.4)
                        .background(Capsule().fill(AppColors.background.opacity(0.85)))
                        .offset(y: (sin(node.angle) > 0 ? -1 : 1) * (radius + size * 1.1))
                }
            }
    }

    /// A subject's title along its ray, starting just past the node; flipped on the left half so it
    /// never reads upside down.
    private func radialTitle(_ node: FullMapLayout.Node) -> some View {
        Text(node.title)
            .font(.system(size: Layout.labelSize(.subject), weight: .semibold))
            .foregroundStyle(style.labelColor)
            .lineLimit(1)
            .frame(width: Layout.titleWidth, alignment: node.readsLeftward ? .trailing : .leading)
    }
}

/// Where every node of the full map sits. Subjects get evenly spaced slots around the outer ring,
/// with extra gaps between sub-areas and wider ones between areas; each sub-area sits at the
/// middle of its subjects' span and each area at the middle of its sub-areas', rotated so the
/// first area points straight down as it does on the wheel at rest.
private enum FullMapLayout {
    enum Level { case area, child, subject }

    struct Node: Identifiable {
        let id: String
        let level: Level
        let area: Int
        let child: Int?
        let title: String
        let icon: String
        let ring: CGFloat
        let angle: CGFloat
        let parentRing: CGFloat
        let parentAngle: CGFloat

        var point: CGPoint { FullMapLayout.point(ring: ring, angle: angle) }
        /// On the left half of the map, where a title along the ray would otherwise be upside down.
        var readsLeftward: Bool { cos(angle) < 0 }
    }

    /// Sizes the map's nodes like a wheel this big, so they match the wheel's proportions.
    static let metrics = WheelMetrics(side: 540)

    static let areaRing: CGFloat = 230
    static let childRing: CGFloat = 480
    static let subjectRing: CGFloat = 730
    static let titleGap: CGFloat = 8
    static let titleWidth: CGFloat = 170

    static func radius(_ level: Level) -> CGFloat {
        switch level {
        case .area: return metrics.satelliteRadius
        case .child: return metrics.childTier.radius
        case .subject: return metrics.subjectTier.radius
        }
    }

    static func labelSize(_ level: Level) -> CGFloat {
        switch level {
        case .area: return metrics.labelSize
        case .child: return metrics.childTier.labelSize
        case .subject: return metrics.subjectTier.labelSize
        }
    }

    static let canvasSize: CGSize = {
        let side = (subjectRing + radius(.subject) + titleGap + titleWidth + 20) * 2
        return CGSize(width: side, height: side)
    }()

    static var center: CGPoint { CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2) }

    static func point(ring: CGFloat, angle: CGFloat) -> CGPoint {
        CGPoint(x: center.x + cos(angle) * ring, y: center.y + sin(angle) * ring)
    }

    static let nodes: [Node] = {
        let childGap: CGFloat = 0.6
        let areaGap: CGFloat = 1.5

        // Slot positions, in units of one subject.
        var slot: CGFloat = 0
        var slots: [[[CGFloat]]] = []
        for (a, area) in Wheel.areas.enumerated() {
            if a > 0 { slot += areaGap }
            var areaSlots: [[CGFloat]] = []
            for (c, child) in area.children.enumerated() {
                if c > 0 { slot += childGap }
                areaSlots.append(child.subjects.map { _ in defer { slot += 1 }; return slot })
            }
            slots.append(areaSlots)
        }
        let step = 2 * .pi / (slot + areaGap)
        let span = { (values: [CGFloat]) in (values.first! + values.last!) / 2 }
        let offset = .pi / 2 - span(slots[0].flatMap { $0 }) * step
        let angle = { (slot: CGFloat) in slot * step + offset }

        var nodes: [Node] = []
        for (a, area) in Wheel.areas.enumerated() {
            let areaAngle = angle(span(slots[a].flatMap { $0 }))
            nodes.append(Node(id: "\(a)", level: .area, area: a, child: nil, title: area.title, icon: area.icon,
                              ring: areaRing, angle: areaAngle, parentRing: 0, parentAngle: areaAngle))
            for (c, child) in area.children.enumerated() {
                let childAngle = angle(span(slots[a][c]))
                nodes.append(Node(id: "\(a).\(c)", level: .child, area: a, child: c, title: child.title, icon: child.icon,
                                  ring: childRing, angle: childAngle, parentRing: areaRing, parentAngle: areaAngle))
                for (s, subject) in child.subjects.enumerated() {
                    nodes.append(Node(id: "\(a).\(c).\(s)", level: .subject, area: a, child: c, title: subject.title, icon: subject.icon,
                                      ring: subjectRing, angle: angle(slots[a][c][s]), parentRing: childRing, parentAngle: childAngle))
                }
            }
        }
        return nodes
    }()

    /// One curve from each node's parent to it, leaving the parent along the parent's ray and
    /// arriving along the node's own, stopping short of both shapes. Edge distances use the wheel's
    /// satellite shape for every node, and the hub's own shape at the center.
    static let links: Path = Path { path in
        let gap = metrics.lineGap
        for node in nodes {
            let parentRadius: CGFloat
            switch node.level {
            case .area: parentRadius = metrics.hubRadius
            case .child: parentRadius = radius(.area)
            case .subject: parentRadius = radius(.child)
            }
            let mid = (node.parentRing + node.ring) / 2
            let start = point(ring: node.parentRing + parentRadius + gap, angle: node.parentAngle)
            let end = point(ring: node.ring - radius(node.level) - gap, angle: node.angle)
            path.move(to: start)
            path.addCurve(to: end,
                          control1: point(ring: mid, angle: node.parentAngle),
                          control2: point(ring: mid, angle: node.angle))
        }
    }
}

/// A fixed-size canvas you can drag in any direction and zoom between fitting the whole canvas
/// on screen and 2.5×. Opens fitted and centered. Panning is in screen points and scales with
/// the zoom, so zooming keeps whatever is at the middle of the screen there; it's clamped so the
/// canvas can't be dragged entirely out of view.
private struct MapViewport<Content: View>: View {
    let canvasSize: CGSize
    @ViewBuilder let content: Content

    /// nil until the user zooms, meaning "fit".
    @State private var zoom: CGFloat?
    @State private var pan: CGSize = .zero
    @GestureState private var pinch: CGFloat = 1
    @GestureState private var drag: CGSize = .zero

    private let maxZoom: CGFloat = 2.5

    var body: some View {
        GeometryReader { geo in
            let fit = min(geo.size.width / canvasSize.width, geo.size.height / canvasSize.height)
            let base = zoom ?? fit
            let scale = clamped(base * pinch, fit: fit)
            let livePan = clamped(pan * (scale / base) + drag, scale: scale)

            ZStack {
                content
                    .frame(width: canvasSize.width, height: canvasSize.height)
                    .scaleEffect(scale)
                    .offset(livePan)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .contentShape(Rectangle())
            .clipped()
            .gesture(
                DragGesture(minimumDistance: 4)
                    .updating($drag) { value, state, _ in state = value.translation }
                    .onEnded { value in pan = clamped(pan + value.translation, scale: base) }
            )
            .simultaneousGesture(
                MagnifyGesture()
                    .updating($pinch) { value, state, _ in state = value.magnification }
                    .onEnded { value in setZoom(base * value.magnification, from: base, fit: fit, animated: false) }
            )
            .overlay(alignment: .bottomTrailing) {
                HStack(spacing: 0) {
                    zoomButton("minus", label: "Zoom out") { setZoom(base / 1.5, from: base, fit: fit) }
                    Divider().frame(height: 20).overlay(AppColors.border)
                    zoomButton("arrow.up.left.and.down.right.magnifyingglass", label: "Fit") {
                        withAnimation(.easeOut(duration: 0.25)) { zoom = nil; pan = .zero }
                    }
                    Divider().frame(height: 20).overlay(AppColors.border)
                    zoomButton("plus", label: "Zoom in") { setZoom(base * 1.5, from: base, fit: fit) }
                }
                .background(RoundedRectangle(cornerRadius: 10).fill(AppColors.cardBackground))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppColors.border, lineWidth: 1))
                .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
                .padding(16)
            }
        }
    }

    private func clamped(_ value: CGFloat, fit: CGFloat) -> CGFloat {
        min(max(value, fit), maxZoom)
    }

    /// Keeps at least the canvas's center on screen.
    private func clamped(_ offset: CGSize, scale: CGFloat) -> CGSize {
        let limitX = canvasSize.width * scale / 2
        let limitY = canvasSize.height * scale / 2
        return CGSize(width: min(max(offset.width, -limitX), limitX),
                      height: min(max(offset.height, -limitY), limitY))
    }

    private func setZoom(_ value: CGFloat, from base: CGFloat, fit: CGFloat, animated: Bool = true) {
        let target = clamped(value, fit: fit)
        withAnimation(animated ? .easeOut(duration: 0.2) : nil) {
            pan = clamped(pan * (target / base), scale: target)
            zoom = target
        }
    }

    private func zoomButton(_ icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppColors.primary)
                .frame(width: 40, height: 36)
        }
        .accessibilityLabel(label)
    }
}

private extension CGSize {
    static func + (lhs: CGSize, rhs: CGSize) -> CGSize {
        CGSize(width: lhs.width + rhs.width, height: lhs.height + rhs.height)
    }

    static func * (lhs: CGSize, rhs: CGFloat) -> CGSize {
        CGSize(width: lhs.width * rhs, height: lhs.height * rhs)
    }
}

private extension WheelStyle {
    /// One hub, satellite, or child node: the style's shape, fill, outline, and shadow.
    func node(_ shape: WheelShape, radius: CGFloat, fill: AnyShapeStyle, outline: Color?, metrics: WheelMetrics) -> some View {
        shape
            .fill(fill)
            .overlay { shape.stroke(outline ?? .clear, lineWidth: metrics.outlineWidth) }
            .frame(width: radius * 2, height: radius * 2)
            .shadow(color: shadowColor ?? .clear, radius: metrics.side * 0.02, y: metrics.side * 0.01)
    }
}

// MARK: - Styles

private enum WheelStyle: String, CaseIterable, Identifiable {
    case modern, corporate, minimal, executive

    var id: String { rawValue }

    var title: String {
        switch self {
        case .modern: return "Modern"
        case .corporate: return "Corporate"
        case .minimal: return "Minimal"
        case .executive: return "Executive"
        }
    }

    var summary: String {
        switch self {
        case .modern: return "Teal gradients with soft shadows"
        case .corporate: return "Navy rounded squares, dashed lines"
        case .minimal: return "Clean outlines, dotted lines"
        case .executive: return "Charcoal hexagons, gold accents"
        }
    }

    var hubShape: WheelShape {
        switch self {
        case .modern, .minimal: return .circle
        case .corporate: return .roundedSquare
        case .executive: return .hexagon
        }
    }

    var satelliteShape: WheelShape { hubShape }

    var hubFill: AnyShapeStyle {
        switch self {
        case .modern: return Self.diagonal("#14B8A6", "#0F766E")
        case .corporate: return AnyShapeStyle(Color(hex: "#1F3A5F"))
        case .minimal: return AnyShapeStyle(AppColors.cardBackground)
        case .executive: return AnyShapeStyle(Color(hex: "#2B2E33"))
        }
    }

    var hubOutline: Color? {
        switch self {
        case .modern, .corporate: return nil
        case .minimal: return AppColors.text
        case .executive: return Self.gold
        }
    }

    var satelliteFill: AnyShapeStyle {
        switch self {
        case .modern: return Self.diagonal("#2DD4BF", "#0D9488")
        case .corporate: return AnyShapeStyle(Color(hex: "#3E6FA3"))
        case .minimal: return AnyShapeStyle(AppColors.cardBackground)
        case .executive: return AnyShapeStyle(Color(hex: "#2B2E33"))
        }
    }

    var satelliteOutline: Color? {
        switch self {
        case .modern, .corporate: return nil
        case .minimal: return AppColors.textSecondary
        case .executive: return Self.gold
        }
    }

    var labelColor: Color {
        switch self {
        case .modern, .corporate, .minimal: return AppColors.text
        case .executive: return Self.gold
        }
    }

    var iconColor: Color {
        switch self {
        case .modern, .corporate: return .white
        case .minimal: return AppColors.text
        case .executive: return Self.gold
        }
    }

    var spokeColor: Color {
        switch self {
        case .modern: return Color(hex: "#14B8A6").opacity(0.4)
        case .minimal: return AppColors.textSecondary
        case .corporate: return Color(hex: "#8A9BB0")
        case .executive: return Self.gold
        }
    }

    var spokePattern: SpokePattern {
        switch self {
        case .modern, .executive: return .solid
        case .corporate: return .dashed
        case .minimal: return .dotted
        }
    }

    /// Multiplier on the base spoke width.
    var spokeWeight: CGFloat {
        switch self {
        case .modern: return 1.6
        case .corporate: return 1
        case .minimal: return 1.2
        case .executive: return 0.6
        }
    }

    /// Soft drop shadow under the hub and satellites; nil for flat styles.
    var shadowColor: Color? {
        switch self {
        case .modern: return Color(hex: "#0F766E").opacity(0.35)
        case .corporate, .minimal, .executive: return nil
        }
    }

    private static let gold = Color(hex: "#C9A227")

    /// Light-to-dark gradient from the top-leading corner, for a lit-from-above look.
    private static func diagonal(_ light: String, _ dark: String) -> AnyShapeStyle {
        AnyShapeStyle(LinearGradient(colors: [Color(hex: light), Color(hex: dark)], startPoint: .topLeading, endPoint: .bottomTrailing))
    }
}

private enum WheelShape: Shape {
    case circle, roundedSquare, hexagon // hexagon is flat on top and bottom

    func path(in rect: CGRect) -> Path {
        switch self {
        case .circle:
            return Circle().path(in: rect)
        case .roundedSquare:
            return RoundedRectangle(cornerRadius: min(rect.width, rect.height) * 0.28, style: .continuous).path(in: rect)
        case .hexagon:
            let radius = min(rect.width, rect.height) / 2
            return Path { path in
                for corner in 0..<6 {
                    let radians = Angle.degrees(60 * Double(corner)).radians
                    let point = CGPoint(x: rect.midX + cos(radians) * radius, y: rect.midY + sin(radians) * radius)
                    if corner == 0 { path.move(to: point) } else { path.addLine(to: point) }
                }
                path.closeSubpath()
            }
        }
    }

    /// Distance from the center to the edge along `angle` (screen space, shape upright), for a
    /// shape `radius` from center to its farthest side or corner — where a line should stop.
    func edgeDistance(radius: CGFloat, angle: Angle) -> CGFloat {
        switch self {
        case .circle:
            return radius
        case .roundedSquare:
            let ux = abs(cos(angle.radians)), uy = abs(sin(angle.radians))
            let cornerRadius = radius * 0.56
            let inset = radius - cornerRadius
            let squareHit = radius / max(ux, uy)
            // Only the rounded corners fall short of the square's flat sides.
            guard squareHit * ux > inset, squareHit * uy > inset else { return squareHit }
            let along = (ux + uy) * inset
            return along + sqrt(max(0, along * along - 2 * inset * inset + cornerRadius * cornerRadius))
        case .hexagon:
            // Flat-topped: corners every 60° from 0°, flat sides facing 30°, 90°, ….
            var degrees = angle.degrees.truncatingRemainder(dividingBy: 60)
            if degrees < 0 { degrees += 60 }
            return radius * sqrt(3) / 2 / cos(Angle.degrees(degrees - 30).radians)
        }
    }
}

private enum SpokePattern {
    case solid, dashed, dotted

    func strokeStyle(width: CGFloat) -> StrokeStyle {
        switch self {
        case .solid: return StrokeStyle(lineWidth: width, lineCap: .round)
        case .dashed: return StrokeStyle(lineWidth: width, lineCap: .butt, dash: [width * 4, width * 3])
        case .dotted: return StrokeStyle(lineWidth: width, lineCap: .round, dash: [0, width * 2.5])
        }
    }
}

#Preview {
    Projects2View()
}
