import Combine
import Foundation
import FirebaseAuth
import FirebaseFirestore

private struct TaskBlueprint {
    let title: String
    let description: String
    let requiresLink: Bool
    let subtasks: [String]
}

private let defaultTaskBlueprint: [TaskBlueprint] = [
    TaskBlueprint(
        title: "Generate a blog post about traveling around your city and share Google Doc link",
        description: "Shareable Google Doc link is required to complete this task.",
        requiresLink: true,
        subtasks: ["Waiting on Ibrahim to publish on website"]
    ),
    TaskBlueprint(
        title: "Use Tourbook app to create an itinerary and share link",
        description: "Create itinerary and attach the link.",
        requiresLink: true,
        subtasks: []
    ),
    TaskBlueprint(
        title: "Gather reels/photos for content and share Google Drive link",
        description: "Upload media to Drive and share the URL.",
        requiresLink: true,
        subtasks: ["Create a reel with CapCut, Adobe Premiere, or Instagram Edit", "Choose 10 photos for a carousel"]
    ),
    TaskBlueprint(
        title: "Post reel/carousel/shortened blog post to Facebook group and share post link",
        description: "Include caption and hashtags.",
        requiresLink: true,
        subtasks: ["Waiting on Cynthia to publish on TikTok"]
    ),
    TaskBlueprint(
        title: "Receive instruction for keyword research, blog optimization, GA4, and Meta Business Suite",
        description: "Track process updates and complete once instruction is done.",
        requiresLink: false,
        subtasks: []
    ),
]

struct ProjectActionResult {
    let success: Bool
    let error: String?

    static let ok = ProjectActionResult(success: true, error: nil)
    static func failure(_ message: String) -> ProjectActionResult {
        ProjectActionResult(success: false, error: message)
    }
}

@MainActor
final class ProjectsViewModel: ObservableObject {
    @Published private(set) var projects: [Project] = []
    @Published private(set) var isLoadingProjects = false
    @Published private(set) var isSavingTask = false
    @Published private(set) var assignableUserEmails: [String] = []
    @Published private(set) var currentUserEmail: String = ""

    private let db = Firestore.firestore()

    private func loadCurrentUserEmail() async -> String {
        guard let uid = Auth.auth().currentUser?.uid else { return "" }
        let fallback = Auth.auth().currentUser?.email ?? ""
        do {
            let snapshot = try await db.collection("users").document(uid).getDocument()
            return (snapshot.data()?["email"] as? String)?.trimmingCharacters(in: .whitespaces) ?? fallback
        } catch {
            return fallback
        }
    }

    private func normalizeStatus(_ raw: Any?) -> ProjectStatus {
        (raw as? String) == ProjectStatus.completed.rawValue ? .completed : .inProgress
    }

    private func normalizeTimestamp(_ raw: Any?) -> Date? {
        (raw as? Timestamp)?.dateValue()
    }

    // MARK: - Fetch

    func loadProjects() async {
        isLoadingProjects = true
        defer { isLoadingProjects = false }
        async let fetchedProjects = fetchProjects()
        async let fetchedEmails = fetchAssignableUserEmails()
        async let fetchedUserEmail = loadCurrentUserEmail()
        let (loadedProjects, loadedEmails, userEmail) = await (fetchedProjects, fetchedEmails, fetchedUserEmail)
        projects = loadedProjects
        currentUserEmail = userEmail
        let lead = userEmail.trimmingCharacters(in: .whitespaces)
        if !lead.isEmpty {
            assignableUserEmails = Array(Set([lead] + loadedEmails)).sorted()
        } else {
            assignableUserEmails = loadedEmails
        }
    }

    private func fetchTaskSubtasks(projectId: String, taskId: String) async -> [ProjectSubtask] {
        do {
            let snapshot = try await db.collection("projects").document(projectId)
                .collection("tasks").document(taskId)
                .collection("subtasks")
                .order(by: "order", descending: false)
                .getDocuments()
            return snapshot.documents.map { doc in
                let data = doc.data()
                return ProjectSubtask(
                    id: doc.documentID,
                    title: data["title"] as? String ?? "",
                    status: normalizeStatus(data["status"]),
                    assigneeEmail: data["assigneeEmail"] as? String ?? "",
                    completedAt: normalizeTimestamp(data["completedAt"]),
                    order: data["order"] as? Int ?? 0
                )
            }
        } catch {
            return []
        }
    }

