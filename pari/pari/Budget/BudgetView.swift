import SwiftUI

struct BudgetView: View {
    @Environment(PariClient.self) private var client

    private var currency: String { client.household?.baseCurrency ?? "EUR" }

    private var monthPrefix: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        return f.string(from: Date())
    }

    private var thisMonthExpenses: [Expense] {
        client.expenses.filter { !$0.isTreat && $0.spentOn.hasPrefix(monthPrefix) }
    }

    // Spending per category this month
    private func spent(for categoryId: UUID?) -> Int {
        thisMonthExpenses
            .filter { $0.categoryId == categoryId }
            .reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.paper.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 12) {
                        // Month total card
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Total this month")
                                    .font(.footnote)
                                    .foregroundStyle(Theme.ink.opacity(0.45))
                                Text(client.thisMonthTotal.asCurrency(currency))
                                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Theme.ink)
                            }
                            Spacer()
                        }
                        .padding(20)
                        .background(Theme.mist)
                        .clipShape(RoundedRectangle(cornerRadius: 20))

                        // Per-category breakdown
                        ForEach(client.categories) { cat in
                            let spentAmt = spent(for: cat.id)
                            if spentAmt > 0 || cat.monthlyBudget != nil {
                                CategoryBudgetRow(
                                    category: cat,
                                    spent: spentAmt,
                                    currency: currency
                                )
                            }
                        }

                        if client.categories.isEmpty || thisMonthExpenses.isEmpty {
                            Text("Add some expenses to see your budget breakdown.")
                                .font(.subheadline)
                                .foregroundStyle(Theme.ink.opacity(0.4))
                                .multilineTextAlignment(.center)
                                .padding(.vertical, 40)
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                }
            }
            .navigationTitle("Budget")
            .refreshable { try? await client.loadHousehold() }
        }
    }
}

struct CategoryBudgetRow: View {
    let category: Category
    let spent: Int
    let currency: String

    private var budget: Int? { category.monthlyBudget }
    private var progress: Double {
        guard let b = budget, b > 0 else { return 0 }
        return min(Double(spent) / Double(b), 1.0)
    }
    private var overBudget: Bool {
        guard let b = budget else { return false }
        return spent > b
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text(category.icon)
                    .font(.title3)
                Text(category.name)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(Theme.ink)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(spent.asCurrency(currency))
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(overBudget ? Color.red : Theme.ink)
                    if let b = budget {
                        Text("of \(b.asCurrency(currency))")
                            .font(.caption)
                            .foregroundStyle(Theme.ink.opacity(0.4))
                    }
                }
            }

            if budget != nil {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Theme.mist)
                            .frame(height: 6)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(overBudget ? Color.red.opacity(0.7) : Theme.sage)
                            .frame(width: geo.size.width * progress, height: 6)
                    }
                }
                .frame(height: 6)
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
