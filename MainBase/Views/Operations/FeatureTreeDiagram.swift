import SwiftUI

/// Feature-tree view: a mind map of MainBase's own feature surface, radiating from the app at the
/// center out to each area (Projects, Time Tracker, ...) and their individual capabilities.
/// Static sample data, built on the shared `MindMapDiagram` renderer.
struct FeatureTreeDiagram: View {
    var body: some View {
        MindMapDiagram(title: "Feature Tree",
                       subtitle: "Every area of the app, broken down to its individual capabilities",
                       rootTitle: "MainBase",
                       rootIcon: "square.stack.3d.up.fill",
                       branches: FeatureTreeSample.branches)
    }
}

enum FeatureTreeSample {
    static let branches: [MindMapBranch] = [
        MindMapBranch(id: "projects", title: "Projects", emoji: "📁", tint: AppColors.primary, leaves: [
            MindMapLeaf(id: "tasks", title: "Tasks & Subtasks"),
            MindMapLeaf(id: "budget", title: "Budget & Expenses"),
            MindMapLeaf(id: "photos", title: "Photo Carousel"),
            MindMapLeaf(id: "chat", title: "Project Chat"),
            MindMapLeaf(id: "diagrams", title: "Diagrams"),
        ]),
        MindMapBranch(id: "time", title: "Time Tracker", emoji: "⏱️", tint: Color(hex: "#AF52DE"), leaves: [
            MindMapLeaf(id: "clock", title: "Clock In / Out"),
            MindMapLeaf(id: "history", title: "History Log"),
        ]),
        MindMapBranch(id: "schedule", title: "Schedule", emoji: "🗓️", tint: Color(hex: "#00B8A9"), leaves: [
            MindMapLeaf(id: "shifts", title: "Shift Planning"),
            MindMapLeaf(id: "flowmap", title: "Flow Map"),
        ]),
        MindMapBranch(id: "reports", title: "Reports", emoji: "📄", tint: Color(hex: "#FF9500"), leaves: [
            MindMapLeaf(id: "submit", title: "Submit Report"),
            MindMapLeaf(id: "reportchat", title: "Report Chat"),
        ]),
        MindMapBranch(id: "profile", title: "Profile & Alerts", emoji: "🔔", tint: Color(hex: "#34C759"), leaves: [
            MindMapLeaf(id: "profileinfo", title: "Profile Info"),
            MindMapLeaf(id: "notifications", title: "Notifications"),
        ]),
    ]
}

#Preview {
    FeatureTreeDiagram()
        .background(AppColors.background)
}
