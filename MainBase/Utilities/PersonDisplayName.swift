import Foundation

/// "Sarah" + "Kim" -> "Sarah K." Used everywhere a person's name is shown outside their own
/// Profile screen (assignee pickers, chat, notifications, admin employee list).
func formattedDisplayName(name: String, surname: String) -> String {
    guard let initial = surname.trimmingCharacters(in: .whitespaces).first else { return name }
    return "\(name) \(initial)."
}
