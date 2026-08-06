import SwiftUI

private let currencyFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    return formatter
}()

private func currencyString(_ amount: Double) -> String {
    currencyFormatter.string(from: NSNumber(value: amount)) ?? String(format: "$%.2f", amount)
}

/// Shows the project's budget vs. total spent, and the list of logged expenses.
struct ProjectBudgetSection: View {
    let projectId: String
    let budget: Double?
    @ObservedObject var vm: ProjectsViewModel

    @State private var showingAddExpense = false
    @State private var errorMessage: String?

    private var totalSpent: Double {
        vm.currentExpenses.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Budget")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary)
                    Text(budget.map(currencyString) ?? "—")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.text)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Spent")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary)
                    Text(currencyString(totalSpent))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(overBudget ? .red : AppColors.text)
                }
            }
            .listRowBackground(AppColors.cardBackground)

            ForEach(vm.currentExpenses) { expense in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(expense.name)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppColors.text)
                        if !expense.type.isEmpty {
                            Text(expense.type)
                                .font(.system(size: 12))
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                    Spacer()
                    Text(currencyString(expense.amount))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.text)
                }
                .listRowBackground(AppColors.cardBackground)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        Task {
                            let result = await vm.deleteExpense(projectId: projectId, expenseId: expense.id)
                            if !result.success { errorMessage = result.error }
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 12))
                    .foregroundColor(.red)
                    .listRowBackground(AppColors.cardBackground)
            }
        } header: {
            HStack {
                Text("Budget")
                Spacer()
                Button {
                    showingAddExpense = true
                } label: {
                    Text("Add Expense")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppColors.primary)
                }
            }
        }
        .sheet(isPresented: $showingAddExpense) {
            AddExpenseSheet(vm: vm, projectId: projectId)
        }
    }

    private var overBudget: Bool {
        guard let budget else { return false }
        return totalSpent > budget
    }
}

private struct AddExpenseSheet: View {
    @ObservedObject var vm: ProjectsViewModel
    let projectId: String
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var type = ""
    @State private var amountText = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    FormTextField(label: "Expense Name", placeholder: "e.g. Venue deposit", text: $name)
                    FormTextField(label: "Expense Type", placeholder: "e.g. Venue", text: $type)
                    FormTextField(label: "Amount", placeholder: "e.g. 250", text: $amountText, keyboardType: .decimalPad)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundColor(.red)
                    }
                }
                .padding(20)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Add Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save") { Task { await handleSave() } }
                    }
                }
            }
        }
    }

    private func handleSave() async {
        isSaving = true
        errorMessage = nil
        let result = await vm.addExpense(projectId: projectId, name: name, type: type, amount: Double(amountText) ?? 0)
        isSaving = false
        if result.success {
            dismiss()
        } else {
            errorMessage = result.error
        }
    }
}
