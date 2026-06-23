import SwiftUI

struct JoinHouseholdView: View {
    @Environment(PariClient.self) private var client
    @State private var inviteCode = ""
    @State private var displayName = ""
    @State private var avatarEmoji = "🙂"
    @State private var isLoading = false
    @State private var error: String?
    @State private var showEmojiPicker = false

    private let emojis = ["🙂","😊","😎","🥰","🤩","😄","🐻","🦊","🐱","🐶","🦋","🌸"]

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    VStack(spacing: 12) {
                        Button { showEmojiPicker.toggle() } label: {
                            Text(avatarEmoji).font(.system(size: 56))
                        }
                        if showEmojiPicker {
                            EmojiPickerRow(selected: $avatarEmoji, emojis: emojis) {
                                showEmojiPicker = false
                            }
                        }
                        PariField("Your name", text: $displayName)
                    }

                    Divider().background(Theme.mist)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Invite code")
                            .font(.footnote)
                            .foregroundStyle(Theme.ink.opacity(0.5))
                        TextField("6-letter code", text: $inviteCode)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .font(.system(.title2, design: .monospaced, weight: .semibold))
                            .multilineTextAlignment(.center)
                            .padding(16)
                            .background(Theme.mist)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    if let error {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }

                    PariButton("Join household", style: .primary, loading: isLoading) {
                        join()
                    }
                    .disabled(inviteCode.count < 6 || displayName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(24)
            }
        }
        .navigationTitle("Join household")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func join() {
        isLoading = true
        error = nil
        Task {
            do {
                try await client.joinHousehold(
                    inviteCode: inviteCode,
                    displayName: displayName.trimmingCharacters(in: .whitespaces),
                    avatarEmoji: avatarEmoji
                )
            } catch {
                self.error = "Couldn't find that code. Double-check with your partner."
            }
            isLoading = false
        }
    }
}
