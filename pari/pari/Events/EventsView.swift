import SwiftUI

struct EventsView: View {
    @Environment(PariClient.self) private var client
    @State private var eventToEdit: Event?
    @State private var showAddEvent = false

    private var currency: String { client.household?.baseCurrency ?? "EUR" }

    // Total spent per event, derived from all expenses
    private func total(for event: Event) -> Int {
        client.expenses
            .filter { $0.eventId == event.id }
            .reduce(0) { $0 + $1.amount }
    }

    private func count(for event: Event) -> Int {
        client.expenses.filter { $0.eventId == event.id }.count
    }

    var body: some View {
        List {
            if client.events.isEmpty {
                Text("No events yet. Add one from the expense form.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.ink.opacity(0.5))
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                    .padding(.vertical, 32)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ForEach(client.events) { event in
                    Button { eventToEdit = event } label: {
                        EventRow(event: event, total: total(for: event),
                                 count: count(for: event), currency: currency)
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.white)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            Task { try? await client.deleteEvent(id: event.id) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.paper.ignoresSafeArea())
        .navigationTitle("Events")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $eventToEdit) { event in
            EditEventSheet(event: event)
        }
    }
}

// MARK: - Row

private struct EventRow: View {
    let event: Event
    let total: Int
    let count: Int
    let currency: String

    var body: some View {
        HStack(spacing: 14) {
            Text(event.emoji)
                .font(.system(size: 28))
                .frame(width: 44, height: 44)
                .background(Theme.mist)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(event.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Theme.ink)
                Text("\(count) expense\(count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(Theme.ink.opacity(0.5))
            }

            Spacer()

            Text(total.asCurrency(currency))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.ink)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Edit sheet

struct EditEventSheet: View {
    @Environment(PariClient.self) private var client
    @Environment(\.dismiss) private var dismiss

    let event: Event

    @State private var name: String
    @State private var emoji: String
    @State private var isSaving = false
    @State private var error: String?

    init(event: Event) {
        self.event = event
        _name = State(initialValue: event.name)
        _emoji = State(initialValue: event.emoji)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    HStack {
                        Text("Emoji")
                            .foregroundStyle(Theme.ink)
                        Spacer()
                        TextField("🎉", text: $emoji)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 50)
                    }

                    HStack {
                        Text("Name")
                            .foregroundStyle(Theme.ink)
                        Spacer()
                        TextField("Event name", text: $name)
                            .multilineTextAlignment(.trailing)
                    }
                }

                if let error {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle("Edit Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.ink)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.sage)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedEmoji = emoji.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        isSaving = true
        error = nil
        Task {
            do {
                try await client.updateEvent(id: event.id, name: trimmedName,
                                             emoji: trimmedEmoji.isEmpty ? "📌" : trimmedEmoji)
                dismiss()
            } catch let e {
                error = e.localizedDescription
            }
            isSaving = false
        }
    }
}
