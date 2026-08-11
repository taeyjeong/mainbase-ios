import Combine
import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import UIKit

/// Deterministic seed IDs/colors for the built-in Mains, so seeding is idempotent
/// (re-running never clobbers an admin's edits to name/color) and multiple clients
/// racing to seed on first launch just write the same content.
private let defaultProjectMains: [ProjectMain] = [
    ProjectMain(id: "la-coach-tours", name: "LA Coach Tours", colorHex: "#FF3B30"),
    ProjectMain(id: "us-group-travel", name: "US Group Travel", colorHex: "#34C759"),
    ProjectMain(id: "tourbook-app", name: "TourBook app", colorHex: "#0A84FF"),
    ProjectMain(id: "cinq-app", name: "Cinq app", colorHex: "#AF52DE"),
]

struct ProjectActionResult {
    let success: Bool
    let error: String?

    static let ok = ProjectActionResult(success: true, error: nil)
    static func failure(_ message: String) -> ProjectActionResult {
        ProjectActionResult(success: false, error: message)
    }
}

struct TaskSubmissionResult {
    let success: Bool
    let error: String?
    let taskId: String?

    static func ok(_ taskId: String) -> TaskSubmissionResult {
        TaskSubmissionResult(success: true, error: nil, taskId: taskId)
    }
    static func failure(_ message: String) -> TaskSubmissionResult {
        TaskSubmissionResult(success: false, error: message, taskId: nil)
    }
}

/// A task (with optional subtasks) not yet saved, composed in the multi-task add sheet.
struct DraftTask: Identifiable {
    let id = UUID()
    var title: String = ""
    var assigneeEmail: String = ""
    var subtasks: [DraftSubtask] = []
}

struct DraftSubtask: Identifiable {
    let id = UUID()
    var title: String = ""
    var assigneeEmail: String = ""
}

@MainActor
final class ProjectsViewModel: ObservableObject {
    @Published private(set) var projects: [Project] = []
    @Published private(set) var isLoadingProjects = false
    @Published private(set) var assignableUserEmails: [String] = []
    @Published private(set) var assignableTeamMembers: [AssignableUser] = []
    @Published private(set) var userNamesByEmail: [String: String] = [:]
    @Published private(set) var userFirstNamesByEmail: [String: String] = [:]
    @Published private(set) var userEmojisByEmail: [String: String] = [:]
    @Published private(set) var currentUserEmail: String = ""
    @Published private(set) var currentUserIsAdmin: Bool = false
    @Published private(set) var archivedProjects: [Project] = []
    @Published private(set) var isLoadingArchivedProjects = false
    @Published private(set) var projectMains: [ProjectMain] = []
    @Published private(set) var currentChatMessages: [ProjectChatMessage] = []
    @Published private(set) var currentExpenses: [ProjectExpense] = []

    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    private var projectMainsListener: ListenerRegistration?
    private var chatListener: ListenerRegistration?
    private var expensesListener: ListenerRegistration?
    private var hasAttemptedMainsSeed = false

    func projectMain(withId id: String?) -> ProjectMain? {
        guard let id else { return nil }
        return projectMains.first { $0.id == id }
    }

    func startProjectMainsListener() {
        guard projectMainsListener == nil else { return }
        projectMainsListener = db.collection("projectMains").addSnapshotListener { [weak self] snapshot, _ in
            guard let self, let documents = snapshot?.documents else { return }
            self.projectMains = documents.map { doc in
                let data = doc.data()
                return ProjectMain(
                    id: doc.documentID,
                    name: data["name"] as? String ?? "",
                    colorHex: data["colorHex"] as? String ?? "#999999"
                )
            }
            if documents.isEmpty, !self.hasAttemptedMainsSeed {
                self.hasAttemptedMainsSeed = true
                Task { await self.seedDefaultProjectMainsIfNeeded() }
            }
        }
    }

