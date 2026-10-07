import SwiftUI

/// The employee's own weekly schedule editor, presented from ScheduleView's "Edit" button.
/// Edits a draft copy, so Cancel leaves the saved schedule untouched; Save writes only the
/// schedule and its time zone (EmployeeTermsViewModel.saveSchedule), never the admin's pay notes.
struct EditMyScheduleSheet: View {
    @ObservedObject var termsVM: EmployeeTermsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var schedule: [Weekday: WorkDay]
    @State private var timeZoneId: String
    @State private var errorMessage: String?

    init(termsVM: EmployeeTermsViewModel) {
        self.termsVM = termsVM
        _schedule = State(initialValue: termsVM.terms.schedule)
        _timeZoneId = State(initialValue: termsVM.terms.timeZoneId)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                WeeklyScheduleEditor(schedule: $schedule, timeZoneId: $timeZoneId)
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 40)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Edit Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if termsVM.isSaving {
                        ProgressView()
                    } else {
                        Button("Save") {
                            Task {
                                errorMessage = await termsVM.saveSchedule(schedule, timeZoneId: timeZoneId)
                                if errorMessage == nil { dismiss() }
                            }
                        }
                        .fontWeight(.semibold)
                        .disabled(schedule == termsVM.terms.schedule && timeZoneId == termsVM.terms.timeZoneId)
                    }
                }
            }
            .alert("Schedule", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
}
