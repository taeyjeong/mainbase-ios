import Foundation

struct HistoryEntry: Identifiable {
    let id: String
    let clockIn: Date
    let clockOut: Date
    let durationFormatted: String
    let report: String
    /// Set once an admin has corrected the clock-in/out (EmployeePayoutsViewModel.updateShift).
    var editedAt: Date? = nil

    var hours: Double { clockOut.timeIntervalSince(clockIn) / 3600 }
}
