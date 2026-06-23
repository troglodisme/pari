import SwiftUI

struct AddExpenseView: View {
    @Environment(PariClient.self) private var client
    @Environment(\.dismiss) private var dismiss

    var expense: Expense? = nil   // nil = add mode, non-nil = edit mode

    @State private var amountString = ""
    @State private var selectedCategory: Category?
    @State private var description = ""
    @State private var spentOn = Date()
    @State private var splitType: SplitType = .`default`
    @State private var isTreat = false
    @State private var payerId: UUID?
    @State private var showSplitPicker = false
    @State private var isLoading = false
    @State private var error: String?

    private var isEditing: Bool { expense != nil }
    private var currency: String { client.household?.baseCurrency ?? "EUR" }
    private var cents: Int { parseAmountToCents(amountString) }
    private var canSave: Bool { cents > 0 }

    private var displayAmount: String {
        if amountString.isEmpty { return "0" }
        let parts = amountString.components(separatedBy: ".")
        let major = parts[0]
        if parts.count > 1 {
            return "\(major).\((parts[1] + "00").prefix(2))"
        }
        return major
    }

    var body: some View {
        // Plain VStack — no NavigationStack inside the sheet.
        // NavigationStack registers gesture recognisers that eat the first tap,
        // making the custom keypad feel unresponsive.
        VStack(spacing: 0) {
            // ── Custom header ────────────────────────────────────────────
            HStack {
                Button("Cancel") { dismiss() }
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text(isEditing ? "Edit expense" : "Add expense")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Button(isEditing ? "Update" : "Save") { save() }
                    .fontWeight(.semibold)
                    .foregroundStyle(canSave ? Theme.sage : Theme.ink.opacity(0.3))
                    .disabled(!canSave || isLoading)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Theme.paper)

            Divider()

            ZStack {
                Theme.paper.ignoresSafeArea()

                VStack(spacing: 0) {
                    // ── Amount ──────────────────────────────────────────
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(currency.currencySymbol)
                            .font(.system(size: 28, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.ink.opacity(0.35))
                        Text(displayAmount)
                            .font(.system(size: 52, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.ink)
                            .contentTransition(.numericText())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)

                    Divider()

                    // ── Note + Date ──────────────────────────────────────
                    HStack(spacing: 10) {
                        TextField("Note (optional)", text: $description)
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(Theme.ink)
                        DatePicker("", selection: $spentOn, displayedComponents: .date)
                            .labelsHidden()
                            .tint(Theme.sage)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)

                    // ── Chips ────────────────────────────────────────────
                    HStack(spacing: 6) {
                        // Category
                        CategoryChip(
                            icon: selectedCategory?.icon ?? "🧾",
                            label: selectedCategory?.name ?? "Category",
                            categories: client.categories,
                            selected: $selectedCategory
                        )

                        // Who paid
                        if let my = client.myMember, let partner = client.partnerMember {
                            let pid = payerId ?? my.id
                            PayerChip(
                                myMember: my,
                                partnerMember: partner,
                                payerId: Binding(get: { pid }, set: { payerId = $0 })
                            )
                        }

                        // Split
                        Button { showSplitPicker = true } label: {
                            Text(splitLabel)
                                .font(.caption.weight(.medium))
                                .lineLimit(1)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(isTreat ? Theme.clay.opacity(0.2) : Theme.mist)
                                .foregroundStyle(Theme.ink)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)

                    Divider()

                    if let error {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.top, 6)
                    }

                    // ── Keypad ───────────────────────────────────────────
                    AmountKeypad(amountString: $amountString)
                        .padding(8)
                }
            }
        }
        .background(Theme.paper.ignoresSafeArea())
        .sheet(isPresented: $showSplitPicker) {
            SplitPickerSheet(splitType: $splitType, isTreat: $isTreat)
                .presentationDetents([.height(300)])
        }
        .onAppear(perform: prefill)
    }

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

    private func prefill() {
        if let e = expense {
            amountString   = centsToAmountString(e.amount)
            description    = e.description ?? ""
            spentOn        = dateFromString(e.spentOn)
            isTreat        = e.isTreat
            splitType      = e.isTreat ? .`default` : e.splitType
            payerId        = e.payerId
            selectedCategory = client.categories.first { $0.id == e.categoryId }
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
                        payerId: pid
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
                        payerId: pid
                    )
                }
                dismiss()
            } catch {
                self.error = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func dateFromString(_ s: String) -> Date {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: s) ?? Date()
    }
}

// MARK: - Sub-components

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
            .foregroundStyle(Theme.ink)
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
                        Text(cat.name).foregroundStyle(Theme.ink)
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
                .foregroundStyle(Theme.ink)
                .clipShape(Capsule())
        }
    }
}

struct SplitPickerSheet: View {
    @Binding var splitType: SplitType
    @Binding var isTreat: Bool
    @Environment(\.dismiss) private var dismiss

    private let options: [(String, SplitType, Bool)] = [
        ("Default (household rule)", .`default`, false),
        ("50 / 50", .equal, false),
        ("Income-based", .proportional, false),
        ("🎁 My treat — I cover it", .equal, true),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Theme.mist)
                .frame(width: 36, height: 4)
                .padding(.top, 10)

            Text("How to split?")
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .padding(.vertical, 14)

            Divider()

            ForEach(options, id: \.0) { label, type, treat in
                Button {
                    splitType = type
                    isTreat = treat
                    dismiss()
                } label: {
                    HStack {
                        Text(label)
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(Theme.ink)
                        Spacer()
                        if isTreat == treat && splitType == type {
                            Image(systemName: "checkmark").foregroundStyle(Theme.sage)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                }
                Divider().padding(.leading, 24)
            }

            Spacer()
        }
        .background(Theme.paper)
    }
}
