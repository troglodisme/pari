import SwiftUI

struct BalanceCard: View {
    let balance: Int
    let myName: String
    let partnerName: String
    let currency: String
    let monthTotal: Int
    let onSettle: () -> Void

    private var isEven: Bool { balance == 0 }
    private var iAhead: Bool { balance > 0 }

    private var cardColor: Color {
        if isEven { return Theme.sage.opacity(0.25) }
        return iAhead ? Theme.sage.opacity(0.18) : Theme.clay.opacity(0.22)
    }

    private var headline: String {
        if isEven { return "You're even." }
        let amt = abs(balance).asCurrency(currency)
        return iAhead
            ? "You're \(amt) ahead."
            : "\(partnerName) is \(amt) ahead."
    }

    private var subline: String {
        if isEven { return "All square. Nice work." }
        return iAhead
            ? "\(partnerName) covered a bit less lately."
            : "You've covered a bit less lately."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text(headline)
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.ink)

                Text(subline)
                    .font(.subheadline)
                    .foregroundStyle(Theme.ink.opacity(0.55))
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("This month")
                        .font(.caption)
                        .foregroundStyle(Theme.ink.opacity(0.4))
                    Text(monthTotal.asCurrency(currency))
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                }
                Spacer()
                if !isEven {
                    Button(action: onSettle) {
                        Text("Square up")
                            .font(.system(.footnote, design: .rounded, weight: .semibold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Theme.ink.opacity(0.08))
                            .clipShape(Capsule())
                            .foregroundStyle(Theme.ink)
                    }
                }
            }
        }
        .padding(24)
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .animation(.easeInOut(duration: 0.4), value: balance)
    }
}
