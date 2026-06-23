import SwiftUI

struct HomeView: View {
    @Environment(PariClient.self) private var client
    @Binding var showAddExpense: Bool
    @State private var showSettle = false
    @State private var expenseToEdit: Expense?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.paper.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {

                        // Balance glance card
                        BalanceCard(
                            balance: client.balance,
                            myName: client.myMember?.displayName ?? "You",
                            partnerName: client.partnerMember?.displayName ?? "Partner",
                            currency: client.household?.baseCurrency ?? "EUR",
                            monthTotal: client.thisMonthTotal,
                            onSettle: { showSettle = true }
                        )

                        // Recent activity
                        if client.recentExpenses.isEmpty {
                            EmptyActivityView(onAdd: { showAddExpense = true })
                        } else {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Recent")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(Theme.ink.opacity(0.4))
                                    .padding(.horizontal, 4)

                                VStack(spacing: 1) {
                                    ForEach(client.recentExpenses) { expense in
                                        Button { expenseToEdit = expense } label: {
                                            ExpenseRow(expense: expense)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                        }

                        Spacer(minLength: 80)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                }
                .refreshable { try? await client.loadHousehold() }

                // Floating add button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            showAddExpense = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(Theme.paper)
                                .frame(width: 56, height: 56)
                                .background(Theme.ink)
                                .clipShape(Circle())
                                .shadow(color: Theme.ink.opacity(0.2), radius: 8, y: 4)
                        }
                        .padding(.trailing, 24)
                        .padding(.bottom, 16)
                    }
                }
            }
            .navigationTitle(client.household?.name ?? "Pari")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showSettle) {
            SettleView(isPresented: $showSettle)
        }
        .sheet(item: $expenseToEdit) { expense in
            AddExpenseView(expense: expense)
        }
    }
}

struct EmptyActivityView: View {
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("🧾")
                .font(.system(size: 48))
            Text("Add your first shared cost")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Theme.ink.opacity(0.5))
            Button(action: onAdd) {
                Text("Add expense")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Theme.mist)
                    .clipShape(Capsule())
                    .foregroundStyle(Theme.ink)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

struct ExpenseRow: View {
    @Environment(PariClient.self) private var client
    let expense: Expense

    private var category: Category? {
        client.categories.first { $0.id == expense.categoryId }
    }

    private var payerName: String {
        client.members.first { $0.id == expense.payerId }?.displayName ?? "?"
    }

    var body: some View {
        HStack(spacing: 14) {
            Text(category?.icon ?? "🧾")
                .font(.title3)
                .frame(width: 40, height: 40)
                .background(Theme.mist)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(expense.description ?? category?.name ?? "Expense")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text("\(payerName) · \(expense.spentOn)")
                    .font(.caption)
                    .foregroundStyle(Theme.ink.opacity(0.4))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(expense.amount.asCurrency(expense.currency))
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                if expense.isTreat {
                    Text("treat")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Theme.clay)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white)
    }
}
