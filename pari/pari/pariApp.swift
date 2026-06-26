import SwiftUI

@main
struct pariApp: App {
    @State private var client = PariClient()
    @State private var showAddExpense = false

    var body: some Scene {
        WindowGroup {
            ContentView(showAddExpense: $showAddExpense)
                .environment(client)
                .task { await client.initialize() }
                .onOpenURL { url in
                    // pari://add — tapping the widget opens the add expense sheet
                    if url.scheme == "pari", url.host == "add" {
                        showAddExpense = true
                    }
                }
        }
    }
}