    private func seedDefaultProjectMainsIfNeeded() async {
        let batch = db.batch()
        for main in defaultProjectMains {
            let ref = db.collection("projectMains").document(main.id)
            batch.setData([
                "name": main.name,
                "colorHex": main.colorHex,
                "createdAt": FieldValue.serverTimestamp(),
            ], forDocument: ref, merge: true)
        }
        try? await batch.commit()
    }

    private func loadCurrentUserInfo() async -> (email: String, isAdmin: Bool) {
        guard let uid = Auth.auth().currentUser?.uid else { return ("", false) }
        let fallback = Auth.auth().currentUser?.email ?? ""
        do {
            let snapshot = try await db.collection("users").document(uid).getDocument()
            let data = snapshot.data()
            let email = (data?["email"] as? String)?.trimmingCharacters(in: .whitespaces) ?? fallback
            let isAdmin = data?["admin"] as? Bool ?? false
            return (email, isAdmin)
        } catch {
            return (fallback, false)
        }
    }

    // MARK: - Permissions

    func canEditOrArchive(_ project: Project) -> Bool {
        currentUserIsAdmin || project.projectLead.caseInsensitiveCompare(currentUserEmail) == .orderedSame
    }

    func canDelete(_ project: Project) -> Bool {
        currentUserIsAdmin
    }

    private func normalizeStatus(_ raw: Any?) -> ProjectStatus {
        (raw as? String) == ProjectStatus.completed.rawValue ? .completed : .inProgress
    }

    private func normalizeTimestamp(_ raw: Any?) -> Date? {
        (raw as? Timestamp)?.dateValue()
    }

    // MARK: - Fetch

    func loadProjects() async {
        startProjectMainsListener()
        isLoadingProjects = true
        defer { isLoadingProjects = false }
        async let fetchedProjects = fetchProjects()
        async let fetchedUsers = fetchAssignableUsers()
        async let fetchedUserInfo = loadCurrentUserInfo()
        let (loadedProjects, loadedUsers, userInfo) = await (fetchedProjects, fetchedUsers, fetchedUserInfo)
        projects = loadedProjects.filter { !$0.isArchived }
        currentUserEmail = userInfo.email
        currentUserIsAdmin = userInfo.isAdmin
        userNamesByEmail = Dictionary(uniqueKeysWithValues: loadedUsers.map { ($0.email.lowercased(), $0.name) })
        userFirstNamesByEmail = Dictionary(uniqueKeysWithValues: loadedUsers.map { ($0.email.lowercased(), $0.firstName) })
        userEmojisByEmail = Dictionary(uniqueKeysWithValues: loadedUsers.map { ($0.email.lowercased(), $0.emoji) })
        assignableTeamMembers = loadedUsers
            .filter { $0.isEmployed }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        let lead = userInfo.email.trimmingCharacters(in: .whitespaces)
        let allEmails = loadedUsers.map { $0.email }
        if !lead.isEmpty {
            assignableUserEmails = Array(Set([lead] + allEmails)).sorted()
        } else {
            assignableUserEmails = allEmails.sorted()
        }
    }

    func displayName(forEmail email: String) -> String {
        userNamesByEmail[email.trimmingCharacters(in: .whitespaces).lowercased()] ?? email
    }

    /// First name plus the person's chosen profile emoji (e.g. "Sarah 🌵"), used where a compact,
    /// scannable roster of people is shown, like the team-members line on a project card.
    func teamMemberTag(forEmail email: String) -> String {
        let key = email.trimmingCharacters(in: .whitespaces).lowercased()
        let firstName = userFirstNamesByEmail[key] ?? email
        guard let emoji = userEmojisByEmail[key], !emoji.isEmpty else { return firstName }
        return "\(firstName) \(emoji)"
    }

    /// Just the person's profile emoji — used on project cards where the lead/members line shows
    /// emojis instead of names. Falls back to the first name if they haven't set an emoji yet.
    func emojiTag(forEmail email: String) -> String {
        let key = email.trimmingCharacters(in: .whitespaces).lowercased()
        if let emoji = userEmojisByEmail[key], !emoji.isEmpty { return emoji }
        return userFirstNamesByEmail[key] ?? email
    }

