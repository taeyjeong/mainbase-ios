import SwiftUI

/// Admin-only sheet, presented from a shift in PayoutMonthCalendarView. Corrects the shift's
/// clock-in and clock-out; the report is left as written. Times are picked in the admin's own
/// time zone. Days and months stay Pacific (PayoutRecord.calendar), so if the new clock-out
/// falls on another Pacific day or month, the shift moves there.
struct EditShiftSheet: View {
    let entry: HistoryEntry
    @ObservedObject var payoutsVM: EmployeePayoutsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var clockIn: Date
    @State private var clockOut: Date
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(entry: HistoryEntry, payoutsVM: EmployeePayoutsViewModel) {
        self.entry = entry
        self.payoutsVM = payoutsVM
        _clockIn = State(initialValue: entry.clockIn)
        _clockOut = State(initialValue: entry.clockOut)
    }

    private var duration: TimeInterval { clockOut.timeIntervalSince(clockIn) }

    private var durationText: String {
        guard duration > 0 else { return "—" }
        let seconds = Int(duration)
        return "\(seconds / 3600)h \((seconds % 3600) / 60)m"
    }

    private var validationMessage: String? {
        if duration <= 0 { return "Clock-out must be after clock-in." }
        if clockOut > Date() { return "Clock-out can't be in the future." }
        if duration > 16 * 3600 { return "This shift is over 16 hours. Double-check the dates." }
        return nil
    }

    private var hasChanges: Bool {
        clockIn != entry.clockIn || clockOut != entry.clockOut
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    DatePicker("Clock in", selection: $clockIn)
                    DatePicker("Clock out", selection: $clockOut, in: ...Date())

                    Divider()

                    HStack {
                        Text("Duration")
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.textSecondary)
                        Spacer()
                        Text(durationText)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppColors.text)
                    }
                    if let validationMessage {
                        Text(validationMessage)
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                    }
                    Text("Times are in your time zone (\(TimeZone.current.abbreviation() ?? TimeZone.current.identifier)). Pay days and months follow Pacific Time (US), and a shift counts toward the Pacific day it's clocked out, so changing the clock-out can move it to another day or month.")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(AppColors.cardBackground)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColors.border, lineWidth: 1))
                )
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Edit Shift")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save") { save() }
                            .fontWeight(.semibold)
                            .disabled(!hasChanges || duration <= 0 || clockOut > Date())
                    }
                }
            }
            .alert("Edit Shift", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func save() {
        isSaving = true
        Task {
            errorMessage = await payoutsVM.updateShift(entry, clockIn: clockIn, clockOut: clockOut)
            isSaving = false
            if errorMessage == nil { dismiss() }
        }
    }
}