    private func fetchProjects() async -> [Project] {
        do {
            let projectsSnapshot = try await db.collection("projects")
                .order(by: "createdAt", descending: true)
                .getDocuments()

            return await withTaskGroup(of: (Int, Project).self) { group in
                for (index, projectDoc) in projectsSnapshot.documents.enumerated() {
                    group.addTask {
                        (index, await self.fetchProject(projectDoc))
                    }
                }
                var indexed: [(Int, Project)] = []
                for await result in group {
                    indexed.append(result)
                }
                return indexed.sorted { $0.0 < $1.0 }.map { $0.1 }
            }
        } catch {
            return []
        }
    }

    private func fetchProject(_ projectDoc: QueryDocumentSnapshot) async -> Project {
        let projectData = projectDoc.data()
        let tasks = await fetchTasks(projectId: projectDoc.documentID)
        let allTasksCompleted = !tasks.isEmpty && tasks.allSatisfy { $0.status == .completed }
        return Project(
            id: projectDoc.documentID,
            projectTitle: projectData["projectTitle"] as? String ?? "",
            projectDescription: projectData["projectDescription"] as? String ?? "",
            projectLead: projectData["projectLead"] as? String ?? "",
            label: (projectData["label"] as? String) == ProjectLabel.socials.rawValue ? .socials : .standard,
            status: allTasksCompleted ? .completed : .inProgress,
            createdAt: normalizeTimestamp(projectData["createdAt"]),
            updatedAt: normalizeTimestamp(projectData["updatedAt"]),
            tasks: tasks
        )
    }

    private func fetchTasks(projectId: String) async -> [ProjectTask] {
        do {
            let tasksSnapshot = try await db.collection("projects").document(projectId)
                .collection("tasks")
                .order(by: "order", descending: false)
                .getDocuments()

            return await withTaskGroup(of: (Int, ProjectTask).self) { group in
                for (index, taskDoc) in tasksSnapshot.documents.enumerated() {
                    group.addTask {
                        let taskData = taskDoc.data()
                        let subtasks = await self.fetchTaskSubtasks(projectId: projectId, taskId: taskDoc.documentID)
                        let task = ProjectTask(
                            id: taskDoc.documentID,
                            title: taskData["title"] as? String ?? "",
                            description: taskData["description"] as? String ?? "",
                            status: await self.normalizeStatus(taskData["status"]),
                            requiresLink: taskData["requiresLink"] as? Bool ?? false,
                            proofLink: taskData["proofLink"] as? String ?? "",
                            assigneeEmail: taskData["assigneeEmail"] as? String ?? "",
                            completedAt: await self.normalizeTimestamp(taskData["completedAt"]),
                            order: taskData["order"] as? Int ?? 0,
                            subtasks: subtasks
                        )
                        return (index, task)
                    }
                }
                var indexed: [(Int, ProjectTask)] = []
                for await result in group {
                    indexed.append(result)
                }
                return indexed.sorted { $0.0 < $1.0 }.map { $0.1 }
            }
        } catch {
            return []
        }
    }

    func fetchAssignableUserEmails() async -> [String] {
        do {
            let snapshot = try await db.collection("users").getDocuments()
            let emails = snapshot.documents.compactMap { doc -> String? in
                let email = (doc.data()["email"] as? String)?.trimmingCharacters(in: .whitespaces) ?? ""
                return email.isEmpty ? nil : email
            }
            return Array(Set(emails)).sorted()
        } catch {
            return []
        }
    }

    private func getProjectLeadEmail(projectId: String) async -> String {
        do {
            let snapshot = try await db.collection("projects").document(projectId).getDocument()
            return (snapshot.data()?["projectLead"] as? String)?.trimmingCharacters(in: .whitespaces) ?? ""
        } catch {
            return ""
        }
    }

