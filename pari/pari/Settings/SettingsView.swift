import SwiftUI

struct SettingsView: View {
    @Environment(PariClient.self) private var client

    @State private var householdName = ""
    @State private var currency = "EUR"
    @State private var splitMode: SplitMode = .equal
    @State private var displayName = ""
    @State private var avatarEmoji = ""
    @State private var isSaving = false
    @State private var error: String?
    @State private var saved = false

    private let currencies = ["EUR", "USD", "GBP", "CHF", "JPY", "CAD", "AUD", "SEK", "NOK", "DKK"]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.paper.ignoresSafeArea()

                List {
                    Section("Household") {
                        LabeledContent("Name") {
                            TextField("Household name", text: $householdName)
                                .multilineTextAlignment(.trailing)
                                .foregroundStyle(Theme.ink)
                        }

                        Picker("Currency", selection: $currency) {
                            ForEach(currencies, id: \.self) { code in
                                Text("\(code.currencySymbol)  \(code)").tag(code)
                            }
                        }

                        Picker("Default split", selection: $splitMode) {
                            Text("50 / 50").tag(SplitMode.equal)
                            Text("Income-based").tag(SplitMode.proportional)
                        }
                    }

                    Section("My profile") {
                        LabeledContent("Name") {
                            TextField("Display name", text: $displayName)
                                .multilineTextAlignment(.trailing)
                                .foregroundStyle(Theme.ink)
                        }

                        LabeledContent("Avatar") {
                            TextField("😊", text: $avatarEmoji)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 48)
                        }
                    }

                    if let error {
                        Section {
                            Text(error)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                    }

                    Section {
                        PariButton(
                            saved ? "Saved ✓" : "Save changes",
                            style: .primary,
                            loading: isSaving
                        ) { save() }
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                        .listRowBackground(Color.clear)
                    }

                    Section {
                        Button("Sign out", role: .destructive) {
                            Task { try? await client.signOut() }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .onAppear(perform: loadValues)
        }
    }

    private func loadValues() {
        householdName = client.household?.name ?? ""
        currency      = client.household?.baseCurrency ?? "EUR"
        splitMode     = client.household?.splitMode ?? .equal
        displayName   = client.myMember?.displayName ?? ""
        avatarEmoji   = client.myMember?.avatarEmoji ?? ""
    }

    private func save() {
        isSaving = true
        error = nil
        saved = false
        Task {
            do {
                try await client.updateHousehold(name: householdName, currency: currency, splitMode: splitMode)
                try await client.updateMember(displayName: displayName, avatarEmoji: avatarEmoji)
                saved = true
            } catch {
                self.error = error.localizedDescription
            }
            isSaving = false
        }
    }
}