    func loadArchivedProjects() async {
        isLoadingArchivedProjects = true
        defer { isLoadingArchivedProjects = false }
        // Also load user info/names here so this view works standalone (it's opened from Profile,
        // which doesn't run loadProjects): unarchive needs the admin flag, and rows show lead names.
        async let fetchedProjects = fetchProjects()
        async let fetchedUsers = fetchAssignableUsers()
        async let fetchedUserInfo = loadCurrentUserInfo()
        let (allProjects, loadedUsers, userInfo) = await (fetchedProjects, fetchedUsers, fetchedUserInfo)
        currentUserEmail = userInfo.email
        currentUserIsAdmin = userInfo.isAdmin
        if userNamesByEmail.isEmpty {
            userNamesByEmail = Dictionary(uniqueKeysWithValues: loadedUsers.map { ($0.email.lowercased(), $0.name) })
        }
        archivedProjects = allProjects.filter { $0.isArchived }
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
                    createdAt: normalizeTimestamp(data["createdAt"]),
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
            teamMembers: projectData["teamMembers"] as? [String] ?? [],
            projectMainId: projectData["projectMainId"] as? String,
            label: (projectData["label"] as? String).flatMap(ProjectLabel.init(rawValue:)),
            sublabels: projectData["sublabels"] as? [String] ?? [],
            photoURLs: projectData["photoURLs"] as? [String] ?? [],
            budget: projectData["budget"] as? Double,
            status: allTasksCompleted ? .completed : .inProgress,
            isArchived: projectData["isArchived"] as? Bool ?? false,
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
                            assigneeEmail: taskData["assigneeEmail"] as? String ?? "",
                            createdAt: await self.normalizeTimestamp(taskData["createdAt"]),
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

    private func fetchAssignableUsers() async -> [AssignableUser] {
        do {
            let snapshot = try await db.collection("users").getDocuments()
            var seenEmails = Set<String>()
            var users: [AssignableUser] = []
            for doc in snapshot.documents {
                let data = doc.data()
                let email = (data["email"] as? String)?.trimmingCharacters(in: .whitespaces) ?? ""
                guard !email.isEmpty, seenEmails.insert(email.lowercased()).inserted else { continue }
                let name = (data["name"] as? String)?.trimmingCharacters(in: .whitespaces) ?? ""
                let surname = (data["surname"] as? String) ?? ""
                let emoji = (data["emoji"] as? String) ?? ""
                let isEmployed = data["isEmployed"] as? Bool ?? false
                let displayName = name.isEmpty ? email : formattedDisplayName(name: name, surname: surname)
                let firstName = name.isEmpty ? email : name
                users.append(AssignableUser(email: email, name: displayName, firstName: firstName, emoji: emoji, isEmployed: isEmployed))
            }
            return users
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

    private func getTaskTitle(projectId: String, taskId: String) async -> String {
        do {
            let snapshot = try await db.collection("projects").document(projectId).collection("tasks").document(taskId).getDocument()
            return (snapshot.data()?["title"] as? String) ?? "a task"
        } catch {
            return "a task"
        }
    }

    // MARK: - Activity log

    /// Posts an italicized, timestamped entry into the project's chat feed describing an
    /// action someone just took (task/subtask added or completed, photo added, message pinned).
    private func logActivity(projectId: String, text: String) async {
        try? await db.collection("projects").document(projectId).collection("chatMessages").addDocument(data: [
            "text": text,
            "senderEmail": currentUserEmail,
            "isPinned": false,
            "isSystemEvent": true,
            "createdAt": FieldValue.serverTimestamp(),
        ])
    }

    private func actorName() -> String {
        displayName(forEmail: currentUserEmail)
    }

    /// Formats upload indices as "#3", "#3 & #4", or "#3, #4 & #5".
    private func photoNumberList(startingAt start: Int, count: Int) -> String {
        let numbers = (0..<count).map { "#\(start + $0 + 1)" }
        guard numbers.count > 1 else { return numbers.first ?? "" }
        return "\(numbers.dropLast().joined(separator: ", ")) & \(numbers.last!)"
    }

    // MARK: - Mutations

    private func cleanedEmailList(_ emails: [String]) -> [String] {
        Array(Set(emails.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })).sorted()
    }

    func submitProject(
        title: String,
        description: String,
        projectMainId: String,
        sublabels: [String],
        teamMembers: [String],
        budget: Double?
    ) async -> ProjectActionResult {
        let projectTitle = title.trimmingCharacters(in: .whitespaces)
        let projectDescription = description.trimmingCharacters(in: .whitespaces)
        let projectLead = currentUserEmail.trimmingCharacters(in: .whitespaces)
        guard !projectTitle.isEmpty else { return .failure("Project title is required.") }
        guard !projectLead.isEmpty else { return .failure("Missing project lead email. Please sign in again.") }
        guard !projectMainId.isEmpty else { return .failure("Please select a Main.") }

        do {
            _ = try await db.collection("projects").addDocument(data: [
                "projectTitle": projectTitle,
                "projectDescription": projectDescription,
                "projectLead": projectLead,
                "teamMembers": cleanedEmailList(teamMembers),
                "projectMainId": projectMainId,
                "label": "",
                "sublabels": sublabels,
                "photoURLs": [String](),
                "budget": budget.map { $0 as Any } ?? NSNull(),
                "status": ProjectStatus.inProgress.rawValue,
                "isArchived": false,
                "createdAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp(),
            ])
            await loadProjects()
            return .ok
        } catch {
            return .failure("Could not create project. Please try again.")
        }
    }

    @discardableResult
    func submitAddTask(projectId: String, title: String, assigneeEmail: String) async -> TaskSubmissionResult {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return .failure("Task title is required.") }
        do {
            let projectLead = await getProjectLeadEmail(projectId: projectId)
            let trimmedAssignee = assigneeEmail.trimmingCharacters(in: .whitespaces)
            let resolvedAssignee = trimmedAssignee.isEmpty ? projectLead : trimmedAssignee
            let existingTasks = try await db.collection("projects").document(projectId).collection("tasks").getDocuments()
            let taskRef = try await db.collection("projects").document(projectId).collection("tasks").addDocument(data: [
                "title": trimmedTitle,
                "description": "",
                "status": ProjectStatus.inProgress.rawValue,
                "assigneeEmail": resolvedAssignee,
                "assignedByEmail": currentUserEmail,
                "completedAt": NSNull(),
                "order": existingTasks.count,
                "createdAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp(),
            ])
            await logActivity(projectId: projectId, text: "\(actorName()) added a task '\(trimmedTitle)'")
            await loadProjects()
            return .ok(taskRef.documentID)
        } catch {
            return .failure("Could not add task right now.")
        }
    }

    /// Creates a task and any subtasks composed alongside it in the multi-task add sheet.
    func submitAddTaskWithSubtasks(projectId: String, title: String, assigneeEmail: String, subtasks: [DraftSubtask]) async -> ProjectActionResult {
        let taskResult = await submitAddTask(projectId: projectId, title: title, assigneeEmail: assigneeEmail)
        guard taskResult.success, let taskId = taskResult.taskId else {
            return .failure(taskResult.error ?? "Could not add task right now.")
        }
        for subtask in subtasks where !subtask.title.trimmingCharacters(in: .whitespaces).isEmpty {
            let result = await submitAddSubtask(projectId: projectId, taskId: taskId, title: subtask.title, assigneeEmail: subtask.assigneeEmail)
            if !result.success { return result }
        }
        return .ok
    }

    func submitAddSubtask(projectId: String, taskId: String, title: String, assigneeEmail: String) async -> ProjectActionResult {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return .failure("Subtask title is required.") }
        do {
            let taskRef = db.collection("projects").document(projectId).collection("tasks").document(taskId)
            let existingSubtasks = try await taskRef.collection("subtasks").getDocuments()
            let trimmedAssignee = assigneeEmail.trimmingCharacters(in: .whitespaces)
            try await taskRef.collection("subtasks").addDocument(data: [
                "title": trimmedTitle,
                "status": ProjectStatus.inProgress.rawValue,
                "assigneeEmail": trimmedAssignee,
                "assignedByEmail": currentUserEmail,
                "completedAt": NSNull(),
                "order": existingSubtasks.count,
                "createdAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp(),
            ])
            let taskTitle = await getTaskTitle(projectId: projectId, taskId: taskId)
            var activityText = "\(actorName()) added a subtask '\(trimmedTitle)' to task '\(taskTitle)'"
            if !trimmedAssignee.isEmpty {
                activityText += " & assigned \(displayName(forEmail: trimmedAssignee))"
            }
            await logActivity(projectId: projectId, text: activityText)
            await loadProjects()
            return .ok
        } catch {
            return .failure("Could not add subtask right now.")
        }
    }

