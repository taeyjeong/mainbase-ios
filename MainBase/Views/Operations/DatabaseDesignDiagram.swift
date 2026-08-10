import SwiftUI

/// Database-design view: a UML/ER-style schema where each table is a box with a header and typed
/// columns, and relationships are drawn as connecting lines annotated with cardinality (1 : ∞).
/// Static sample data — the core schema behind a projects-and-time-tracking app.
struct DatabaseDesignDiagram: View {
    private let tables = SchemaSample.tables
    private let relationships = SchemaSample.relationships

    private let canvasSize = CGSize(width: 720, height: 480)
    private let lineColor = AppColors.textSecondary.opacity(0.6)

    private func table(_ id: String) -> ERTable { tables.first { $0.id == id }! }

    var body: some View {
        ScrollView([.horizontal, .vertical], showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                heading
                diagram
            }
            .padding(20)
        }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Schema Design")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(AppColors.text)
            Text("5 entities · primary keys 🔑 and foreign keys 🔗")
                .font(.system(size: 13))
                .foregroundColor(AppColors.textSecondary)
        }
    }

    private var diagram: some View {
        ZStack(alignment: .topLeading) {
            Canvas { context, _ in
                for rel in relationships {
                    let from = anchor(of: table(rel.from).rect, rel.fromSide)
                    let to = anchor(of: table(rel.to).rect, rel.toSide)
                    DiagramDraw.relationship(&context, from: from, to: to, color: lineColor, axis: rel.axis)
                }
            }
            .frame(width: canvasSize.width, height: canvasSize.height)

            // Cardinality badges near each end of every relationship line.
            ForEach(relationships) { rel in
                let from = anchor(of: table(rel.from).rect, rel.fromSide)
                let to = anchor(of: table(rel.to).rect, rel.toSide)
                cardinalityBadge("1").position(inset(from, toward: to, by: 16))
                cardinalityBadge("∞").position(inset(to, toward: from, by: 16))
            }

            ForEach(tables) { table in
                tableCard(table).position(table.rect.centerPoint)
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
    }

    private func cardinalityBadge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(AppColors.textSecondary)
            .frame(width: 18, height: 18)
            .background(Circle().fill(AppColors.background))
            .overlay(Circle().stroke(AppColors.border, lineWidth: 1))
    }

    private func anchor(of rect: CGRect, _ side: ERSide) -> CGPoint {
        switch side {
        case .leading: return rect.leadingAnchor
        case .trailing: return rect.trailingAnchor
        case .top: return rect.topAnchor
        case .bottom: return rect.bottomAnchor
        }
    }

    /// A point `distance` away from `point` along the line toward `other` — used to nudge the
    /// cardinality badge just inside the endpoint.
    private func inset(_ point: CGPoint, toward other: CGPoint, by distance: CGFloat) -> CGPoint {
        let dx = other.x - point.x
        let dy = other.y - point.y
        let length = max(hypot(dx, dy), 0.001)
        return CGPoint(x: point.x + dx / length * distance, y: point.y + dy / length * distance)
    }

    private func tableCard(_ table: ERTable) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: table.icon).font(.system(size: 11, weight: .semibold))
                Text(table.name)
                    .font(.system(size: 13, weight: .bold))
                Spacer(minLength: 0)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .frame(height: table.headerHeight)
            .frame(maxWidth: .infinity)
            .background(table.tint)

            VStack(spacing: 0) {
                ForEach(Array(table.columns.enumerated()), id: \.offset) { index, column in
                    columnRow(column)
                    if index < table.columns.count - 1 {
                        Rectangle().fill(AppColors.border.opacity(0.6)).frame(height: 1)
                    }
                }
            }
        }
        .frame(width: table.width, height: table.height)
        .background(RoundedRectangle(cornerRadius: 10).fill(AppColors.cardBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppColors.border, lineWidth: 1.5))
    }

    private func columnRow(_ column: ERColumn) -> some View {
        HStack(spacing: 5) {
            if column.isPrimaryKey {
                Text("🔑").font(.system(size: 9))
            } else if column.isForeignKey {
                Text("🔗").font(.system(size: 9))
            } else {
                Color.clear.frame(width: 11)
            }
            Text(column.name)
                .font(.system(size: 11, weight: column.isPrimaryKey ? .semibold : .regular))
                .foregroundColor(AppColors.text)
            Spacer(minLength: 6)
            Text(column.type)
                .font(.system(size: 10))
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(.horizontal, 10)
        .frame(height: SchemaSample.rowHeight)
    }
}

