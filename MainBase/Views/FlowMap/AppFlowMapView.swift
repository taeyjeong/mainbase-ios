import SwiftUI

// MARK: - Model

/// A single stop on the flow map — one screen (or entry point) in the app.
enum FlowStopKind {
    case entry   // auth / app entry — red pin
    case hub     // a tab — ringed "town" marker
    case screen  // a regular screen — blue pin
}

struct FlowStop: Identifiable {
    let id: Int
    var name: String
    var sub: String
    var pos: CGPoint   // in design space (1240 x 860)
    var kind: FlowStopKind

    init(_ id: Int, _ x: CGFloat, _ y: CGFloat, _ kind: FlowStopKind, _ name: String, _ sub: String = "") {
        self.id = id; self.pos = CGPoint(x: x, y: y); self.kind = kind; self.name = name; self.sub = sub
    }
}

/// A road between two stops — the kind encodes how you get there.
enum FlowRoadKind {
    case highway    // the tab bar (thick, yellow dashed center line)
    case road       // push navigation (solid)
    case spur       // opens as a sheet (dashed)
    case connector  // automatic navigation (blue dashed arrow)
}

struct FlowRoad: Identifiable {
    let id: Int
    var from: Int
    var to: Int
    var kind: FlowRoadKind
    var label: String
    var arrow: Bool
    var curve: CGFloat   // perpendicular bow, in design units

    init(_ id: Int, _ from: Int, _ to: Int, _ kind: FlowRoadKind, _ label: String = "", arrow: Bool = false, curve: CGFloat = 0) {
        self.id = id; self.from = from; self.to = to; self.kind = kind
        self.label = label; self.arrow = arrow; self.curve = curve
    }
}

// MARK: - Palette

private struct MapPalette {
    let paper, road, roadFill, centerline, brand, start, water, park, ink, inkSoft, grid, labelBg, hair, shadow: Color

    static func make(_ scheme: ColorScheme) -> MapPalette {
        if scheme == .dark {
            return MapPalette(
                paper: Color(hex: "#10161B"), road: Color(hex: "#1E252B"), roadFill: Color(hex: "#454F58"),
                centerline: Color(hex: "#F2B705"), brand: Color(hex: "#3B9BFF"), start: Color(hex: "#F0575B"),
                water: Color(hex: "#143A35"), park: Color(hex: "#223318"), ink: Color(hex: "#DCE3E8"),
                inkSoft: Color(hex: "#8A99A2"), grid: Color(hex: "#DCE3E8").opacity(0.06),
                labelBg: Color(hex: "#10161B").opacity(0.86), hair: Color(hex: "#DCE3E8").opacity(0.12),
                shadow: Color.black.opacity(0.5))
        }
        return MapPalette(
            paper: Color(hex: "#E9ECE3"), road: Color(hex: "#313941"), roadFill: Color(hex: "#525B64"),
            centerline: Color(hex: "#F2B705"), brand: Color(hex: "#0A6CF0"), start: Color(hex: "#DB3B3F"),
            water: Color(hex: "#A9D6CF"), park: Color(hex: "#C0D4A6"), ink: Color(hex: "#223038"),
            inkSoft: Color(hex: "#61707A"), grid: Color(hex: "#223038").opacity(0.07),
            labelBg: Color(hex: "#F7F9F2").opacity(0.92), hair: Color(hex: "#223038").opacity(0.14),
            shadow: Color.black.opacity(0.16))
    }
}

// MARK: - View