    // MARK: - Mutations

    func submitProject(title: String, description: String, label: ProjectLabel) async -> ProjectActionResult {
        let projectTitle = title.trimmingCharacters(in: .whitespaces)
        let projectDescription = description.trimmingCharacters(in: .whitespaces)
        let projectLead = currentUserEmail.trimmingCharacters(in: .whitespaces)
        guard !projectTitle.isEmpty else { return .failure("Project title is required.") }
        guard !projectLead.isEmpty else { return .failure("Missing project lead email. Please sign in again.") }

        do {
            let projectRef = try await db.collection("projects").addDocument(data: [
                "projectTitle": projectTitle,
                "projectDescription": projectDescription,
                "projectLead": projectLead,
                "label": label.rawValue,
                "status": ProjectStatus.inProgress.rawValue,
                "createdAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp(),
            ])

            if label == .socials {
                for (index, blueprint) in defaultTaskBlueprint.enumerated() {
                    let taskRef = try await projectRef.collection("tasks").addDocument(data: [
                        "title": blueprint.title,
                        "description": blueprint.description,
                        "status": ProjectStatus.inProgress.rawValue,
                        "requiresLink": blueprint.requiresLink,
                        "proofLink": "",
                        "assigneeEmail": projectLead,
                        "completedAt": NSNull(),
                        "order": index,
                        "createdAt": FieldValue.serverTimestamp(),
                        "updatedAt": FieldValue.serverTimestamp(),
                    ])
                    for (subIndex, subtaskTitle) in blueprint.subtasks.enumerated() {
                        try await taskRef.collection("subtasks").addDocument(data: [
                            "title": subtaskTitle,
                            "status": ProjectStatus.inProgress.rawValue,
                            "assigneeEmail": "",
                            "completedAt": NSNull(),
                            "order": subIndex,
                            "createdAt": FieldValue.serverTimestamp(),
                            "updatedAt": FieldValue.serverTimestamp(),
                        ])
                    }
                }
            }
            await loadProjects()
            return .ok
        } catch {
            return .failure("Could not create project. Please try again.")
        }
    }

