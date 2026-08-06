import Foundation

/// Admin-only preference for clock in/out push notifications: admins can either hear about
/// every clock event regardless of their own clocked-in status, or opt out of them entirely.
/// Non-admins aren't affected by this — they always follow the "only while clocked in" rule.
enum ClockNotificationPreference: String, CaseIterable {
    case none
    case all

    var displayName: String {
        switch self {
        case .none: return "No Notifications"
        case .all: return "All Notifications"
        }
    }
}

struct UserProfile {
    var name: String = ""
    var surname: String = ""
    var emoji: String = ""
    var email: String = ""
    var company: String = ""
    var phone: String = ""
    var country: String = ""
    var admin: Bool = false
    var isEmployed: Bool = false
    var clockNotificationPreference: ClockNotificationPreference = .all

    init() {}

    init(data: [String: Any], fallbackEmail: String = "") {
        name = data["name"] as? String ?? ""
        surname = data["surname"] as? String ?? ""
        emoji = data["emoji"] as? String ?? ""
        email = data["email"] as? String ?? fallbackEmail
        company = data["company"] as? String ?? ""
        phone = data["phone"] as? String ?? ""
        country = data["country"] as? String ?? ""
        admin = data["admin"] as? Bool ?? false
        isEmployed = data["isEmployed"] as? Bool ?? false
        clockNotificationPreference = (data["clockNotificationPreference"] as? String)
            .flatMap(ClockNotificationPreference.init(rawValue:)) ?? .all
    }

    var firestoreUpdateData: [String: Any] {
        [
            "name": name.trimmingCharacters(in: .whitespaces),
            "surname": surname.trimmingCharacters(in: .whitespaces),
            "emoji": emoji,
            "company": company.trimmingCharacters(in: .whitespaces),
            "phone": phone.trimmingCharacters(in: .whitespaces),
            "country": country.trimmingCharacters(in: .whitespaces),
            "clockNotificationPreference": clockNotificationPreference.rawValue,
        ]
    }
}