/// A cartographic "field map" of the app's navigation — screens as stops, transitions as roads.
/// The layout is data-driven (`MainBaseFlow`), so editing the data rebuilds the map on the next run.
struct AppFlowMapView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    let stops: [FlowStop]
    let roads: [FlowRoad]

    private static let design = CGSize(width: 1240, height: 860)

    @State private var zoom: CGFloat = 1
    @State private var lastZoom: CGFloat = 1

    init(stops: [FlowStop] = MainBaseFlow.stops, roads: [FlowRoad] = MainBaseFlow.roads) {
        self.stops = stops
        self.roads = roads
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let base = max(geo.size.width, 1040)
                let w = base * zoom
                let h = w * (Self.design.height / Self.design.width)

                ScrollView([.horizontal, .vertical], showsIndicators: true) {
                    Canvas { context, size in
                        draw(context, size: size, pal: MapPalette.make(scheme))
                    }
                    .frame(width: w, height: h)
                    .padding(16)
                }
                .background(mapBackground)
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in zoom = min(3, max(0.5, lastZoom * value)) }
                        .onEnded { _ in lastZoom = zoom }
                )
            }
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle("App Flow Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.primary)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { zoom = 1; lastZoom = 1 }
                    } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                    }
                    .foregroundColor(AppColors.primary)
                }
            }
            .safeAreaInset(edge: .bottom) { legend }
        }
    }

    private var mapBackground: some View {
        MapPalette.make(scheme).paper.opacity(0.35).ignoresSafeArea()
    }

    // MARK: Legend

    private var legend: some View {
        let pal = MapPalette.make(scheme)
        return HStack(spacing: 16) {
            legendItem(color: pal.centerline, text: "Highway · tabs")
            legendItem(color: pal.roadFill, text: "Road · push")
            legendItem(color: pal.inkSoft, text: "Spur · sheet", dashed: true)
            legendItem(color: pal.brand, text: "Auto-jump", dashed: true)
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundColor(pal.inkSoft)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(.thinMaterial)
    }

    private func legendItem(color: Color, text: String, dashed: Bool = false) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 18, height: dashed ? 3 : 5)
                .opacity(dashed ? 0.9 : 1)
            Text(text).fixedSize()
        }
    }

    // MARK: Drawing

    private func draw(_ context: GraphicsContext, size: CGSize, pal: MapPalette) {
        let s = size.width / Self.design.width
        func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * s, y: y * s) }

        // Terrain
        let bg = Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 12 * s)
        context.fill(bg, with: .color(pal.paper))

        // Water blob
        var water = Path()
        water.move(to: P(980, 55))
        water.addCurve(to: P(1232, 150), control1: P(1085, 26), control2: P(1215, 58))
        water.addCurve(to: P(1064, 236), control1: P(1244, 214), control2: P(1156, 256))
        water.addCurve(to: P(980, 55), control1: P(982, 218), control2: P(936, 132))
        water.closeSubpath()
        context.fill(water, with: .color(pal.water.opacity(0.5)))

        // Parks
        context.fill(Path(ellipseIn: CGRect(x: (540 - 150) * s, y: (748 - 60) * s, width: 300 * s, height: 120 * s)),
                     with: .color(pal.park.opacity(0.5)))
        context.fill(Path(ellipseIn: CGRect(x: (120 - 95) * s, y: (150 - 66) * s, width: 190 * s, height: 132 * s)),
                     with: .color(pal.park.opacity(0.5)))

        // Dot grid
        var dots = Path()
        var gx: CGFloat = 20
        while gx < Self.design.width { var gy: CGFloat = 20
            while gy < Self.design.height {
                dots.addEllipse(in: CGRect(x: gx * s - 1.3 * s, y: gy * s - 1.3 * s, width: 2.6 * s, height: 2.6 * s))
                gy += 40
            }
            gx += 40
        }
        context.fill(dots, with: .color(pal.grid))

        // Roads
        for road in roads { drawRoad(context, road: road, s: s, pal: pal) }
        // Road labels (drawn above roads)
        for road in roads where !road.label.isEmpty { drawRoadLabel(context, road: road, s: s, pal: pal) }

        // Stops + labels
        for stop in stops { drawStop(context, stop: stop, s: s, pal: pal) }

        // Compass
        drawCompass(context, s: s, pal: pal)
    }

    private func stop(_ id: Int) -> FlowStop? { stops.first { $0.id == id } }

    private func drawRoad(_ context: GraphicsContext, road: FlowRoad, s: CGFloat, pal: MapPalette) {
        guard let a = stop(road.from), let b = stop(road.to) else { return }
        let dx = b.pos.x - a.pos.x, dy = b.pos.y - a.pos.y
        let len = max(1, hypot(dx, dy))
        let ux = dx / len, uy = dy / len
        let t0: CGFloat = 15, t1: CGFloat = road.arrow ? 22 : 15
        let ax = a.pos.x + ux * t0, ay = a.pos.y + uy * t0
        let bx = b.pos.x - ux * t1, by = b.pos.y - uy * t1
        let mx = (ax + bx) / 2, my = (ay + by) / 2
        let nx = -uy, ny = ux
        let cx = mx + nx * road.curve, cy = my + ny * road.curve

        var path = Path()
        path.move(to: CGPoint(x: ax * s, y: ay * s))
        path.addQuadCurve(to: CGPoint(x: bx * s, y: by * s), control: CGPoint(x: cx * s, y: cy * s))

        func line(_ w: CGFloat, _ color: Color, dash: [CGFloat] = []) {
            context.stroke(path, with: .color(color),
                           style: StrokeStyle(lineWidth: w * s, lineCap: .round, lineJoin: .round, dash: dash.map { $0 * s }))
        }

        switch road.kind {
        case .highway:
            line(26, pal.road); line(17, pal.roadFill); line(2.6, pal.centerline, dash: [11, 13])
        case .road:
            line(13, pal.road); line(7, pal.roadFill)
        case .spur:
            line(3, pal.inkSoft, dash: [2, 7.5])
        case .connector:
            line(2.6, pal.brand, dash: [8, 6])
        }

        if road.arrow {
            let color = road.kind == .connector ? pal.brand : pal.inkSoft
            drawArrow(context, tip: CGPoint(x: bx, y: by), control: CGPoint(x: cx, y: cy), s: s, color: color)
        }
    }

    private func drawArrow(_ context: GraphicsContext, tip: CGPoint, control: CGPoint, s: CGFloat, color: Color) {
        let vx = tip.x - control.x, vy = tip.y - control.y
        let vl = max(1, hypot(vx, vy))
        let dx = vx / vl, dy = vy / vl
        let px = -dy, py = dx
        let baseX = tip.x - dx * 8, baseY = tip.y - dy * 8
        var tri = Path()
        tri.move(to: CGPoint(x: tip.x * s, y: tip.y * s))
        tri.addLine(to: CGPoint(x: (baseX + px * 4.5) * s, y: (baseY + py * 4.5) * s))
        tri.addLine(to: CGPoint(x: (baseX - px * 4.5) * s, y: (baseY - py * 4.5) * s))
        tri.closeSubpath()
        context.fill(tri, with: .color(color))
    }

    private func drawStop(_ context: GraphicsContext, stop: FlowStop, s: CGFloat, pal: MapPalette) {
        let p = CGPoint(x: stop.pos.x * s, y: stop.pos.y * s)

        switch stop.kind {
        case .hub:
            context.fill(Path(ellipseIn: CGRect(x: p.x - 15 * s, y: p.y - 3 * s, width: 30 * s, height: 8 * s)),
                         with: .color(pal.shadow.opacity(0.5)))
            let outer = Path(ellipseIn: CGRect(x: p.x - 15.5 * s, y: p.y - 15.5 * s, width: 31 * s, height: 31 * s))
            context.fill(outer, with: .color(pal.paper))
            context.stroke(outer, with: .color(pal.brand), lineWidth: 3.6 * s)
            context.fill(Path(ellipseIn: CGRect(x: p.x - 6.5 * s, y: p.y - 6.5 * s, width: 13 * s, height: 13 * s)),
                         with: .color(pal.brand))
        default:
            drawPin(context, at: p, s: s, color: stop.kind == .entry ? pal.start : pal.brand, eye: pal.paper, pal: pal)
        }

        // Label
        let isHub = stop.kind == .hub
        let top = (isHub ? stop.pos.y + 20 : stop.pos.y + 6) * s
        drawLabel(context, text: stop.name, centerX: p.x, top: top,
                  fontPx: isHub ? 15 : 13.5, weight: isHub ? .bold : .semibold,
                  tracking: isHub ? 0.6 : 0, uppercase: isHub, s: s, pal: pal)

        if !stop.sub.isEmpty {
            let subText = Text(stop.sub).font(.system(size: 10 * s, design: .monospaced)).foregroundColor(pal.inkSoft)
            context.draw(subText, at: CGPoint(x: p.x, y: top + 34 * s), anchor: .center)
        }
    }

    private func drawPin(_ context: GraphicsContext, at p: CGPoint, s: CGFloat, color: Color, eye: Color, pal: MapPalette) {
        // shadow
        context.fill(Path(ellipseIn: CGRect(x: p.x - 7 * s, y: p.y - 2.6 * s, width: 14 * s, height: 5.2 * s)),
                     with: .color(pal.shadow))
        // head
        context.fill(Path(ellipseIn: CGRect(x: p.x - 12 * s, y: p.y - 38 * s, width: 24 * s, height: 24 * s)),
                     with: .color(color))
        // tail
        var tail = Path()
        tail.move(to: CGPoint(x: p.x - 7 * s, y: p.y - 24 * s))
        tail.addLine(to: CGPoint(x: p.x, y: p.y))
        tail.addLine(to: CGPoint(x: p.x + 7 * s, y: p.y - 24 * s))
        tail.closeSubpath()
        context.fill(tail, with: .color(color))
        // eye
        context.fill(Path(ellipseIn: CGRect(x: p.x - 4.6 * s, y: p.y - 30.6 * s, width: 9.2 * s, height: 9.2 * s)),
                     with: .color(eye))
    }

    private func drawLabel(_ context: GraphicsContext, text: String, centerX: CGFloat, top: CGFloat,
                           fontPx: CGFloat, weight: Font.Weight, tracking: CGFloat, uppercase: Bool,
                           s: CGFloat, pal: MapPalette) {
        let str = uppercase ? text.uppercased() : text
        let t = Text(str).font(.system(size: fontPx * s, weight: weight)).tracking(tracking * s).foregroundColor(pal.ink)
        let resolved = context.resolve(t)
        let sz = resolved.measure(in: CGSize(width: 600, height: 200))
        let padX = 9 * s, padY = 4 * s
        let rect = CGRect(x: centerX - sz.width / 2 - padX, y: top, width: sz.width + padX * 2, height: sz.height + padY * 2)
        let rr = Path(roundedRect: rect, cornerRadius: 6 * s)
        context.fill(rr, with: .color(pal.labelBg))
        context.stroke(rr, with: .color(pal.hair), lineWidth: 1)
        context.draw(resolved, at: CGPoint(x: centerX, y: rect.midY), anchor: .center)
    }

    private func drawRoadLabel(_ context: GraphicsContext, road: FlowRoad, s: CGFloat, pal: MapPalette) {
        guard let a = stop(road.from), let b = stop(road.to) else { return }
        let mx = (a.pos.x + b.pos.x) / 2, my = (a.pos.y + b.pos.y) / 2
        let dx = b.pos.x - a.pos.x, dy = b.pos.y - a.pos.y
        let len = max(1, hypot(dx, dy))
        let nx = -dy / len, ny = dx / len
        let lx = (mx + nx * road.curve * 0.55) * s
        let ly = (my + ny * road.curve * 0.55) * s

        let emphasize = road.kind == .connector || road.kind == .spur
        let t = Text(road.label).font(.system(size: 11 * s, weight: emphasize ? .semibold : .regular, design: .monospaced))
            .foregroundColor(emphasize ? pal.brand : pal.inkSoft)
        let resolved = context.resolve(t)
        let sz = resolved.measure(in: CGSize(width: 400, height: 60))
        let rect = CGRect(x: lx - sz.width / 2 - 5 * s, y: ly - sz.height / 2 - 2 * s,
                          width: sz.width + 10 * s, height: sz.height + 4 * s)
        context.fill(Path(roundedRect: rect, cornerRadius: 4 * s), with: .color(pal.labelBg))
        context.draw(resolved, at: CGPoint(x: lx, y: ly), anchor: .center)
    }

    private func drawCompass(_ context: GraphicsContext, s: CGFloat, pal: MapPalette) {
        let c = CGPoint(x: 1158 * s, y: 772 * s)
        let ring = Path(ellipseIn: CGRect(x: c.x - 26 * s, y: c.y - 26 * s, width: 52 * s, height: 52 * s))
        context.fill(ring, with: .color(pal.labelBg))
        context.stroke(ring, with: .color(pal.inkSoft), lineWidth: 1.2 * s)

        var north = Path()
        north.move(to: CGPoint(x: c.x, y: c.y - 20 * s))
        north.addLine(to: CGPoint(x: c.x + 5.5 * s, y: c.y + 3 * s))
        north.addLine(to: CGPoint(x: c.x - 5.5 * s, y: c.y + 3 * s))
        north.closeSubpath()
        context.fill(north, with: .color(pal.start))

        var south = Path()
        south.move(to: CGPoint(x: c.x, y: c.y + 20 * s))
        south.addLine(to: CGPoint(x: c.x + 5.5 * s, y: c.y - 3 * s))
        south.addLine(to: CGPoint(x: c.x - 5.5 * s, y: c.y - 3 * s))
        south.closeSubpath()
        context.fill(south, with: .color(pal.inkSoft))

        let n = Text("N").font(.system(size: 13 * s, weight: .bold)).foregroundColor(pal.ink)
        context.draw(n, at: CGPoint(x: c.x, y: c.y - 30 * s), anchor: .center)
    }
}

