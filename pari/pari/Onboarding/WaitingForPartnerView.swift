import SwiftUI

struct WaitingForPartnerView: View {
    @Environment(PariClient.self) private var client
    @State private var copied = false

    var inviteCode: String {
        client.household?.inviteCode ?? "——"
    }

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 24) {
                    Text("🎉")
                        .font(.system(size: 64))

                    VStack(spacing: 8) {
                        Text("Household created!")
                            .font(.system(size: 26, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.ink)
                        Text("Share this code with your partner so they can join.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.ink.opacity(0.5))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }

                    // Code card
                    Button {
                        UIPasteboard.general.string = inviteCode
                        copied = true
                        Task {
                            try? await Task.sleep(for: .seconds(2))
                            copied = false
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Text(inviteCode)
                                .font(.system(size: 40, weight: .semibold, design: .monospaced))
                                .foregroundStyle(Theme.ink)
                                .tracking(8)
                            Text(copied ? "Copied!" : "Tap to copy")
                                .font(.caption)
                                .foregroundStyle(Theme.ink.opacity(0.4))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .background(Theme.mist)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                    }
                    .padding(.horizontal, 24)

                    HStack(spacing: 8) {
                        ProgressView()
                            .tint(Theme.sage)
                        Text("Waiting for your partner…")
                            .font(.subheadline)
                            .foregroundStyle(Theme.ink.opacity(0.5))
                    }
                }

                Spacer()

                Button("Sign out") {
                    Task { try? await client.signOut() }
                }
                .font(.footnote)
                .foregroundStyle(Theme.ink.opacity(0.3))
                .padding(.bottom, 32)
            }
        }
        .task { await client.pollForPartner() }
    }
}
