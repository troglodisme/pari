import SwiftUI

struct AmountKeypad: View {
    @Binding var amountString: String

    private let keys: [[String]] = [
        ["7", "8", "9"],
        ["4", "5", "6"],
        ["1", "2", "3"],
        [".", "0", "⌫"],
    ]

    var body: some View {
        VStack(spacing: 1) {
            ForEach(keys, id: \.self) { row in
                HStack(spacing: 1) {
                    ForEach(row, id: \.self) { key in
                        Button { tap(key) } label: {
                            Group {
                                if key == "⌫" {
                                    Image(systemName: "delete.left")
                                        .font(.system(size: 18, weight: .medium))
                                } else {
                                    Text(key)
                                        .font(.system(size: 24, weight: .medium, design: .rounded))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Theme.mist.opacity(0.8))
                            .foregroundStyle(Theme.ink)
                        }
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func tap(_ key: String) {
        switch key {
        case "⌫":
            if !amountString.isEmpty { amountString.removeLast() }
        case ".":
            if !amountString.contains(".") {
                amountString = amountString.isEmpty ? "0." : amountString + "."
            }
        default:
            if let dotIndex = amountString.firstIndex(of: ".") {
                let decimals = amountString.distance(from: dotIndex, to: amountString.endIndex) - 1
                if decimals >= 2 { return }
            }
            let parts = amountString.components(separatedBy: ".")
            if parts[0].count >= 6 && !amountString.contains(".") { return }
            amountString += key
        }
    }
}

// MARK: - Helpers

func parseAmountToCents(_ string: String) -> Int {
    let parts = string.components(separatedBy: ".")
    let major = Int(parts[0]) ?? 0
    let minor: Int = parts.count > 1 ? (Int((parts[1] + "00").prefix(2)) ?? 0) : 0
    return major * 100 + minor
}

func centsToAmountString(_ cents: Int) -> String {
    let major = cents / 100
    let minor = cents % 100
    if minor == 0 { return "\(major)" }
    return minor < 10 ? "\(major).0\(minor)" : "\(major).\(minor)"
}
