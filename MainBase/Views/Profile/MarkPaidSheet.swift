import SwiftUI

/// Admin-only sheet, presented from a Monthly Payouts row in EmployeeDetailView. Adds an
/// optional bonus, deduction and note to the month's base pay, then marks it paid.
struct MarkPaidSheet: View {
    let record: PayoutRecord
    @ObservedObject var payoutsVM: EmployeePayoutsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var bonusText = ""
    @State private var deductionText = ""
    @State private var note = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @ObservedObject private var rates = ExchangeRates.shared

    private var currencyFormat: FloatingPointFormatStyle<Double>.Currency { record.currency.format }

    private var bonus: Double { Double(bonusText) ?? 0 }
    private var deduction: Double { Double(deductionText) ?? 0 }

    private var total: Double? {
        var adjusted = record
        adjusted.bonus = bonus
        adjusted.deduction = deduction
        return adjusted.amount
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    summaryRow("Base pay", record.basePay?.formatted(currencyFormat) ?? "—", dollars: rates.dollarsText(record.basePay, in: record.currency))
                    Text(baseDetail)
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary)

                    Divider()

                    AmountField(title: "Bonus", text: $bonusText, symbol: record.currency.symbol)
                    AmountField(title: "Deduction", text: $deductionText, symbol: record.currency.symbol)
                    NotesField(title: "Note", placeholder: "Why the bonus or deduction, payment method…", text: $note)

                    Divider()

                    summaryRow("Total", total?.formatted(currencyFormat) ?? "—", dollars: rates.dollarsText(total, in: record.currency), emphasized: true)
                    if let total, total < 0 {
                        Text("The deduction is larger than the base pay plus bonus.")
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                    }
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
            .navigationTitle("Pay \(record.monthTitle)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Mark Paid") { markPaid() }
                            .fontWeight(.semibold)
                            .disabled((total ?? -1) < 0)
                    }
                }
            }
            .alert("Payouts", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var baseDetail: String {
        let hours = record.hoursWorked.formatted(.number.precision(.fractionLength(0...1)))
        switch record.payType {
        case .hourly:
            return "\(hours) hrs × \(record.rate?.formatted(currencyFormat) ?? "—") / hour"
        case .salary:
            return "Monthly salary · \(hours) hrs worked"
        }
    }

    /// `dollars` is the "≈ $…" figure shown under a non-USD value (ExchangeRates).
    private func summaryRow(_ label: String, _ value: String, dollars: String? = nil, emphasized: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(AppColors.textSecondary)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(value)
                    .font(.system(size: emphasized ? 18 : 14, weight: emphasized ? .semibold : .medium))
                    .foregroundColor(AppColors.text)
                if let dollars {
                    Text(dollars)
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
    }

    private func markPaid() {
        isSaving = true
        Task {
            errorMessage = await payoutsVM.markPaid(record, bonus: bonus, deduction: deduction, note: note)
            isSaving = false
            if errorMessage == nil { dismiss() }
        }
    }
}
