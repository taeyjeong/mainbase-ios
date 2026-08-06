// Ported from CoWorkNChill/Utilities/CountryHelper.swift, restyled to use AppColors.

import SwiftUI
import Foundation

struct Country {
    let name: String
    let code: String
    let phoneCode: String
    let flag: String
}

enum CountryHelper {

    // MARK: - Country Data
    static let countries: [Country] = [
        // Popular countries first, then alphabetical
        Country(name: "United States", code: "US", phoneCode: "+1", flag: "🇺🇸"),
        Country(name: "Canada", code: "CA", phoneCode: "+1", flag: "🇨🇦"),
        Country(name: "United Kingdom", code: "GB", phoneCode: "+44", flag: "🇬🇧"),
        Country(name: "Germany", code: "DE", phoneCode: "+49", flag: "🇩🇪"),
        Country(name: "France", code: "FR", phoneCode: "+33", flag: "🇫🇷"),
        Country(name: "Japan", code: "JP", phoneCode: "+81", flag: "🇯🇵"),
        Country(name: "South Korea", code: "KR", phoneCode: "+82", flag: "🇰🇷"),
        Country(name: "China", code: "CN", phoneCode: "+86", flag: "🇨🇳"),
        Country(name: "India", code: "IN", phoneCode: "+91", flag: "🇮🇳"),
        Country(name: "Australia", code: "AU", phoneCode: "+61", flag: "🇦🇺"),
        Country(name: "Brazil", code: "BR", phoneCode: "+55", flag: "🇧🇷"),
        Country(name: "Mexico", code: "MX", phoneCode: "+52", flag: "🇲🇽"),
        Country(name: "Italy", code: "IT", phoneCode: "+39", flag: "🇮🇹"),
        Country(name: "Spain", code: "ES", phoneCode: "+34", flag: "🇪🇸"),
        Country(name: "Netherlands", code: "NL", phoneCode: "+31", flag: "🇳🇱"),
        Country(name: "Switzerland", code: "CH", phoneCode: "+41", flag: "🇨🇭"),
        Country(name: "Sweden", code: "SE", phoneCode: "+46", flag: "🇸🇪"),
        Country(name: "Norway", code: "NO", phoneCode: "+47", flag: "🇳🇴"),
        Country(name: "Denmark", code: "DK", phoneCode: "+45", flag: "🇩🇰"),
        Country(name: "Finland", code: "FI", phoneCode: "+358", flag: "🇫🇮"),
        Country(name: "Belgium", code: "BE", phoneCode: "+32", flag: "🇧🇪"),
        Country(name: "Austria", code: "AT", phoneCode: "+43", flag: "🇦🇹"),
        Country(name: "Portugal", code: "PT", phoneCode: "+351", flag: "🇵🇹"),
        Country(name: "Greece", code: "GR", phoneCode: "+30", flag: "🇬🇷"),
        Country(name: "Poland", code: "PL", phoneCode: "+48", flag: "🇵🇱"),
        Country(name: "Czech Republic", code: "CZ", phoneCode: "+420", flag: "🇨🇿"),
        Country(name: "Hungary", code: "HU", phoneCode: "+36", flag: "🇭🇺"),
        Country(name: "Romania", code: "RO", phoneCode: "+40", flag: "🇷🇴"),
        Country(name: "Bulgaria", code: "BG", phoneCode: "+359", flag: "🇧🇬"),
        Country(name: "Croatia", code: "HR", phoneCode: "+385", flag: "🇭🇷"),
        Country(name: "Slovenia", code: "SI", phoneCode: "+386", flag: "🇸🇮"),
        Country(name: "Slovakia", code: "SK", phoneCode: "+421", flag: "🇸🇰"),
        Country(name: "Estonia", code: "EE", phoneCode: "+372", flag: "🇪🇪"),
        Country(name: "Latvia", code: "LV", phoneCode: "+371", flag: "🇱🇻"),
        Country(name: "Lithuania", code: "LT", phoneCode: "+370", flag: "🇱🇹"),
        Country(name: "Ireland", code: "IE", phoneCode: "+353", flag: "🇮🇪"),
        Country(name: "Iceland", code: "IS", phoneCode: "+354", flag: "🇮🇸"),
        Country(name: "Luxembourg", code: "LU", phoneCode: "+352", flag: "🇱🇺"),
        Country(name: "Malta", code: "MT", phoneCode: "+356", flag: "🇲🇹"),
        Country(name: "Cyprus", code: "CY", phoneCode: "+357", flag: "🇨🇾"),

        // Asian Countries
        Country(name: "Indonesia", code: "ID", phoneCode: "+62", flag: "🇮🇩"),
        Country(name: "Thailand", code: "TH", phoneCode: "+66", flag: "🇹🇭"),
        Country(name: "Vietnam", code: "VN", phoneCode: "+84", flag: "🇻🇳"),
        Country(name: "Philippines", code: "PH", phoneCode: "+63", flag: "🇵🇭"),
        Country(name: "Malaysia", code: "MY", phoneCode: "+60", flag: "🇲🇾"),
        Country(name: "Singapore", code: "SG", phoneCode: "+65", flag: "🇸🇬"),
        Country(name: "Taiwan", code: "TW", phoneCode: "+886", flag: "🇹🇼"),
        Country(name: "Hong Kong", code: "HK", phoneCode: "+852", flag: "🇭🇰"),
        Country(name: "Macau", code: "MO", phoneCode: "+853", flag: "🇲🇴"),
        Country(name: "Mongolia", code: "MN", phoneCode: "+976", flag: "🇲🇳"),
        Country(name: "Nepal", code: "NP", phoneCode: "+977", flag: "🇳🇵"),
        Country(name: "Bangladesh", code: "BD", phoneCode: "+880", flag: "🇧🇩"),
        Country(name: "Sri Lanka", code: "LK", phoneCode: "+94", flag: "🇱🇰"),
        Country(name: "Pakistan", code: "PK", phoneCode: "+92", flag: "🇵🇰"),
        Country(name: "Afghanistan", code: "AF", phoneCode: "+93", flag: "🇦🇫"),
        Country(name: "Myanmar", code: "MM", phoneCode: "+95", flag: "🇲🇲"),
        Country(name: "Cambodia", code: "KH", phoneCode: "+855", flag: "🇰🇭"),
        Country(name: "Laos", code: "LA", phoneCode: "+856", flag: "🇱🇦"),
        Country(name: "Brunei", code: "BN", phoneCode: "+673", flag: "🇧🇳"),

        // Middle East & Africa
        Country(name: "Turkey", code: "TR", phoneCode: "+90", flag: "🇹🇷"),
        Country(name: "Israel", code: "IL", phoneCode: "+972", flag: "🇮🇱"),
        Country(name: "United Arab Emirates", code: "AE", phoneCode: "+971", flag: "🇦🇪"),
        Country(name: "Saudi Arabia", code: "SA", phoneCode: "+966", flag: "🇸🇦"),
        Country(name: "Qatar", code: "QA", phoneCode: "+974", flag: "🇶🇦"),
        Country(name: "Kuwait", code: "KW", phoneCode: "+965", flag: "🇰🇼"),
        Country(name: "Bahrain", code: "BH", phoneCode: "+973", flag: "🇧🇭"),
        Country(name: "Oman", code: "OM", phoneCode: "+968", flag: "🇴🇲"),
        Country(name: "Jordan", code: "JO", phoneCode: "+962", flag: "🇯🇴"),
        Country(name: "Lebanon", code: "LB", phoneCode: "+961", flag: "🇱🇧"),
        Country(name: "Syria", code: "SY", phoneCode: "+963", flag: "🇸🇾"),
        Country(name: "Iraq", code: "IQ", phoneCode: "+964", flag: "🇮🇶"),
        Country(name: "Iran", code: "IR", phoneCode: "+98", flag: "🇮🇷"),
        Country(name: "Egypt", code: "EG", phoneCode: "+20", flag: "🇪🇬"),
        Country(name: "South Africa", code: "ZA", phoneCode: "+27", flag: "🇿🇦"),
        Country(name: "Nigeria", code: "NG", phoneCode: "+234", flag: "🇳🇬"),
        Country(name: "Kenya", code: "KE", phoneCode: "+254", flag: "🇰🇪"),
        Country(name: "Morocco", code: "MA", phoneCode: "+212", flag: "🇲🇦"),
        Country(name: "Tunisia", code: "TN", phoneCode: "+216", flag: "🇹🇳"),
        Country(name: "Algeria", code: "DZ", phoneCode: "+213", flag: "🇩🇿"),
        Country(name: "Libya", code: "LY", phoneCode: "+218", flag: "🇱🇾"),
        Country(name: "Ethiopia", code: "ET", phoneCode: "+251", flag: "🇪🇹"),
        Country(name: "Ghana", code: "GH", phoneCode: "+233", flag: "🇬🇭"),

        // Americas
        Country(name: "Argentina", code: "AR", phoneCode: "+54", flag: "🇦🇷"),
        Country(name: "Chile", code: "CL", phoneCode: "+56", flag: "🇨🇱"),
        Country(name: "Colombia", code: "CO", phoneCode: "+57", flag: "🇨🇴"),
        Country(name: "Peru", code: "PE", phoneCode: "+51", flag: "🇵🇪"),
        Country(name: "Venezuela", code: "VE", phoneCode: "+58", flag: "🇻🇪"),
        Country(name: "Ecuador", code: "EC", phoneCode: "+593", flag: "🇪🇨"),
        Country(name: "Bolivia", code: "BO", phoneCode: "+591", flag: "🇧🇴"),
        Country(name: "Paraguay", code: "PY", phoneCode: "+595", flag: "🇵🇾"),
        Country(name: "Uruguay", code: "UY", phoneCode: "+598", flag: "🇺🇾"),
        Country(name: "Costa Rica", code: "CR", phoneCode: "+506", flag: "🇨🇷"),
        Country(name: "Panama", code: "PA", phoneCode: "+507", flag: "🇵🇦"),
        Country(name: "Guatemala", code: "GT", phoneCode: "+502", flag: "🇬🇹"),
        Country(name: "Nicaragua", code: "NI", phoneCode: "+505", flag: "🇳🇮"),
        Country(name: "Honduras", code: "HN", phoneCode: "+504", flag: "🇭🇳"),
        Country(name: "El Salvador", code: "SV", phoneCode: "+503", flag: "🇸🇻"),
        Country(name: "Belize", code: "BZ", phoneCode: "+501", flag: "🇧🇿"),
        Country(name: "Jamaica", code: "JM", phoneCode: "+1", flag: "🇯🇲"),
        Country(name: "Cuba", code: "CU", phoneCode: "+53", flag: "🇨🇺"),
        Country(name: "Dominican Republic", code: "DO", phoneCode: "+1", flag: "🇩🇴"),
        Country(name: "Haiti", code: "HT", phoneCode: "+509", flag: "🇭🇹"),
        Country(name: "Puerto Rico", code: "PR", phoneCode: "+1", flag: "🇵🇷"),

        // Oceania
        Country(name: "New Zealand", code: "NZ", phoneCode: "+64", flag: "🇳🇿"),
        Country(name: "Fiji", code: "FJ", phoneCode: "+679", flag: "🇫🇯"),
        Country(name: "Papua New Guinea", code: "PG", phoneCode: "+675", flag: "🇵🇬"),

        // More European Countries
        Country(name: "Russia", code: "RU", phoneCode: "+7", flag: "🇷🇺"),
        Country(name: "Ukraine", code: "UA", phoneCode: "+380", flag: "🇺🇦"),
        Country(name: "Belarus", code: "BY", phoneCode: "+375", flag: "🇧🇾"),
        Country(name: "Moldova", code: "MD", phoneCode: "+373", flag: "🇲🇩"),
        Country(name: "Serbia", code: "RS", phoneCode: "+381", flag: "🇷🇸"),
        Country(name: "Montenegro", code: "ME", phoneCode: "+382", flag: "🇲🇪"),
        Country(name: "Bosnia and Herzegovina", code: "BA", phoneCode: "+387", flag: "🇧🇦"),
        Country(name: "North Macedonia", code: "MK", phoneCode: "+389", flag: "🇲🇰"),
        Country(name: "Albania", code: "AL", phoneCode: "+355", flag: "🇦🇱"),
        Country(name: "Kosovo", code: "XK", phoneCode: "+383", flag: "🇽🇰"),
        Country(name: "Georgia", code: "GE", phoneCode: "+995", flag: "🇬🇪"),
        Country(name: "Armenia", code: "AM", phoneCode: "+374", flag: "🇦🇲"),
        Country(name: "Azerbaijan", code: "AZ", phoneCode: "+994", flag: "🇦🇿"),
    ]

