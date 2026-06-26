import SwiftUI

struct AddExpenseView: View {
    @Environment(PariClient.self) private var client
    @Environment(\.dismiss) private var dismiss

    var expense: Expense? = nil

    @State private var amountString = ""
    @State private var selectedCategory: Category?
    @State private var description = ""
    @State private var spentOn = Date()
    @State private var splitType: SplitType = .`default`
    @State private var isTreat = false
    @State private var payerId: UUID?
    @State private var selectedEvent: Event?
    @State private var isRecurring = false
    @State private var dayOfMonth = 1
    @State private var showSplitPicker = false
    @State private var showEventPicker = false
    @State private var showRecurringPicker = false
    @State private var showDeleteConfirm = false
    @State private var isLoading = false
    @State private var error: String?
    @FocusState private var focus: Field?
    private enum Field { case amount, note }

    // Haptic generators
    private let successFeedback = UINotificationFeedbackGenerator()
    private let errorFeedback   = UINotificationFeedbackGenerator()

    private var isEditing: Bool { expense != nil }
    private var currency: String { client.household?.baseCurrency ?? "EUR" }
    private var cents: Int { parseAmountToCents(amountString) }
    private var canSave: Bool { cents > 0 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {

                    // ── Amount field ─────────────────────────────────────
                    // Styled like a big display; system decimal pad handles input.
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(currency.currencySymbol)
                            .font(.system(size: 28, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.ink.opacity(0.35))
                        TextField("0", text: $amountString)
                            .keyboardType(.decimalPad)
                            .focused($focus, equals: .amount)
                            .font(.system(size: 52, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.ink)
                            .multilineTextAlignment(.leading)
                            .fixedSize()
                            .onChange(of: amountString, sanitiseAmount)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .contentShape(Rectangle())
                    .onTapGesture { focus = .amount }

                    Divider()

                    // ── Note + Date ──────────────────────────────────────
                    HStack(spacing: 10) {
                        TextField("Note (optional)", text: $description)
                            .focused($focus, equals: .note)
                            .font(.system(.subheadline, design: .rounded))
                            .submitLabel(.done)
                            .onSubmit { focus = nil }
                        Spacer()
                        DatePicker("", selection: $spentOn, displayedComponents: .date)
                            .labelsHidden()
                            .tint(Theme.sage)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)

                    // ── Chips ────────────────────────────────────────────
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            CategoryChip(
                                icon: selectedCategory?.icon ?? "🧾",
                                label: selectedCategory?.name ?? "Category",
                                categories: client.categories,
                                selected: $selectedCategory
                            )
                            if let my = client.myMember, let partner = client.partnerMember {
                                let pid = payerId ?? my.id
                                PayerChip(
                                    myMember: my,
                                    partnerMember: partner,
                                    payerId: Binding(get: { pid }, set: { payerId = $0 })
                                )
                            }
                            Chip(label: splitLabel,
                                 color: isTreat ? Theme.clay.opacity(0.25) : Theme.mist
                            ) { showSplitPicker = true }
                            Chip(
                                label: selectedEvent.map { "\($0.emoji) \($0.name)" } ?? "Event",
                                color: selectedEvent != nil ? Theme.sage.opacity(0.2) : Theme.mist
                            ) { showEventPicker = true }
                            if !isEditing {
                                Chip(
                                    label: isRecurring ? "🔁 Monthly" : "One-time",
                                    color: isRecurring ? Theme.clay.opacity(0.2) : Theme.mist
                                ) { showRecurringPicker = true }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.vertical, 10)

                    if let error {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                    }

                    if isEditing {
                        Divider().padding(.top, 8)
                        Button("Delete expense", role: .destructive) {
                            showDeleteConfirm = true
                        }
                        .font(.subheadline)
                        .padding(.vertical, 16)
                    }
                }
            }
            .background(Theme.paper.ignoresSafeArea())
            .navigationTitle(isEditing ? "Edit expense" : "Add expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isLoading {
                        ProgressView()
                    } else {
                        Button(isEditing ? "Update" : "Save") { save() }
                            .fontWeight(.semibold)
                            .disabled(!canSave)
                    }
                }
            }
            .sheet(isPresented: $showSplitPicker) {
                SplitPickerSheet(splitType: $splitType, isTreat: $isTreat)
                    .presentationDetents([.height(300)])
            }
            .sheet(isPresented: $showEventPicker) {
                EventPickerSheet(selected: $selectedEvent)
                    .presentationDetents([.medium])
            }
            .sheet(isPresented: $showRecurringPicker) {
                RecurringPickerSheet(isRecurring: $isRecurring, dayOfMonth: $dayOfMonth)
                    .presentationDetents([.height(260)])
            }
            .confirmationDialog("Delete this expense?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Delete", role: .destructive) { deleteExpense() }
            }
            .onAppear {
                prefill()
                // Small delay so the sheet is fully presented before keyboard appears
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { focus = .amount }
            }
        }
    }

    // MARK: - Input

    private func sanitiseAmount(old: String, new: String) {
        // Strip anything that's not a digit or decimal point
        var s = new.filter { $0.isNumber || $0 == "." }
        let parts = s.components(separatedBy: ".")
        // Only one decimal point
        if parts.count > 2 { s = "\(parts[0]).\(parts[1])" }
        // Max 2 decimal places
        if parts.count == 2, parts[1].count > 2 {
            s = "\(parts[0]).\(parts[1].prefix(2))"
        }
        // Max 6 digits before decimal
        if let intPart = s.components(separatedBy: ".").first, intPart.count > 6 {
            return
        }
        if s != new { amountString = s }
    }

    // MARK: - Derived

    private var splitLabel: String {
        if isTreat { return "🎁 Treat" }
        switch splitType {
        case .equal:        return "50/50"
        case .proportional: return "By income"
        case .custom:       return "Custom"
        default:
            return client.household?.splitMode == .proportional ? "By income" : "50/50"
        }
    }

    // MARK: - Actions

    private func prefill() {
        if let e = expense {
            amountString     = centsToAmountString(e.amount)
            description      = e.description ?? ""
            spentOn          = dateFromString(e.spentOn)
            isTreat          = e.isTreat
            splitType        = e.isTreat ? .`default` : e.splitType
            payerId          = e.payerId
            selectedCategory = client.categories.first { $0.id == e.categoryId }
            selectedEvent    = client.events.first { $0.id == e.eventId }
        } else {
            if payerId == nil { payerId = client.myMember?.id }
            if selectedCategory == nil { selectedCategory = client.categories.first }
        }
    }

    private func save() {
        guard let pid = payerId ?? client.myMember?.id else { return }
        isLoading = true
        error = nil
        Task {
            do {
                if let existing = expense {
                    try await client.editExpense(
                        id: existing.id,
                        amount: cents,
                        currency: currency,
                        categoryId: selectedCategory?.id,
                        description: description,
                        spentOn: spentOn,
                        splitType: isTreat ? .`default` : splitType,
                        isTreat: isTreat,
                        payerId: pid,
                        eventId: selectedEvent?.id
                    )
                } else {
                    try await client.addExpense(
                        amount: cents,
                        currency: currency,
                        categoryId: selectedCategory?.id,
                        description: description,
                        spentOn: spentOn,
                        splitType: isTreat ? .treat : splitType,
                        isTreat: isTreat,
                        payerId: pid,
                        eventId: selectedEvent?.id,
                        isRecurring: isRecurring,
                        dayOfMonth: dayOfMonth
                    )
                }
                successFeedback.notificationOccurred(.success)
                dismiss()
            } catch {
                self.error = error.localizedDescription
                errorFeedback.notificationOccurred(.error)
            }
            isLoading = false
        }
    }

    private func deleteExpense() {
        guard let existing = expense else { return }
        Task {
            try? await client.deleteExpense(id: existing.id)
            dismiss()
        }
    }

    private func dateFromString(_ s: String) -> Date {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: s) ?? Date()
    }
}

