import SwiftUI

struct ExpenseListView: View {
    @Environment(PariClient.self) private var client
    @Binding var showAddExpense: Bool
    @State private var expenseToEdit: Expense?
    @State private var expenseToDelete: Expense?
    @State private var filterEvent: Event? = nil
    @State private var showEvents = false

    // Expenses filtered by the selected event (nil = all)
    private var filteredExpenses: [Expense] {
        guard let event = filterEvent else { return client.expenses }
        return client.expenses.filter { $0.eventId == event.id }
    }

    private var eventTotal: Int {
        filteredExpenses.reduce(0) { $0 + $1.amount }
    }

    private var grouped: [(String, [Expense])] {
        var result: [(String, [Expense])] = []
        var current: [Expense] = []
        var currentMonth = ""
        for e in filteredExpenses {
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

                VStack(spacing: 0) {
                    // ── Event filter chips ───────────────────────────────
                    if !client.events.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                FilterChip(label: "All", selected: filterEvent == nil) {
                                    filterEvent = nil
                                }
                                ForEach(client.events) { event in
                                    FilterChip(
                                        label: "\(event.emoji) \(event.name)",
                                        selected: filterEvent?.id == event.id
                                    ) {
                                        filterEvent = filterEvent?.id == event.id ? nil : event
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                        }
                        .background(Theme.paper)

                        // Event total banner
                        if let event = filterEvent {
                            HStack {
                                Text("\(event.emoji) \(event.name)")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Theme.ink)
                                Spacer()
                                Text(eventTotal.asCurrency(client.household?.baseCurrency ?? "EUR"))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Theme.ink)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Theme.sage.opacity(0.12))
                        }

                        Divider()
                    }

                    // ── Expense list ─────────────────────────────────────
                    if filteredExpenses.isEmpty {
                        Spacer()
                        if filterEvent != nil {
                            VStack(spacing: 12) {
                                Text("No expenses tagged to this event yet.")
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.ink.opacity(0.5))
                                    .multilineTextAlignment(.center)
                                Button("Add one") { showAddExpense = true }
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Theme.sage)
                            }
                            .padding(.horizontal, 40)
                        } else {
                            EmptyActivityView(onAdd: { showAddExpense = true })
                        }
                        Spacer()
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
            }
            .navigationTitle(filterEvent.map { "\($0.emoji) \($0.name)" } ?? "Expenses")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !client.events.isEmpty {
                        Button {
                            showEvents = true
                        } label: {
                            Label("Events", systemImage: "calendar.badge.clock")
                                .foregroundStyle(Theme.ink)
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAddExpense = true } label: {
                        Image(systemName: "plus").foregroundStyle(Theme.ink)
                    }
                }
            }
            .navigationDestination(isPresented: $showEvents) {
                EventsView()
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

// MARK: - Filter chip

struct FilterChip: View {
    let label: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(selected ? Theme.ink : Theme.mist)
                .foregroundStyle(selected ? Theme.paper : Theme.ink)
                .clipShape(Capsule())
        }
    }
}
