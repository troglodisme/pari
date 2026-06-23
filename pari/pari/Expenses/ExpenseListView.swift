import SwiftUI

struct ExpenseListView: View {
    @Environment(PariClient.self) private var client
    @Binding var showAddExpense: Bool
    @State private var expenseToEdit: Expense?
    @State private var expenseToDelete: Expense?

    var grouped: [(String, [Expense])] {
        let sorted = client.expenses
        var result: [(String, [Expense])] = []
        var current: [Expense] = []
        var currentMonth = ""
        for e in sorted {
            let month = String(e.spentOn.prefix(7))
            if month != currentMonth {
                if !current.isEmpty { result.append((currentMonth, current)) }
                currentMonth = month
                current = [e]
            } else {
                current.append(e)
            }
        }
        if !current.isEmpty { result.append((currentMonth, current)) }
        return result
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.paper.ignoresSafeArea()

                if client.expenses.isEmpty {
                    EmptyActivityView(onAdd: { showAddExpense = true })
                } else {
                    List {
                        ForEach(grouped, id: \.0) { month, items in
                            Section(header: Text(monthLabel(month))
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Theme.ink.opacity(0.4))
                            ) {
                                ForEach(items) { expense in
                                    Button { expenseToEdit = expense } label: {
                                        ExpenseRow(expense: expense)
                                    }
                                    .buttonStyle(.plain)
                                    .listRowInsets(EdgeInsets())
                                    .listRowBackground(Color.white)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            expenseToDelete = expense
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Expenses")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddExpense = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(Theme.ink)
                    }
                }
            }
            .refreshable { try? await client.loadHousehold() }
            .sheet(item: $expenseToEdit) { expense in
                AddExpenseView(expense: expense)
            }
            .confirmationDialog(
                "Delete this expense?",
                isPresented: Binding(
                    get: { expenseToDelete != nil },
                    set: { if !$0 { expenseToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let e = expenseToDelete {
                        Task { try? await client.deleteExpense(id: e.id) }
                    }
                    expenseToDelete = nil
                }
            }
        }
    }

    private func monthLabel(_ yyyymm: String) -> String {
        let parts = yyyymm.components(separatedBy: "-")
        guard parts.count == 2,
              let year = Int(parts[0]),
              let month = Int(parts[1]) else { return yyyymm }
        var components = DateComponents()
        components.year = year
        components.month = month
        let date = Calendar.current.date(from: components) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
}
