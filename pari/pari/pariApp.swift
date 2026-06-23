import SwiftUI

@main
struct pariApp: App {
    @State private var client = PariClient()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(client)
                .task { await client.initialize() }
        }
    }
}
