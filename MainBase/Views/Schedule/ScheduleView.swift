import FirebaseAuth
import SwiftUI

/// The signed-in user's own work schedule, opened from the calendar icon in TimeTrackerView's
/// header. The weekly schedule is set by an admin in Pacific time (EmploymentTerms); this lists
/// the shifts of the next 7 Pacific days converted to the device's time zone, so a shift can
/// land on a different local day than its Pacific weekday.
struct ScheduleView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var termsVM = EmployeeTermsViewModel(userId: Auth.auth().currentUser?.uid ?? "")
    @State private var showingEditor = false

    private static let daysShown = 7

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEEEMMMd")
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()

    private static var localZoneAbbreviation: String {
        TimeZone.current.abbreviation() ?? TimeZone.current.identifier
    }

    /// Scheduled shifts from today through the next 6 Pacific days, including one in progress.
    private var upcomingShifts: [DateInterval] {
        let calendar = PayoutRecord.calendar
        let now = Date()
        let today = calendar.startOfDay(for: now)
        return (0..<Self.daysShown).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: today)
                .flatMap { termsVM.terms.shift(on: $0) }
        }
        .filter { $0.end > now }
    }

    var body: some View {
        NavigationStack {
            Group {
                if termsVM.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if !termsVM.hasSavedTerms {
                    emptyState("No schedule set yet")
                } else if upcomingShifts.isEmpty {
                    emptyState("No shifts in the next \(Self.daysShown) days")
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 12) {
                            weeklyTotalCard
                            shiftsCard
                            Text("Times are in your time zone (\(Self.localZoneAbbreviation)).")
                                .font(.system(size: 12))
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                        .padding(.bottom, 40)
                    }
                }
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("My Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Edit") { showingEditor = true }
                        .disabled(termsVM.isLoading)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingEditor) {
                EditMyScheduleSheet(termsVM: termsVM)
            }
            .task { await termsVM.load() }
            .alert("Schedule", isPresented: Binding(
                get: { termsVM.alertMessage != nil },
                set: { if !$0 { termsVM.alertMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(termsVM.alertMessage ?? "")
            }
        }
    }

    private var weeklyTotalCard: some View {
        HStack {
            Text("Total this week")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppColors.text)
            Spacer()
            Text(DurationFormatting.hoursMinutes(EmploymentTerms.weeklyHours(termsVM.terms.schedule)))
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppColors.primary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.cardBackground)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColors.border, lineWidth: 1))
        )
    }

    private var shiftsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(upcomingShifts.enumerated()), id: \.offset) { index, shift in
                if index > 0 {
                    Divider()
                        .padding(.vertical, 10)
                }
                shiftRow(shift)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.cardBackground)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColors.border, lineWidth: 1))
        )
    }

    private func shiftRow(_ shift: DateInterval) -> some View {
        let isNow = shift.contains(Date())
        let endsNextDay = !Calendar.current.isDate(shift.start, inSameDayAs: shift.end)
        return HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Self.dayFormatter.string(from: shift.start))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.text)
                Text("\(Self.timeFormatter.string(from: shift.start)) – \(Self.timeFormatter.string(from: shift.end))\(endsNextDay ? " (next day)" : "")")
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.textSecondary)
            }
            Spacer()
            if isNow {
                Text("Now")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.primary)
            }
        }
    }

    private func emptyState(_ message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar")
                .font(.system(size: 36))
                .foregroundColor(AppColors.textSecondary)
            Text(message)
                .font(.system(size: 15))
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ScheduleView()
}