    /// Get unique phone codes with the most popular country for each code
    static func getUniquePhoneCodes() -> [Country] {
        var uniqueCodes: [String: Country] = [:]
        let priorityCountries: [String: String] = [
            "+1": "US", "+7": "RU", "+44": "GB", "+33": "FR", "+39": "IT", "+47": "NO", "+212": "MA",
        ]
        for country in countries {
            let phoneCode = country.phoneCode
            if let existing = uniqueCodes[phoneCode] {
                if let preferredCode = priorityCountries[phoneCode], country.code == preferredCode {
                    uniqueCodes[phoneCode] = country
                }
                _ = existing
            } else {
                uniqueCodes[phoneCode] = country
            }
        }
        return uniqueCodes.values.sorted { (Int($0.phoneCode.dropFirst()) ?? 0) < (Int($1.phoneCode.dropFirst()) ?? 0) }
    }

    static func getAllCountries() -> [Country] {
        countries.sorted { $0.name < $1.name }
    }

    /// Splits "+1 5551234" into (dialCode: "+1", number: "5551234").
    static func parsePhoneNumber(_ fullNumber: String) -> (dialCode: String, number: String) {
        let trimmed = fullNumber.trimmingCharacters(in: .whitespaces)
        guard let spaceIndex = trimmed.firstIndex(of: " ") else {
            return ("+1", trimmed)
        }
        return (String(trimmed[..<spaceIndex]), String(trimmed[trimmed.index(after: spaceIndex)...]))
    }
}

