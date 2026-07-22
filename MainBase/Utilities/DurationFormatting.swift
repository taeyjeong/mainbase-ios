import Foundation

enum DurationFormatting {
    /// Formats the span between two dates as e.g. "3d 4h", "5h", or "<1h".
    static func daysHours(from start: Date, to end: Date) -> String {
        let totalHours = max(0, Int(end.timeIntervalSince(start) / 3600))
        let days = totalHours / 24
        let hours = totalHours % 24
        if days > 0 {
            return "\(days)d \(hours)h"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "<1h"
        }
    }
}
