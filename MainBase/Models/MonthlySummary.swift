import Foundation

/// A Gemini-written report of one employee's month, saved at users/{uid}/monthlySummaries.
struct MonthlySummary: Identifiable {
    let id: String
    /// Start of the month the report covers (device calendar, as ReportsListView shows it).
    let month: Date
    /// The month's label when generated, e.g. "September 2026".
    let monthTitle: String
    let reportText: String
    let createdAt: Date?
}
