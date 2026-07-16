import Foundation

/// Mirrors the NOTIFICATION_TYPES map in functions/index.js. Keep both in sync.
enum NotificationType: String {
    case clockEvent = "clock_event"
    case taskAssigned = "task_assigned"
    case subtaskAssigned = "subtask_assigned"
    case addedToProject = "added_to_project"
    case taskCompleted = "task_completed"
    case subtaskCompleted = "subtask_completed"
}

/// Mirrors the CLOCK_ACTIONS map in functions/index.js. Keep both in sync.
enum ClockAction: String {
    case clockIn = "clock_in"
    case clockOut = "clock_out"
}
