import SwiftUI

/// The employee's request for a day off or a shortened day, presented from ScheduleView's
/// "Request Time Off" button. Picks one of their upcoming scheduled shifts; for a shortened
/// day, also the hours they still want to work. Sent as pending for an admin to answer.
struct TimeOffRequestSheet: View {
    @ObservedObject var requestsVM: TimeOffRequestsViewModel
    @Environment(\.dismiss) private var dismiss

    /// Upcoming shifts without a pending or approved request.
    private let shifts: [DateInterval]

    @State private var kind: TimeOffRequest.Kind = .dayOff
    @State private var shiftIndex = 0
    @State private var requestedStart: Date
    @State private var requestedEnd: Date
    @State private var reason = ""
    @State private var errorMessage: String?

    private static let shiftFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEEMMMdjmm")
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()

    init(requestsVM: TimeOffRequestsViewModel, upcomingShifts: [DateInterval]) {
        self.requestsVM = requestsVM
        let shifts = upcomingShifts.filter { requestsVM.activeRequest(for: $0) == nil }
        self.shifts = shifts
        let first = shifts.first ?? DateInterval(start: Date(), duration: 0)
        _requestedStart = State(initialValue: first.start)
        _requestedEnd = State(initialValue: first.end)
    }

    private var selectedShift: DateInterval? {
        shifts.indices.contains(shiftIndex) ? shifts[shiftIndex] : nil
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                if let selectedShift {
                    form(for: selectedShift)
                } else {
                    Text("You have no upcoming shifts to request time off from.")
                        .font(.system(size: 15))
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                        .padding(.horizontal, 20)
                }
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Request Time Off")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if requestsVM.isSaving {
                        ProgressView()
                    } else {
                        Button("Send") { submit() }
                            .fontWeight(.semibold)
                            .disabled(selectedShift == nil)
                    }
                }
            }
            .onChange(of: shiftIndex) { _, _ in resetRequestedHours() }
            .alert("Time Off", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func form(for shift: DateInterval) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("Type", selection: $kind) {
                ForEach(TimeOffRequest.Kind.allCases) { kind in
                    Text(kind.displayName).tag(kind)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                Text("Shift")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.text)
                Spacer()
                Picker("Shift", selection: $shiftIndex) {
                    ForEach(shifts.indices, id: \.self) { index in
                        Text(shiftLabel(shifts[index])).tag(index)
                    }
                }
                .pickerStyle(.menu)
            }

            if kind == .shortenedDay {
                Divider()
                Text("Hours you'll work instead")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.text)
                DatePicker("Start", selection: $requestedStart, in: shift.start...shift.end, displayedComponents: .hourAndMinute)
                DatePicker("End", selection: $requestedEnd, in: shift.start...shift.end, displayedComponents: .hourAndMinute)
            }

            Divider()

            NotesField(title: "Reason", placeholder: "Optional", text: $reason)

            Text("Times are in your time zone. An admin will approve or deny your request.")
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

    /// "Mon, Oct 5, 9:00 AM – 5:00 PM"
    private func shiftLabel(_ shift: DateInterval) -> String {
        "\(Self.shiftFormatter.string(from: shift.start)) – \(Self.timeFormatter.string(from: shift.end))"
    }

    private func resetRequestedHours() {
        guard let selectedShift else { return }
        requestedStart = selectedShift.start
        requestedEnd = selectedShift.end
    }

    private func submit() {
        guard let selectedShift else { return }
        let requested = requestedEnd > requestedStart ? DateInterval(start: requestedStart, end: requestedEnd) : nil
        Task {
            errorMessage = await requestsVM.submit(kind: kind, shift: selectedShift, requested: requested, reason: reason)
            if errorMessage == nil { dismiss() }
        }
    }
}
