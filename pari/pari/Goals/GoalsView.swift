import SwiftUI

struct GoalsView: View {
    @Environment(PariClient.self) private var client
    @State private var showAddGoal = false

    private var currency: String { client.household?.baseCurrency ?? "EUR" }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.paper.ignoresSafeArea()

                if client.goals.isEmpty {
                    VStack(spacing: 16) {
                        Text("⭐️")
                            .font(.system(size: 56))
                        Text("Set a goal together")
                            .font(.system(.title3, design: .rounded, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                        Text("Save up for something exciting — a holiday, a sofa, anything.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.ink.opacity(0.5))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        PariButton("Add a goal", style: .primary) { showAddGoal = true }
                            .padding(.horizontal, 40)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 14) {
                            ForEach(client.goals) { goal in
                                GoalCard(goal: goal, currency: currency)
                            }
                            Spacer(minLength: 40)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                    }
                }
            }
            .navigationTitle("Goals")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddGoal = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(Theme.ink)
                    }
                }
            }
            .sheet(isPresented: $showAddGoal) {
                AddGoalView(isPresented: $showAddGoal)
                    .presentationDetents([.medium])
            }
            .refreshable { try? await client.loadHousehold() }
        }
    }
}

struct GoalCard: View {
    @Environment(PariClient.self) private var client
    let goal: Goal
    let currency: String

    private var progress: Double {
        guard goal.targetAmount > 0 else { return 0 }
        return min(Double(goal.savedAmount) / Double(goal.targetAmount), 1.0)
    }
    private var done: Bool { goal.savedAmount >= goal.targetAmount }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.name)
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    if let targetDate = goal.targetDate {
                        Text("By \(targetDate)")
                            .font(.caption)
                            .foregroundStyle(Theme.ink.opacity(0.4))
                    }
                }
                Spacer()
                if done {
                    Text("🎉")
                        .font(.title2)
                } else {
                    Button {
                        Task {
                            let newAmount = min(goal.savedAmount + (goal.targetAmount / 10), goal.targetAmount)
                            try? await client.updateGoalSaved(id: goal.id, amount: newAmount)
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Theme.sage)
                    }
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Theme.mist)
                        .frame(height: 10)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(done ? Theme.clay : Theme.sage)
                        .frame(width: geo.size.width * progress, height: 10)
                        .animation(.spring(duration: 0.5), value: progress)
                }
            }
            .frame(height: 10)

            HStack {
                Text(goal.savedAmount.asCurrency(currency))
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text("of \(goal.targetAmount.asCurrency(currency))")
                    .font(.subheadline)
                    .foregroundStyle(Theme.ink.opacity(0.4))
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.ink.opacity(0.5))
            }
        }
        .padding(18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                Task { try? await client.deleteGoal(id: goal.id) }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