// MARK: - MainBase flow data

/// The MainBase navigation graph. Edit these two arrays and re-run to rebuild the map.
enum MainBaseFlow {
    static let stops: [FlowStop] = [
        FlowStop(1, 150, 700, .entry, "Sign In"),
        FlowStop(2, 150, 782, .entry, "Sign Up"),
        FlowStop(3, 380, 520, .hub, "Clock In · Home", "clock · team · reports"),
        FlowStop(4, 700, 450, .hub, "Projects", "list · add · archive"),
        FlowStop(5, 1040, 520, .hub, "Operations", "shipments & ops"),
        FlowStop(6, 250, 250, .screen, "Profile"),
        FlowStop(7, 410, 196, .screen, "Schedule"),
        FlowStop(8, 585, 250, .screen, "Notifications"),
        FlowStop(9, 215, 430, .screen, "Reports feed"),
        FlowStop(10, 110, 315, .screen, "Report Chat"),
        FlowStop(11, 250, 608, .screen, "Clock-Out + Report"),
        FlowStop(12, 760, 250, .screen, "Project Detail", "tasks · chat · budget"),
        FlowStop(13, 930, 360, .screen, "Add Project"),
    ]

    static let roads: [FlowRoad] = [
        FlowRoad(20, 3, 4, .highway, curve: -46),
        FlowRoad(21, 4, 5, .highway, curve: -40),
        FlowRoad(22, 1, 3, .road, "after sign-in", curve: 34),
        FlowRoad(23, 1, 2, .spur, "switch", arrow: true),
        FlowRoad(24, 3, 6, .spur, arrow: true, curve: 18),
        FlowRoad(25, 3, 7, .spur, arrow: true),
        FlowRoad(26, 3, 8, .spur, arrow: true, curve: -18),
        FlowRoad(27, 3, 9, .road, "feed", curve: 10),
        FlowRoad(28, 9, 10, .spur, "Reply", arrow: true, curve: 14),
        FlowRoad(29, 3, 11, .spur, "Clock out", arrow: true, curve: -12),
        FlowRoad(30, 4, 12, .road, "open", curve: 22),
        FlowRoad(31, 4, 13, .spur, "+ Add", arrow: true, curve: -14),
        FlowRoad(32, 3, 4, .connector, "Clock In auto-opens", arrow: true, curve: 80),
    ]
}

#Preview {
    AppFlowMapView()
}
