import SwiftUI

struct SettleView: View {
    @Environment(PariClient.self) private var client
    @Binding var isPresented: Bool

    @State private var note = ""
    @State private var isLoading = false
    @State private var done = false

    private var currency: String { client.household?.baseCurrency ?? "EUR" }
    private var absBalance: Int { abs(client.balance) }
    private var iAhead: Bool { client.balance > 0 }
    private var partnerName: String { client.partnerMember?.displayName ?? "your partner" }
    private var myName: String { client.myMember?.displayName ?? "You" }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.paper.ignoresSafeArea()

                if done {
                    VStack(spacing: 24) {
                        Spacer()
                        Text("✅")
                            .font(.system(size: 72))
                        Text("You're even!")
                            .font(.system(size: 28, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.ink)
                        Text("Settlement recorded. Fresh start.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.ink.opacity(0.5))
                        Spacer()
                        PariButton("Done", style: .primary) { isPresented = false }
                            .padding(.horizontal, 32)
                            .padding(.bottom, 40)
                    }
                } else {
                    VStack(spacing: 0) {
                        Spacer()

                        VStack(spacing: 28) {
                            // Balance summary
                            VStack(spacing: 8) {
                                Text(iAhead
                                     ? "\(partnerName) owes you"
                                     : "You owe \(partnerName)")
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.ink.opacity(0.5))

                                Text(absBalance.asCurrency(currency))
                                    .font(.system(size: 44, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Theme.ink)

                                Text(iAhead
                                     ? "Record a payment from \(partnerName) to square up."
                                     : "Record a payment from you to \(partnerName).")
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.ink.opacity(0.45))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 32)
                            }

                            PariField("Note (optional)", text: $note)
                                .padding(.horizontal, 32)
                        }

                        Spacer()

                        VStack(spacing: 12) {
                            PariButton("Record full settlement", style: .primary, loading: isLoading) {
                                settle(amount: absBalance)
                            }

                            Button("Not now") { isPresented = false }
                                .font(.subheadline)
                                .foregroundStyle(Theme.ink.opacity(0.4))
                        }
                        .padding(.horizontal, 32)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("Square up")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                        .foregroundStyle(Theme.ink.opacity(0.5))
                }
            }
        }
    }

    private func settle(amount: Int) {
        isLoading = true
        Task {
            try? await client.settle(amount: amount, note: note.isEmpty ? nil : note)
            done = true
            isLoading = false
        }
    }
}
