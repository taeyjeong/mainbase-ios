import Foundation

struct UserProfile {
    var name: String = ""
    var email: String = ""
    var company: String = ""
    var phone: String = ""
    var country: String = ""
    var admin: Bool = false
    var isEmployed: Bool = false

    init() {}

    init(data: [String: Any], fallbackEmail: String = "") {
        name = data["name"] as? String ?? ""
        email = data["email"] as? String ?? fallbackEmail
        company = data["company"] as? String ?? ""
        phone = data["phone"] as? String ?? ""
        country = data["country"] as? String ?? ""
        admin = data["admin"] as? Bool ?? false
        isEmployed = data["isEmployed"] as? Bool ?? false
    }

    var firestoreUpdateData: [String: Any] {
        [
            "name": name.trimmingCharacters(in: .whitespaces),
            "company": company.trimmingCharacters(in: .whitespaces),
            "phone": phone.trimmingCharacters(in: .whitespaces),
            "country": country.trimmingCharacters(in: .whitespaces),
        ]
    }
}
