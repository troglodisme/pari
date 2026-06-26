import SwiftUI

struct ContentView: View {
    @Environment(PariClient.self) private var client
    @Binding var showAddExpense: Bool

    var body: some View {
        Group {
            switch client.appState {
            case .loading:
                ZStack {
                    Theme.paper.ignoresSafeArea()
                    ProgressView().tint(Theme.sage)
                }
            case .unauthenticated:
                AuthView()
            case .noHousehold:
                OnboardingView()
            case .waitingForPartner:
                WaitingForPartnerView()
            case .ready:
                MainTabView(showAddExpenseExternal: $showAddExpense)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: client.appState)
    }
}