// MARK: - Generic chip

struct Chip: View {
    let label: String
    var color: Color = Color(.systemGray6)
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption.weight(.medium))
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(color)
                .foregroundStyle(Color.primary)
                .clipShape(Capsule())
        }
    }
}

// MARK: - Category chip

struct CategoryChip: View {
    let icon: String
    let label: String
    let categories: [Category]
    @Binding var selected: Category?
    @State private var showPicker = false

    var body: some View {
        Button { showPicker = true } label: {
            HStack(spacing: 4) {
                Text(icon)
                Text(label)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Theme.mist)
            .foregroundStyle(Color.primary)
            .clipShape(Capsule())
        }
        .sheet(isPresented: $showPicker) {
            CategoryPickerSheet(categories: categories, selected: $selected)
                .presentationDetents([.medium])
        }
    }
}

struct CategoryPickerSheet: View {
    let categories: [Category]
    @Binding var selected: Category?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(categories) { cat in
                Button {
                    selected = cat
                    dismiss()
                } label: {
                    HStack {
                        Text(cat.icon).font(.title2)
                        Text(cat.name).foregroundStyle(Color.primary)
                        Spacer()
                        if selected?.id == cat.id {
                            Image(systemName: "checkmark").foregroundStyle(Theme.sage)
                        }
                    }
                }
            }
            .navigationTitle("Category")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Payer chip

struct PayerChip: View {
    let myMember: HouseholdMember
    let partnerMember: HouseholdMember
    @Binding var payerId: UUID

    var label: String {
        payerId == myMember.id
            ? "\(myMember.avatarEmoji) Me"
            : "\(partnerMember.avatarEmoji) \(partnerMember.displayName)"
    }

    var body: some View {
        Button {
            payerId = payerId == myMember.id ? partnerMember.id : myMember.id
        } label: {
            Text(label)
                .font(.caption.weight(.medium))
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Theme.mist)
                .foregroundStyle(Color.primary)
                .clipShape(Capsule())
        }
    }
}

// MARK: - Split picker

