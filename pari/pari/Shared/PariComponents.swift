import SwiftUI

// MARK: - PariButton

struct PariButton: View {
    enum Style { case primary, secondary }

    let label: String
    let style: Style
    var loading: Bool = false
    let action: () -> Void

    init(_ label: String, style: Style, loading: Bool = false, action: @escaping () -> Void) {
        self.label = label
        self.style = style
        self.loading = loading
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                if loading {
                    ProgressView().tint(style == .primary ? Theme.paper : Theme.ink)
                } else {
                    Text(label)
                        .font(.system(.body, design: .rounded, weight: .semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(style == .primary ? Theme.ink : Theme.mist)
            .foregroundStyle(style == .primary ? Theme.paper : Theme.ink)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(loading)
    }
}

// MARK: - PariField

struct PariField: View {
    let placeholder: String
    @Binding var text: String

    init(_ placeholder: String, text: Binding<String>) {
        self.placeholder = placeholder
        self._text = text
    }

    var body: some View {
        TextField(placeholder, text: $text)
            .font(.system(.body, design: .rounded))
            .padding(14)
            .background(Theme.mist)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(Theme.ink)
    }
}

// MARK: - MainTabView

struct MainTabView: View {
    @Environment(PariClient.self) private var client
    @State private var selectedTab = 0
    @State private var showAddExpense = false

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(showAddExpense: $showAddExpense)
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(0)

            ExpenseListView(showAddExpense: $showAddExpense)
                .tabItem { Label("Expenses", systemImage: "list.bullet") }
                .tag(1)

            BudgetView()
                .tabItem { Label("Budget", systemImage: "chart.bar.fill") }
                .tag(2)

            GoalsView()
                .tabItem { Label("Goals", systemImage: "star.fill") }
                .tag(3)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(4)
        }
        .tint(Theme.sage)
        .sheet(isPresented: $showAddExpense) {
            AddExpenseView()
        }
    }
}