    func canManage(projectId: String, assigneeEmail: String) -> Bool {
        if currentUserIsAdmin { return true }
        if let project = projects.first(where: { $0.id == projectId }) ?? archivedProjects.first(where: { $0.id == projectId }),
           !project.projectLead.isEmpty, project.projectLead.caseInsensitiveCompare(currentUserEmail) == .orderedSame {
            return true
        }
        return !assigneeEmail.isEmpty && assigneeEmail.caseInsensitiveCompare(currentUserEmail) == .orderedSame
    }

    func submitCompleteSubtask(projectId: String, taskId: String, subtaskId: String, isCompleted: Bool) async -> ProjectActionResult {
        guard let task = projects.first(where: { $0.id == projectId })?.tasks.first(where: { $0.id == taskId }),
              let subtask = task.subtasks.first(where: { $0.id == subtaskId }),
              canManage(projectId: projectId, assigneeEmail: subtask.assigneeEmail) else {
            return .failure("Only the assignee, project lead, or an admin can complete this subtask.")
        }
        do {
            try await db.collection("projects").document(projectId).collection("tasks").document(taskId)
                .collection("subtasks").document(subtaskId).updateData([
                    "status": isCompleted ? ProjectStatus.completed.rawValue : ProjectStatus.inProgress.rawValue,
                    "completedAt": isCompleted ? FieldValue.serverTimestamp() : NSNull(),
                    "completedByEmail": currentUserEmail,
                    "updatedAt": FieldValue.serverTimestamp(),
                ])
            if isCompleted {
                await logActivity(projectId: projectId, text: "\(actorName()) completed subtask '\(subtask.title)'")
            }
            await loadProjects()
            return .ok
        } catch {
            return .failure("Could not mark subtask complete.")
        }
    }

