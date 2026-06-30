import Foundation

struct MonthSection<Item> {
    let title: String
    let items: [Item]
}

enum MonthGrouping {
    private static let titleFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()

    static func group<Item>(_ items: [Item], by date: (Item) -> Date) -> [MonthSection<Item>] {
        let calendar = Calendar.current
        var buckets: [Date: [Item]] = [:]

        for item in items {
            let itemDate = date(item)
            let components = calendar.dateComponents([.year, .month], from: itemDate)
            let monthStart = calendar.date(from: components) ?? itemDate
            buckets[monthStart, default: []].append(item)
        }

        return buckets.keys.sorted(by: >).map { monthStart in
            let title = titleFormatter.string(from: monthStart)
            let sorted = (buckets[monthStart] ?? []).sorted { date($0) > date($1) }
            return MonthSection(title: title, items: sorted)
        }
    }
}