    func submitAddTask(projectId: String, title: String, assigneeEmail: String, requiresLink: Bool) async -> ProjectActionResult {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return .failure("Task title is required.") }
        isSavingTask = true
        defer { isSavingTask = false }
        do {
            let projectLead = await getProjectLeadEmail(projectId: projectId)
            let trimmedAssignee = assigneeEmail.trimmingCharacters(in: .whitespaces)
            let resolvedAssignee = trimmedAssignee.isEmpty ? projectLead : trimmedAssignee
            let existingTasks = try await db.collection("projects").document(projectId).collection("tasks").getDocuments()
            try await db.collection("projects").document(projectId).collection("tasks").addDocument(data: [
                "title": trimmedTitle,
                "description": "",
                "status": ProjectStatus.inProgress.rawValue,
                "requiresLink": requiresLink,
                "proofLink": "",
                "assigneeEmail": resolvedAssignee,
                "completedAt": NSNull(),
                "order": existingTasks.count,
                "createdAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp(),
            ])
            await loadProjects()
            return .ok
        } catch {
            return .failure("Could not add task right now.")
        }
    }

    func submitAddSubtask(projectId: String, taskId: String, title: String, assigneeEmail: String) async -> ProjectActionResult {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return .failure("Subtask title is required.") }
        isSavingTask = true
        defer { isSavingTask = false }
        do {
            let taskRef = db.collection("projects").document(projectId).collection("tasks").document(taskId)
            let existingSubtasks = try await taskRef.collection("subtasks").getDocuments()
            try await taskRef.collection("subtasks").addDocument(data: [
                "title": trimmedTitle,
                "status": ProjectStatus.inProgress.rawValue,
                "assigneeEmail": assigneeEmail.trimmingCharacters(in: .whitespaces),
                "completedAt": NSNull(),
                "order": existingSubtasks.count,
                "createdAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp(),
            ])
            await loadProjects()
            return .ok
        } catch {
            return .failure("Could not add subtask right now.")
        }
    }

    func submitTaskLink(projectId: String, taskId: String, proofLink: String) async -> ProjectActionResult {
        isSavingTask = true
        defer { isSavingTask = false }
        let trimmedLink = proofLink.trimmingCharacters(in: .whitespaces)
        do {
            try await db.collection("projects").document(projectId).collection("tasks").document(taskId).updateData([
                "proofLink": trimmedLink,
                "status": trimmedLink.isEmpty ? ProjectStatus.inProgress.rawValue : ProjectStatus.completed.rawValue,
                "completedAt": trimmedLink.isEmpty ? NSNull() : FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp(),
            ])
            await loadProjects()
            return .ok
        } catch {
            return .failure("Could not update task link.")
        }
    }

    func submitCompleteSubtask(projectId: String, taskId: String, subtaskId: String, isCompleted: Bool) async -> ProjectActionResult {
        isSavingTask = true
        defer { isSavingTask = false }
        do {
            try await db.collection("projects").document(projectId).collection("tasks").document(taskId)
                .collection("subtasks").document(subtaskId).updateData([
                    "status": isCompleted ? ProjectStatus.completed.rawValue : ProjectStatus.inProgress.rawValue,
                    "completedAt": isCompleted ? FieldValue.serverTimestamp() : NSNull(),
                    "updatedAt": FieldValue.serverTimestamp(),
                ])
            await loadProjects()
            return .ok
        } catch {
            return .failure("Could not mark subtask complete.")
        }
    }

    func submitToggleTaskCompletion(projectId: String, taskId: String, isCompleted: Bool) async -> ProjectActionResult {
        isSavingTask = true
        defer { isSavingTask = false }
        do {
            try await db.collection("projects").document(projectId).collection("tasks").document(taskId).updateData([
                "status": isCompleted ? ProjectStatus.completed.rawValue : ProjectStatus.inProgress.rawValue,
                "completedAt": isCompleted ? FieldValue.serverTimestamp() : NSNull(),
                "updatedAt": FieldValue.serverTimestamp(),
            ])
            await loadProjects()
            return .ok
        } catch {
            return .failure("Could not update task status.")
        }
    }

    func submitEditTask(projectId: String, taskId: String, title: String, requiresLink: Bool, assigneeEmail: String) async -> ProjectActionResult {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return .failure("Task title is required.") }
        isSavingTask = true
        defer { isSavingTask = false }
        do {
            try await db.collection("projects").document(projectId).collection("tasks").document(taskId).updateData([
                "title": trimmedTitle,
                "requiresLink": requiresLink,
                "assigneeEmail": assigneeEmail.trimmingCharacters(in: .whitespaces),
                "updatedAt": FieldValue.serverTimestamp(),
            ])
            await loadProjects()
            return .ok
        } catch {
            return .failure("Could not update task right now.")
        }
    }

    func submitDeleteTask(projectId: String, taskId: String) async -> ProjectActionResult {
        isSavingTask = true
        defer { isSavingTask = false }
        do {
            let taskRef = db.collection("projects").document(projectId).collection("tasks").document(taskId)
            let subtasksSnapshot = try await taskRef.collection("subtasks").getDocuments()
            for subtaskDoc in subtasksSnapshot.documents {
                try await taskRef.collection("subtasks").document(subtaskDoc.documentID).delete()
            }
            try await taskRef.delete()
            await loadProjects()
            return .ok
        } catch {
            return .failure("Could not delete task right now.")
        }
    }

    func submitDeleteSubtask(projectId: String, taskId: String, subtaskId: String) async -> ProjectActionResult {
        isSavingTask = true
        defer { isSavingTask = false }
        do {
            try await db.collection("projects").document(projectId).collection("tasks").document(taskId)
                .collection("subtasks").document(subtaskId).delete()
            await loadProjects()
            return .ok
        } catch {
            return .failure("Could not delete subtask right now.")
        }
    }
}