// MARK: - UI Components

/// A single-field-backed phone entry: a dial-code Menu (flag + "+1" etc.) next to a number TextField,
/// composing back into one "+1 5551234"-style string on any change.
struct PhoneNumberField: View {
    @Binding var fullPhone: String

    @State private var dialCode = "+1"
    @State private var number = ""

    private let phoneCodes = CountryHelper.getUniquePhoneCodes()

    var body: some View {
        HStack(spacing: 8) {
            Menu {
                ForEach(phoneCodes, id: \.phoneCode) { country in
                    Button("\(country.flag) \(country.phoneCode)") {
                        dialCode = country.phoneCode
                        compose()
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(dialCodeDisplay)
                        .foregroundColor(AppColors.text)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(.horizontal, 12)
                .frame(height: 50)
                .background(AppColors.background)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.border, lineWidth: 1))
            }

            TextField("Phone number", text: $number)
                .keyboardType(.phonePad)
                .inputFieldStyle()
                .onChange(of: number) { _, newValue in
                    number = newValue.filter { $0.isNumber }
                    compose()
                }
        }
        .onAppear {
            let parsed = CountryHelper.parsePhoneNumber(fullPhone)
            dialCode = parsed.dialCode
            number = parsed.number
        }
    }

    private var dialCodeDisplay: String {
        if let country = phoneCodes.first(where: { $0.phoneCode == dialCode }) {
            return "\(country.flag) \(dialCode)"
        }
        return dialCode
    }

    private func compose() {
        fullPhone = number.isEmpty ? "" : "\(dialCode) \(number)"
    }
}

/// A Menu-based country name picker.
struct CountryDropdown: View {
    @Binding var selectedCountry: String
    let placeholder: String

    private let countries = CountryHelper.getAllCountries()

    var body: some View {
        Menu {
            ForEach(countries, id: \.code) { country in
                Button("\(country.flag) \(country.name)") {
                    selectedCountry = country.name
                }
            }
        } label: {
            HStack {
                Text(selectedCountry.isEmpty ? placeholder : selectedCountry)
                    .foregroundColor(selectedCountry.isEmpty ? AppColors.textSecondary : AppColors.text)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(.horizontal, 16)
            .frame(height: 50)
            .background(AppColors.background)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.border, lineWidth: 1))
        }
    }
}
