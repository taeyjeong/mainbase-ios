import Foundation

struct HistoryEntry: Identifiable {
    let id: String
    let clockIn: Date
    let clockOut: Date
    let durationFormatted: String
    let report: String
}
