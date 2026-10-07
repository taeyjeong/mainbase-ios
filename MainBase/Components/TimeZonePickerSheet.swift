import SwiftUI

extension TimeZone {
    /// The zone's city from its identifier: "Asia/Tokyo" → "Tokyo", "America/New_York" → "New York".
    var cityName: String {
        (identifier.split(separator: "/").last.map(String.init) ?? identifier)
            .replacingOccurrences(of: "_", with: " ")
    }

    /// "Japan Standard Time (Tokyo)", for the schedule editor's time zone row and its note.
    var scheduleDisplayName: String {
        let name = localizedName(for: .generic, locale: .current) ?? identifier
        return "\(name) (\(cityName))"
    }

    /// "GMT+9", the zone's current offset from GMT.
    var gmtOffsetText: String {
        let minutes = secondsFromGMT() / 60
        guard minutes != 0 else { return "GMT" }
        let sign = minutes > 0 ? "+" : "-"
        let hours = abs(minutes) / 60
        let rest = abs(minutes) % 60
        return rest == 0 ? "GMT\(sign)\(hours)" : String(format: "GMT%@%d:%02d", sign, hours, rest)
    }
}

/// A searchable list of every time zone for a schedule, with the device's zone first.
/// Presented from WeeklyScheduleEditor's time zone row.
struct TimeZonePickerSheet: View {
    @Binding var selectedId: String
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private static let allZones: [TimeZone] = TimeZone.knownTimeZoneIdentifiers
        .compactMap(TimeZone.init(identifier:))
        .sorted { $0.cityName.localizedCaseInsensitiveCompare($1.cityName) == .orderedAscending }

    private var matchingZones: [TimeZone] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return Self.allZones }
        return Self.allZones.filter {
            $0.identifier.localizedCaseInsensitiveContains(query)
                || $0.cityName.localizedCaseInsensitiveContains(query)
                || ($0.localizedName(for: .generic, locale: .current) ?? "").localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if searchText.isEmpty {
                    Section("Your time zone") {
                        row(for: TimeZone.current)
                    }
                }
                Section(searchText.isEmpty ? "All time zones" : "Results") {
                    ForEach(matchingZones, id: \.identifier) { zone in
                        row(for: zone)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "City or time zone")
            .navigationTitle("Time Zone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func row(for zone: TimeZone) -> some View {
        Button {
            selectedId = zone.identifier
            dismiss()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(zone.cityName)
                        .font(.system(size: 15))
                        .foregroundColor(AppColors.text)
                    Text("\(zone.localizedName(for: .generic, locale: .current) ?? zone.identifier) · \(zone.gmtOffsetText)")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary)
                }
                Spacer()
                if zone.identifier == selectedId {
                    Image(systemName: "checkmark")
                        .foregroundColor(AppColors.primary)
                }
            }
        }
    }
}
