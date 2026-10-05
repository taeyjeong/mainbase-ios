import FirebaseFirestore
import Foundation

/// An employee's request to skip a scheduled shift or work only part of it, stored at
/// users/{uid}/timeOffRequests/{id}. Created by the employee from ScheduleView as pending;
/// only an admin in their company may approve or deny it, and the employee may withdraw it
/// while it's still pending (see firestore.rules).
struct TimeOffRequest: Identifiable {
    enum Kind: String, CaseIterable, Identifiable {
        case dayOff
        case shortenedDay

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .dayOff: return "Day off"
            case .shortenedDay: return "Shortened day"
            }
        }
    }

    enum Status: String {
        case pending
        case approved
        case denied

        var displayName: String { rawValue.capitalized }
    }

    let id: String
    let kind: Kind
    /// The scheduled shift the request is for.
    let shiftStart: Date
    let shiftEnd: Date
    /// The hours the employee wants to work instead; nil for a day off.
    let requestedStart: Date?
    let requestedEnd: Date?
    let reason: String
    let status: Status
    let createdAt: Date

    init(id: String = UUID().uuidString, kind: Kind, shift: DateInterval, requested: DateInterval?, reason: String) {
        self.id = id
        self.kind = kind
        shiftStart = shift.start
        shiftEnd = shift.end
        requestedStart = kind == .shortenedDay ? requested?.start : nil
        requestedEnd = kind == .shortenedDay ? requested?.end : nil
        self.reason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        status = .pending
        createdAt = Date()
    }

    init?(id: String, data: [String: Any]) {
        guard let kind = (data["kind"] as? String).flatMap(Kind.init(rawValue:)),
              let shiftStart = (data["shiftStart"] as? Timestamp)?.dateValue(),
              let shiftEnd = (data["shiftEnd"] as? Timestamp)?.dateValue()
        else { return nil }
        self.id = id
        self.kind = kind
        self.shiftStart = shiftStart
        self.shiftEnd = shiftEnd
        requestedStart = (data["requestedStart"] as? Timestamp)?.dateValue()
        requestedEnd = (data["requestedEnd"] as? Timestamp)?.dateValue()
        reason = data["reason"] as? String ?? ""
        status = (data["status"] as? String).flatMap(Status.init(rawValue:)) ?? .pending
        createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
    }

    var firestoreData: [String: Any] {
        var data: [String: Any] = [
            "kind": kind.rawValue,
            "shiftStart": Timestamp(date: shiftStart),
            "shiftEnd": Timestamp(date: shiftEnd),
            "reason": reason,
            "status": status.rawValue,
        ]
        if let requestedStart, let requestedEnd {
            data["requestedStart"] = Timestamp(date: requestedStart)
            data["requestedEnd"] = Timestamp(date: requestedEnd)
        }
        return data
    }
}
