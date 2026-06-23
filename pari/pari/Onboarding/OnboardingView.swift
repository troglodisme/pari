import SwiftUI

struct OnboardingView: View {
    @Environment(PariClient.self) private var client
    @State private var path: [OnboardingStep] = []

    enum OnboardingStep { case create, join }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                Theme.paper.ignoresSafeArea()

                VStack(spacing: 40) {
                    Spacer()

                    VStack(spacing: 8) {
                        Text("Let's get set up")
                            .font(.system(size: 28, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.ink)
                        Text("One of you creates the household, the other joins.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.ink.opacity(0.5))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }

                    Spacer()

                    VStack(spacing: 14) {
                        PariButton("Create our household", style: .primary) {
                            path.append(.create)
                        }

                        PariButton("I have an invite code", style: .secondary) {
                            path.append(.join)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 48)
                }
            }
            .navigationDestination(for: OnboardingStep.self) { step in
                switch step {
                case .create: CreateHouseholdView()
                case .join:   JoinHouseholdView()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Sign out") {
                        Task { try? await client.signOut() }
                    }
                    .font(.footnote)
                    .foregroundStyle(Theme.ink.opacity(0.4))
                }
            }
        }
    }
}
