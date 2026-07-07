import Foundation

enum ProjectStatus: String {
    case inProgress = "in progress"
    case completed = "completed"
}

enum ProjectLabel: String {
    case standard = ""
    case socials = "socials"
}

struct ProjectSubtask: Identifiable {
    let id: String
    var title: String
    var status: ProjectStatus
    var assigneeEmail: String
    var completedAt: Date?
    var order: Int

    var isCompleted: Bool { status == .completed }
}

struct ProjectTask: Identifiable {
    let id: String
    var title: String
    var description: String
    var status: ProjectStatus
    var requiresLink: Bool
    var proofLink: String
    var assigneeEmail: String
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
    var label: ProjectLabel
    var status: ProjectStatus
    var createdAt: Date?
    var updatedAt: Date?
    var tasks: [ProjectTask]
}
