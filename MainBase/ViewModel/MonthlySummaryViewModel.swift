import Combine
import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions

/// Drives the "Summarize this month" pop-up (MonthlySummaryPopup): asks the summarizeMonth
/// Cloud Function for a Gemini-written report of the signed-in user's month, then saves it to
/// users/{uid}/monthlySummaries if they choose to.
@MainActor
final class MonthlySummaryViewModel: ObservableObject {
    @Published private(set) var isPresented = false
    @Published private(set) var isGenerating = false
    @Published private(set) var isSaving = false
    @Published private(set) var month: Date = MonthGrouping.startOfMonth(for: Date())
    @Published private(set) var reportText = ""
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    private var generateTask: Task<Void, Never>?

    var monthTitle: String { MonthGrouping.monthTitle(for: month) }

    /// Whether closing should first ask to save (a report was generated).
    var hasReport: Bool { !reportText.isEmpty }

    func present(month: Date) {
        self.month = MonthGrouping.startOfMonth(for: month)
        reportText = ""
        errorMessage = nil
        isPresented = true
        generateTask?.cancel()
        generateTask = Task { await generate() }
    }

    func dismiss() {
        generateTask?.cancel()
        generateTask = nil
        isPresented = false
        isGenerating = false
        reportText = ""
        errorMessage = nil
    }

    func regenerate() {
        generateTask?.cancel()
        generateTask = Task { await generate() }
    }

    private func generate() async {
        guard let monthEnd = Calendar.current.date(byAdding: .month, value: 1, to: month) else { return }
        isGenerating = true
        errorMessage = nil
        defer { isGenerating = false }

        let callable = Functions.functions().httpsCallable("summarizeMonth")
        callable.timeoutInterval = 120
        do {
            let result = try await callable.call([
                "monthStart": month.timeIntervalSince1970 * 1000,
                "monthEnd": monthEnd.timeIntervalSince1970 * 1000,
                "monthTitle": monthTitle,
            ])
            guard !Task.isCancelled else { return }
            guard let text = (result.data as? [String: Any])?["text"] as? String else {
                errorMessage = "Gemini returned an unexpected response."
                return
            }
            reportText = text
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = (error as NSError).localizedDescription
        }
    }

    /// Saves the generated report with the date created and the month it covers. Returns
    /// whether it saved; on failure `errorMessage` says why.
    func save() async -> Bool {
        guard let uid = Auth.auth().currentUser?.uid else {
            errorMessage = "You need to be signed in to save."
            return false
        }
        guard hasReport else { return false }
        isSaving = true
        defer { isSaving = false }
        do {
            try await db.collection("users").document(uid).collection("monthlySummaries").addDocument(data: [
                "month": Timestamp(date: month),
                "monthTitle": monthTitle,
                "reportText": reportText,
                "createdAt": FieldValue.serverTimestamp(),
            ])
            return true
        } catch {
            errorMessage = "Could not save the report right now."
            return false
        }
    }
}