    func submitToggleTaskCompletion(projectId: String, taskId: String, isCompleted: Bool) async -> ProjectActionResult {
        guard let task = projects.first(where: { $0.id == projectId })?.tasks.first(where: { $0.id == taskId }),
              canManage(projectId: projectId, assigneeEmail: task.assigneeEmail) else {
            return .failure("Only the assignee, project lead, or an admin can complete this task.")
        }
        do {
            try await db.collection("projects").document(projectId).collection("tasks").document(taskId).updateData([
                "status": isCompleted ? ProjectStatus.completed.rawValue : ProjectStatus.inProgress.rawValue,
                "completedAt": isCompleted ? FieldValue.serverTimestamp() : NSNull(),
                "completedByEmail": currentUserEmail,
                "updatedAt": FieldValue.serverTimestamp(),
            ])
            if isCompleted {
                await logActivity(projectId: projectId, text: "\(actorName()) completed task '\(task.title)'")
            }
            await loadProjects()
            return .ok
        } catch {
            return .failure("Could not update task status.")
        }
    }

    func submitEditTask(projectId: String, taskId: String, title: String, assigneeEmail: String) async -> ProjectActionResult {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return .failure("Task title is required.") }
        guard let existingTask = projects.first(where: { $0.id == projectId })?.tasks.first(where: { $0.id == taskId }),
              canManage(projectId: projectId, assigneeEmail: existingTask.assigneeEmail) else {
            return .failure("Only the assignee, project lead, or an admin can edit this task.")
        }
        do {
            try await db.collection("projects").document(projectId).collection("tasks").document(taskId).updateData([
                "title": trimmedTitle,
                "assigneeEmail": assigneeEmail.trimmingCharacters(in: .whitespaces),
                "assignedByEmail": currentUserEmail,
                "updatedAt": FieldValue.serverTimestamp(),
            ])
            await loadProjects()
            return .ok
        } catch {
            return .failure("Could not update task right now.")
        }
    }

    func submitDeleteTask(projectId: String, taskId: String) async -> ProjectActionResult {
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

    func submitEditProject(
        projectId: String,
        title: String,
        description: String,
        projectLead: String,
        teamMembers: [String],
        projectMainId: String,
        sublabels: [String],
        budget: Double?
    ) async -> ProjectActionResult {
        guard let existing = projects.first(where: { $0.id == projectId }) else {
            return .failure("Project not found.")
        }
        guard canEditOrArchive(existing) else {
            return .failure("You don't have permission to edit this project.")
        }
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        let trimmedDescription = description.trimmingCharacters(in: .whitespaces)
        let trimmedLead = projectLead.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return .failure("Project title is required.") }
        guard !trimmedLead.isEmpty else { return .failure("Project lead is required.") }
        guard !projectMainId.isEmpty else { return .failure("Please select a Main.") }

        do {
            try await db.collection("projects").document(projectId).updateData([
                "projectTitle": trimmedTitle,
                "projectDescription": trimmedDescription,
                "projectLead": trimmedLead,
                "teamMembers": cleanedEmailList(teamMembers),
                "projectMainId": projectMainId,
                "label": "",
                "sublabels": sublabels,
                "budget": budget.map { $0 as Any } ?? NSNull(),
                "lastEditedByEmail": currentUserEmail,
                "updatedAt": FieldValue.serverTimestamp(),
            ])
            await loadProjects()
            return .ok
        } catch {
            return .failure("Could not update project right now.")
        }
    }

    /// Focused update for editing just the project description inline (tap-to-edit on the detail
    /// screen), without going through the full edit-project form.
    func updateProjectDescription(projectId: String, description: String) async -> ProjectActionResult {
        guard let existing = projects.first(where: { $0.id == projectId }) else {
            return .failure("Project not found.")
        }
        guard canEditOrArchive(existing) else {
            return .failure("Only the project lead or an admin can edit the description.")
        }
        do {
            try await db.collection("projects").document(projectId).updateData([
                "projectDescription": description.trimmingCharacters(in: .whitespacesAndNewlines),
                "lastEditedByEmail": currentUserEmail,
                "updatedAt": FieldValue.serverTimestamp(),
            ])
            await loadProjects()
            return .ok
        } catch {
            return .failure("Could not update description right now.")
        }
    }

    // MARK: - Photos

    func addPhotos(projectId: String, images: [UIImage]) async -> ProjectActionResult {
        do {
            let existingPhotoCount = projects.first(where: { $0.id == projectId })?.photoURLs.count ?? 0
            var uploadedURLs: [String] = []
            for image in images {
                guard let data = image.jpegData(compressionQuality: 0.8) else { continue }
                let ref = storage.reference().child("projects/\(projectId)/photos/\(UUID().uuidString).jpg")
                _ = try await ref.putDataAsync(data, metadata: nil)
                let url = try await ref.downloadURL()
                uploadedURLs.append(url.absoluteString)
            }
            guard !uploadedURLs.isEmpty else { return .failure("Could not upload photos.") }
            try await db.collection("projects").document(projectId).updateData([
                "photoURLs": FieldValue.arrayUnion(uploadedURLs),
                "updatedAt": FieldValue.serverTimestamp(),
            ])
            let numberList = photoNumberList(startingAt: existingPhotoCount, count: uploadedURLs.count)
            let noun = uploadedURLs.count == 1 ? "photo" : "photos"
            await logActivity(projectId: projectId, text: "\(actorName()) added \(noun) \(numberList)")
            await loadProjects()
            return .ok
        } catch {
            print("addPhotos failed for project \(projectId): \(error)")
            return .failure("Could not upload photos right now.")
        }
    }

    func deletePhoto(projectId: String, photoURL: String) async -> ProjectActionResult {
        do {
            // Firestore is the source of truth for which photos show, so drop the URL there first.
            try await db.collection("projects").document(projectId).updateData([
                "photoURLs": FieldValue.arrayRemove([photoURL]),
                "updatedAt": FieldValue.serverTimestamp(),
            ])
            // Best-effort cleanup of the underlying Storage object; a failure here (e.g. an
            // already-missing file) shouldn't fail the delete the user just saw succeed.
            if let ref = try? storage.reference(forURL: photoURL) {
                try? await ref.delete()
            }
            await logActivity(projectId: projectId, text: "\(actorName()) removed a photo")
            await loadProjects()
            return .ok
        } catch {
            print("deletePhoto failed for project \(projectId): \(error)")
            return .failure("Could not delete photo right now.")
        }
    }

    // MARK: - Budget & Expenses

    func startExpensesListener(projectId: String) {
        stopExpensesListener()
        expensesListener = db.collection("projects").document(projectId)
            .collection("expenses")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self, let documents = snapshot?.documents else { return }
                self.currentExpenses = documents.map { doc in
                    let data = doc.data()
                    return ProjectExpense(
                        id: doc.documentID,
                        name: data["expenseName"] as? String ?? "",
                        type: data["expenseType"] as? String ?? "",
                        amount: data["expenseAmt"] as? Double ?? 0,
                        createdByEmail: data["createdByEmail"] as? String ?? "",
                        createdAt: self.normalizeTimestamp(data["createdAt"])
                    )
                }
            }
    }

    func stopExpensesListener() {
        expensesListener?.remove()
        expensesListener = nil
        currentExpenses = []
    }

    func addExpense(projectId: String, name: String, type: String, amount: Double) async -> ProjectActionResult {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedType = type.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return .failure("Expense name is required.") }
        guard amount > 0 else { return .failure("Enter an amount greater than 0.") }
        do {
            try await db.collection("projects").document(projectId).collection("expenses").addDocument(data: [
                "expenseName": trimmedName,
                "expenseType": trimmedType,
                "expenseAmt": amount,
                "createdByEmail": currentUserEmail,
                "createdAt": FieldValue.serverTimestamp(),
            ])
            return .ok
        } catch {
            return .failure("Could not add expense right now.")
        }
    }

    func deleteExpense(projectId: String, expenseId: String) async -> ProjectActionResult {
        do {
            try await db.collection("projects").document(projectId).collection("expenses").document(expenseId).delete()
            return .ok
        } catch {
            return .failure("Could not delete expense right now.")
        }
    }

    // MARK: - Chat

    func canChat(projectId: String) -> Bool {
        if currentUserIsAdmin { return true }
        guard let project = projects.first(where: { $0.id == projectId }) else { return false }
        if project.projectLead.caseInsensitiveCompare(currentUserEmail) == .orderedSame { return true }
        return project.teamMembers.contains { $0.caseInsensitiveCompare(currentUserEmail) == .orderedSame }
    }

    func startChatListener(projectId: String) {
        stopChatListener()
        chatListener = db.collection("projects").document(projectId)
            .collection("chatMessages")
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self, let documents = snapshot?.documents else { return }
                self.currentChatMessages = documents.map { doc in
                    let data = doc.data()
                    return ProjectChatMessage(
                        id: doc.documentID,
                        text: data["text"] as? String ?? "",
                        senderEmail: data["senderEmail"] as? String ?? "",
                        createdAt: self.normalizeTimestamp(data["createdAt"]),
                        isPinned: data["isPinned"] as? Bool ?? false,
                        isSystemEvent: data["isSystemEvent"] as? Bool ?? false
                    )
                }
            }
    }

    func stopChatListener() {
        chatListener?.remove()
        chatListener = nil
        currentChatMessages = []
    }

    func sendChatMessage(projectId: String, text: String) async -> ProjectActionResult {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return .failure("Message can't be empty.") }
        guard canChat(projectId: projectId) else {
            return .failure("Only project team members can post in this chat.")
        }
        do {
            try await db.collection("projects").document(projectId).collection("chatMessages").addDocument(data: [
                "text": trimmedText,
                "senderEmail": currentUserEmail,
                "isPinned": false,
                "isSystemEvent": false,
                "createdAt": FieldValue.serverTimestamp(),
            ])
            return .ok
        } catch {
            return .failure("Could not send message right now.")
        }
    }

    func togglePinMessage(projectId: String, message: ProjectChatMessage) async -> ProjectActionResult {
        guard canChat(projectId: projectId) else {
            return .failure("Only project team members can pin messages.")
        }
        if !message.isPinned {
            let pinnedCount = currentChatMessages.filter { $0.isPinned }.count
            guard pinnedCount < 3 else {
                return .failure("Only 3 messages can be pinned. Unpin one first.")
            }
        }
        let willPin = !message.isPinned
        do {
            try await db.collection("projects").document(projectId).collection("chatMessages").document(message.id).updateData([
                "isPinned": willPin,
            ])
            let truncatedText = message.text.count > 60 ? "\(message.text.prefix(60))…" : message.text
            let action = willPin ? "pinned" : "unpinned"
            await logActivity(projectId: projectId, text: "\(actorName()) \(action) the message '\(truncatedText)'")
            return .ok
        } catch {
            return .failure("Could not update pin right now.")
        }
    }

    func archiveProject(projectId: String) async -> ProjectActionResult {
        guard let existing = projects.first(where: { $0.id == projectId }), canEditOrArchive(existing) else {
            return .failure("You don't have permission to archive this project.")
        }
        do {
            try await db.collection("projects").document(projectId).updateData([
                "isArchived": true,
                "updatedAt": FieldValue.serverTimestamp(),
            ])
            projects.removeAll { $0.id == projectId }
            return .ok
        } catch {
            return .failure("Could not archive project right now.")
        }
    }

    func unarchiveProject(projectId: String) async -> ProjectActionResult {
        guard currentUserIsAdmin else {
            return .failure("Only an admin can restore projects.")
        }
        do {
            try await db.collection("projects").document(projectId).updateData([
                "isArchived": false,
                "updatedAt": FieldValue.serverTimestamp(),
            ])
            archivedProjects.removeAll { $0.id == projectId }
            return .ok
        } catch {
            return .failure("Could not restore project right now.")
        }
    }

    func deleteProject(projectId: String) async -> ProjectActionResult {
        guard currentUserIsAdmin else {
            return .failure("Only an admin can delete projects.")
        }
        do {
            let projectRef = db.collection("projects").document(projectId)
            let tasksSnapshot = try await projectRef.collection("tasks").getDocuments()
            for taskDoc in tasksSnapshot.documents {
                let subtasksSnapshot = try await taskDoc.reference.collection("subtasks").getDocuments()
                for subtaskDoc in subtasksSnapshot.documents {
                    try await subtaskDoc.reference.delete()
                }
                try await taskDoc.reference.delete()
            }
            try await projectRef.delete()
            projects.removeAll { $0.id == projectId }
            return .ok
        } catch {
            return .failure("Could not delete project right now.")
        }
    }

    func submitDeleteSubtask(projectId: String, taskId: String, subtaskId: String) async -> ProjectActionResult {
        do {
            try await db.collection("projects").document(projectId).collection("tasks").document(taskId)
                .collection("subtasks").document(subtaskId).delete()
            await loadProjects()
            return .ok
        } catch {
            return .failure("Could not delete subtask right now.")
        }
    }

    deinit {
        projectMainsListener?.remove()
        chatListener?.remove()
        expensesListener?.remove()
    }
}
