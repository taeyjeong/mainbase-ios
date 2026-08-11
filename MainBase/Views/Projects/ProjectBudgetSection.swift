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

    @State private var newExpenseName = ""
    @State private var newExpenseAmount = ""
    @State private var isAddingExpense = false
    @State private var errorMessage: String?

    private var totalSpent: Double {
        vm.currentExpenses.reduce(0) { $0 + $1.amount }
    }

    private var canAddExpense: Bool {
        !newExpenseName.trimmingCharacters(in: .whitespaces).isEmpty && (Double(newExpenseAmount) ?? 0) > 0
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

            HStack(spacing: 8) {
                TextField("Expense name", text: $newExpenseName)
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.text)
                TextField("Amount", text: $newExpenseAmount)
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.text)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                if isAddingExpense {
                    ProgressView().scaleEffect(0.7)
                } else {
                    Button(action: { Task { await addExpenseInline() } }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(canAddExpense ? AppColors.primary : AppColors.textSecondary.opacity(0.4))
                    }
                    .buttonStyle(.borderless)
                    .disabled(!canAddExpense)
                }
            }
            .listRowBackground(AppColors.cardBackground)
        } header: {
            HStack {
                Text("Budget")
                Spacer()
            }
        }
    }

    private func addExpenseInline() async {
        isAddingExpense = true
        errorMessage = nil
        let result = await vm.addExpense(projectId: projectId, name: newExpenseName, type: "", amount: Double(newExpenseAmount) ?? 0)
        isAddingExpense = false
        if result.success {
            newExpenseName = ""
            newExpenseAmount = ""
        } else {
            errorMessage = result.error
        }
    }

    private var overBudget: Bool {
        guard let budget else { return false }
        return totalSpent > budget
    }
}