struct SplitPickerSheet: View {
    @Binding var splitType: SplitType
    @Binding var isTreat: Bool
    @Environment(\.dismiss) private var dismiss

    private let options: [(String, SplitType, Bool)] = [
        ("Default (household rule)", .`default`, false),
        ("50 / 50",                  .equal,       false),
        ("Income-based",             .proportional, false),
        ("🎁 My treat — I cover it", .equal,        true),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Capsule().fill(Color(.systemGray4)).frame(width: 36, height: 4).padding(.top, 10)
            Text("How to split?")
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .padding(.vertical, 14)
            Divider()
            ForEach(options, id: \.0) { label, type, treat in
                Button {
                    splitType = type; isTreat = treat; dismiss()
                } label: {
                    HStack {
                        Text(label).font(.system(.body, design: .rounded)).foregroundStyle(Color.primary)
                        Spacer()
                        if isTreat == treat && splitType == type {
                            Image(systemName: "checkmark").foregroundStyle(Theme.sage)
                        }
                    }
                    .padding(.horizontal, 24).padding(.vertical, 16)
                }
                Divider().padding(.leading, 24)
            }
            Spacer()
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - Event picker

struct EventPickerSheet: View {
    @Environment(PariClient.self) private var client
    @Binding var selected: Event?
    @Environment(\.dismiss) private var dismiss
    @State private var newName = ""
    @State private var newEmoji = ""
    @State private var isCreating = false
    @State private var createError: String?

    var body: some View {
        NavigationStack {
            List {
                // Clear selection
                Button {
                    selected = nil
                    dismiss()
                } label: {
                    HStack {
                        Text("None").foregroundStyle(Color.primary)
                        Spacer()
                        if selected == nil {
                            Image(systemName: "checkmark").foregroundStyle(Theme.sage)
                        }
                    }
                }

                // Existing events
                if !client.events.isEmpty {
                    Section {
                        ForEach(client.events) { event in
                            Button {
                                selected = event
                                dismiss()
                            } label: {
                                HStack {
                                    Text(event.emoji).font(.title3)
                                    Text(event.name).foregroundStyle(Color.primary)
                                    Spacer()
                                    if selected?.id == event.id {
                                        Image(systemName: "checkmark").foregroundStyle(Theme.sage)
                                    }
                                }
                            }
                        }
                    }
                }

                // Create new event
                Section("New event") {
                    if let createError {
                        Text(createError).font(.caption).foregroundStyle(.red)
                    }
                    HStack(spacing: 10) {
                        TextField("emoji", text: $newEmoji)
                            .frame(width: 50)
                            .multilineTextAlignment(.center)
                            .textInputAutocapitalization(.never)
                        TextField("Name  (e.g. Sea trip)", text: $newName)
                            .submitLabel(.done)
                    }
                    Button {
                        createEvent()
                    } label: {
                        HStack {
                            if isCreating { ProgressView().scaleEffect(0.8) }
                            Text("Create event")
                        }
                    }
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty || isCreating)
                    .foregroundStyle(Theme.sage)
                }
            }
            .navigationTitle("Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func createEvent() {
        let name = newName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let emoji = newEmoji.trimmingCharacters(in: .whitespaces).isEmpty ? "📍" : newEmoji
        isCreating = true
        createError = nil
        Task {
            do {
                let event = try await client.createEvent(name: name, emoji: emoji)
                selected = event
                dismiss()
            } catch {
                createError = error.localizedDescription
            }
            isCreating = false
        }
    }
}

// MARK: - Recurring picker

struct RecurringPickerSheet: View {
    @Binding var isRecurring: Bool
    @Binding var dayOfMonth: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Capsule().fill(Color(.systemGray4)).frame(width: 36, height: 4).padding(.top, 10)

            Text("Recurring expense")
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .padding(.vertical, 14)

            Divider()

            Toggle("Repeat monthly", isOn: $isRecurring)
                .font(.system(.body, design: .rounded))
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .tint(Theme.sage)

            if isRecurring {
                Divider()
                HStack {
                    Text("On the")
                        .font(.system(.body, design: .rounded))
                    Spacer()
                    Picker("Day", selection: $dayOfMonth) {
                        ForEach(1...28, id: \.self) { day in
                            Text(ordinal(day)).tag(day)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 100, height: 80)
                    .clipped()
                    Text("of the month")
                        .font(.system(.body, design: .rounded))
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
            }

            Spacer()

            Button("Done") { dismiss() }
                .font(.system(.body, design: .rounded, weight: .semibold))
                .foregroundStyle(Theme.paper)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Theme.ink)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
        }
        .background(Color(.systemBackground))
    }

    private func ordinal(_ n: Int) -> String {
        let suffix: String
        switch n % 10 {
        case 1 where n % 100 != 11: suffix = "st"
        case 2 where n % 100 != 12: suffix = "nd"
        case 3 where n % 100 != 13: suffix = "rd"
        default: suffix = "th"
        }
        return "\(n)\(suffix)"
    }
}
