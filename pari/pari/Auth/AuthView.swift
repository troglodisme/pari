import SwiftUI
import Supabase

struct AuthView: View {
    @Environment(PariClient.self) private var client
    @State private var isSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var error: String?
    @FocusState private var focused: Field?

    private enum Field { case email, password }

    private var canSubmit: Bool {
        !email.isEmpty && email.contains("@") && password.count >= 6
    }

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 10) {
                    Text("pari")
                        .font(.system(size: 56, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.ink)
                    Text("Share costs together, feel square about money.")
                        .font(.system(size: 17, design: .rounded))
                        .foregroundStyle(Theme.ink.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                Spacer()

                VStack(spacing: 14) {
                    if let error {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }

                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.emailAddress)
                        .font(.system(.body, design: .rounded))
                        .padding(14)
                        .background(Theme.mist)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .focused($focused, equals: .email)
                        .submitLabel(.next)
                        .onSubmit { focused = .password }

                    SecureField("Password", text: $password)
                        .textContentType(isSignUp ? .newPassword : .password)
                        .font(.system(.body, design: .rounded))
                        .padding(14)
                        .background(Theme.mist)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .focused($focused, equals: .password)
                        .submitLabel(.go)
                        .onSubmit { if canSubmit { submit() } }

                    PariButton(isSignUp ? "Create account" : "Sign in", style: .primary, loading: isLoading) {
                        submit()
                    }
                    .disabled(!canSubmit)

                    Button(isSignUp ? "Already have an account? Sign in" : "No account? Create one") {
                        isSignUp.toggle()
                        error = nil
                    }
                    .font(.subheadline)
                    .foregroundStyle(Theme.ink.opacity(0.4))
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
                .animation(.easeInOut(duration: 0.15), value: isSignUp)
            }
        }
        .onAppear {
            // Small delay so the view is fully presented before focusing
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                focused = .email
            }
        }
    }

    private func submit() {
        isLoading = true
        error = nil
        Task {
            do {
                let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
                if isSignUp {
                    let response = try await client.supabase.auth.signUp(
                        email: trimmedEmail, password: password
                    )
                    if response.session == nil {
                        self.error = "Check your inbox and confirm your email, then sign in here."
                        isSignUp = false
                    }
                } else {
                    try await client.supabase.auth.signIn(email: trimmedEmail, password: password)
                }
            } catch {
                self.error = error.localizedDescription
            }
            isLoading = false
        }
    }
}

#Preview {
    AuthView().environment(PariClient())
}
