import SwiftUI

struct AddGoalView: View {
    @Environment(PariClient.self) private var client
    @Binding var isPresented: Bool

    @State private var name = ""
    @State private var amountString = ""
    @State private var hasDate = false
    @State private var targetDate = Date().addingTimeInterval(60 * 60 * 24 * 90)
    @State private var isLoading = false
    @State private var error: String?

    private var currency: String { client.household?.baseCurrency ?? "EUR" }
    private var cents: Int { parseAmountToCents(amountString) }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.paper.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        PariField("Goal name (e.g. Holiday 🌴)", text: $name)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Target amount")
                                .font(.footnote)
                                .foregroundStyle(Theme.ink.opacity(0.5))
                            HStack {
                                Text(Locale.current.currencySymbol ?? "€")
                                    .foregroundStyle(Theme.ink.opacity(0.5))
                                TextField("0", text: $amountString)
                                    .keyboardType(.decimalPad)
                                    .font(.system(.title2, design: .rounded, weight: .semibold))
                            }
                            .padding(14)
                            .background(Theme.mist)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        Toggle(isOn: $hasDate) {
                            Text("Set a target date")
                                .font(.system(.body, design: .rounded))
                                .foregroundStyle(Theme.ink)
                        }
                        .tint(Theme.sage)

                        if hasDate {
                            DatePicker("By", selection: $targetDate, displayedComponents: .date)
                                .datePickerStyle(.graphical)
                                .tint(Theme.sage)
                        }

                        if let error {
                            Text(error).font(.footnote).foregroundStyle(.red)
                        }

                        PariButton("Add goal", style: .primary, loading: isLoading) {
                            save()
                        }
                        .disabled(name.isEmpty || cents == 0)
                    }
                    .padding(24)
                }
            }
            .navigationTitle("New goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                        .foregroundStyle(Theme.ink)
                }
            }
        }
    }

    private func save() {
        isLoading = true
        error = nil
        Task {
            do {
                try await client.addGoal(
                    name: name.trimmingCharacters(in: .whitespaces),
                    targetAmount: cents,
                    targetDate: hasDate ? targetDate : nil
                )
                isPresented = false
            } catch {
                self.error = error.localizedDescription
            }
            isLoading = false
        }
    }
}