enum ERSide { case leading, trailing, top, bottom }

/// A column within an ER table.
struct ERColumn {
    let name: String
    let type: String
    var isPrimaryKey: Bool = false
    var isForeignKey: Bool = false
}

/// A table (entity) box in the schema diagram, positioned by its top-left `origin`.
struct ERTable: Identifiable {
    let id: String
    let name: String
    let icon: String
    let tint: Color
    let origin: CGPoint
    let width: CGFloat
    let columns: [ERColumn]

    var headerHeight: CGFloat { 32 }
    var height: CGFloat { headerHeight + SchemaSample.rowHeight * CGFloat(columns.count) }
    var rect: CGRect { CGRect(x: origin.x, y: origin.y, width: width, height: height) }
}

/// A one-to-many relationship between two tables, with the sides its line attaches to.
struct ERRelationship: Identifiable {
    let id = UUID()
    let from: String
    let fromSide: ERSide
    let to: String
    let toSide: ERSide
    var axis: Axis = .horizontal
}

/// Static sample schema for the database-design diagram.
enum SchemaSample {
    static let rowHeight: CGFloat = 26

    static let tables: [ERTable] = [
        ERTable(id: "user", name: "User", icon: "person.fill", tint: Color(hex: "#34C759"),
                origin: CGPoint(x: 40, y: 40), width: 150, columns: [
                    ERColumn(name: "id", type: "uuid", isPrimaryKey: true),
                    ERColumn(name: "name", type: "text"),
                    ERColumn(name: "email", type: "text"),
                    ERColumn(name: "role", type: "enum"),
                ]),
        ERTable(id: "project", name: "Project", icon: "folder.fill", tint: AppColors.primary,
                origin: CGPoint(x: 300, y: 40), width: 170, columns: [
                    ERColumn(name: "id", type: "uuid", isPrimaryKey: true),
                    ERColumn(name: "owner_id", type: "uuid", isForeignKey: true),
                    ERColumn(name: "name", type: "text"),
                    ERColumn(name: "status", type: "enum"),
                    ERColumn(name: "budget", type: "money"),
                ]),
        ERTable(id: "report", name: "Report", icon: "doc.text.fill", tint: Color(hex: "#00B8A9"),
                origin: CGPoint(x: 560, y: 40), width: 150, columns: [
                    ERColumn(name: "id", type: "uuid", isPrimaryKey: true),
                    ERColumn(name: "project_id", type: "uuid", isForeignKey: true),
                    ERColumn(name: "title", type: "text"),
                    ERColumn(name: "url", type: "text"),
                ]),
        ERTable(id: "time_entry", name: "TimeEntry", icon: "clock.fill", tint: Color(hex: "#AF52DE"),
                origin: CGPoint(x: 160, y: 300), width: 180, columns: [
                    ERColumn(name: "id", type: "uuid", isPrimaryKey: true),
                    ERColumn(name: "user_id", type: "uuid", isForeignKey: true),
                    ERColumn(name: "project_id", type: "uuid", isForeignKey: true),
                    ERColumn(name: "clock_in", type: "timestamp"),
                    ERColumn(name: "clock_out", type: "timestamp"),
                ]),
        ERTable(id: "task", name: "Task", icon: "checklist", tint: Color(hex: "#FF9500"),
                origin: CGPoint(x: 470, y: 320), width: 150, columns: [
                    ERColumn(name: "id", type: "uuid", isPrimaryKey: true),
                    ERColumn(name: "project_id", type: "uuid", isForeignKey: true),
                    ERColumn(name: "title", type: "text"),
                    ERColumn(name: "done", type: "bool"),
                ]),
    ]

    static let relationships: [ERRelationship] = [
        ERRelationship(from: "user", fromSide: .trailing, to: "project", toSide: .leading, axis: .horizontal),
        ERRelationship(from: "project", fromSide: .trailing, to: "report", toSide: .leading, axis: .horizontal),
        ERRelationship(from: "project", fromSide: .bottom, to: "task", toSide: .top, axis: .vertical),
        ERRelationship(from: "user", fromSide: .bottom, to: "time_entry", toSide: .leading, axis: .vertical),
        ERRelationship(from: "project", fromSide: .bottom, to: "time_entry", toSide: .trailing, axis: .vertical),
    ]
}

#Preview {
    DatabaseDesignDiagram()
        .background(AppColors.background)
}
