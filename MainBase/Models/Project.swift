import Foundation

enum ProjectStatus: String {
    case inProgress = "in progress"
    case completed = "completed"
}

enum ProjectLabel: String, CaseIterable {
    case marketing
    case development

    var displayName: String {
        switch self {
        case .marketing: return "Marketing"
        case .development: return "Development"
        }
    }

    var sublabelOptions: [String] {
        switch self {
        case .marketing:
            return ["SEO", "Meta Ads", "Social Media", "Analytics", "Influencer collabs", "IRL", "Other"]
        case .development:
            return ["Systems", "Mobile", "Web", "WordPress", "Design", "IRL", "Other"]
        }
    }
}

/// The flat set of sublabels a project can be tagged with. Projects no longer carry a
/// Marketing/Development label — you just pick any number of these directly.
enum ProjectSublabels {
    static let allOptions = [
        "SEO", "Meta Ads", "Social Media", "Analytics", "Influencer collabs",
        "Systems", "Mobile", "Web", "WordPress", "Design", "IRL", "Other",
    ]
}

struct ProjectSubtask: Identifiable {
    let id: String
    var title: String
    var status: ProjectStatus
    var assigneeEmail: String
    var createdAt: Date?
    var completedAt: Date?
    var order: Int

    var isCompleted: Bool { status == .completed }
}

struct ProjectTask: Identifiable {
    let id: String
    var title: String
    var description: String
    var status: ProjectStatus
    var assigneeEmail: String
    var createdAt: Date?
    var completedAt: Date?
    var order: Int
    var subtasks: [ProjectSubtask]

    var isCompleted: Bool { status == .completed }
}

struct Project: Identifiable {
    let id: String
    var projectTitle: String
    var projectDescription: String
    var projectLead: String
    var teamMembers: [String]
    var projectMainId: String?
    var label: ProjectLabel?
    var sublabels: [String]
    var photoURLs: [String]
    var budget: Double?
    var status: ProjectStatus
    var isArchived: Bool
    var createdAt: Date?
    var updatedAt: Date?
    var tasks: [ProjectTask]
}
