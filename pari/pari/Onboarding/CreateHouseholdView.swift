import SwiftUI

struct CreateHouseholdView: View {
    @Environment(PariClient.self) private var client
    @State private var householdName = "Us"
    @State private var displayName = ""
    @State private var avatarEmoji = "🙂"
    @State private var splitMode: SplitMode = .equal
    @State private var myShare = 50
    @State private var partnerShare = 50
    @State private var isLoading = false
    @State private var error: String?
    @State private var showEmojiPicker = false

    private let emojis = ["🙂","😊","😎","🥰","🤩","😄","🐻","🦊","🐱","🐶","🦋","🌸"]

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {

                    // Emoji + Name row
                    VStack(spacing: 12) {
                        Button {
                            showEmojiPicker.toggle()
                        } label: {
                            Text(avatarEmoji)
                                .font(.system(size: 56))
                        }

                        if showEmojiPicker {
                            EmojiPickerRow(selected: $avatarEmoji, emojis: emojis) {
                                showEmojiPicker = false
                            }
                        }

                        PariField("Your name", text: $displayName)
                    }

                    Divider().background(Theme.mist)

                    // Household name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Household name")
                            .font(.footnote)
                            .foregroundStyle(Theme.ink.opacity(0.5))
                        PariField("e.g. Us, Our Home", text: $householdName)
                    }

                    Divider().background(Theme.mist)

                    // Split mode
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Default split")
                            .font(.footnote)
                            .foregroundStyle(Theme.ink.opacity(0.5))

                        HStack(spacing: 10) {
                            SplitModeChip("50 / 50", selected: splitMode == .equal) {
                                splitMode = .equal
                            }
                            SplitModeChip("Income-based", selected: splitMode == .proportional) {
                                splitMode = .proportional
                            }
                        }

                        if splitMode == .proportional {
                            VStack(spacing: 8) {
                                HStack {
                                    Text("My share: \(myShare)%")
                                        .font(.subheadline)
                                    Spacer()
                                }
                                Slider(value: Binding(
                                    get: { Double(myShare) },
                                    set: { v in
                                        myShare = Int(v)
                                        partnerShare = 100 - myShare
                                    }
                                ), in: 10...90, step: 5)
                                .tint(Theme.sage)
                                Text("Partner's share: \(partnerShare)%")
                                    .font(.caption)
                                    .foregroundStyle(Theme.ink.opacity(0.5))
                            }
                        }
                    }

                    if let error {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }

                    PariButton("Create household", style: .primary, loading: isLoading) {
                        create()
                    }
                    .disabled(displayName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(24)
            }
        }
        .navigationTitle("Create household")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func create() {
        isLoading = true
        error = nil
        Task {
            do {
                try await client.createHousehold(
                    name: householdName.isEmpty ? "Us" : householdName,
                    displayName: displayName.trimmingCharacters(in: .whitespaces),
                    avatarEmoji: avatarEmoji,
                    splitMode: splitMode
                )
            } catch {
                self.error = error.localizedDescription
            }
            isLoading = false
        }
    }
}

struct EmojiPickerRow: View {
    @Binding var selected: String
    let emojis: [String]
    let onSelect: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(emojis, id: \.self) { e in
                    Button {
                        selected = e
                        onSelect()
                    } label: {
                        Text(e)
                            .font(.system(size: 32))
                            .padding(6)
                            .background(selected == e ? Theme.mist : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }
}

struct SplitModeChip: View {
    let label: String
    let selected: Bool
    let action: () -> Void

    init(_ label: String, selected: Bool, action: @escaping () -> Void) {
        self.label = label
        self.selected = selected
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(selected ? Theme.sage : Theme.mist)
                .foregroundStyle(Theme.ink)
                .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }
}
