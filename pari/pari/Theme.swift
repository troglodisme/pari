import SwiftUI

enum Theme {
    static let sage  = Color(hex: "#8AB6A6")
    static let clay  = Color(hex: "#E0A47C")
    static let ink   = Color(hex: "#2E2A26")
    static let paper = Color(hex: "#FBF8F3")
    static let mist  = Color(hex: "#EDE7DD")
}

extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        self.init(
            red:   Double((int >> 16) & 0xFF) / 255,
            green: Double((int >> 8)  & 0xFF) / 255,
            blue:  Double( int        & 0xFF) / 255
        )
    }
}

extension String {
    /// Returns the symbol for a currency code ("EUR" → "€").
    var currencySymbol: String {
        switch self {
        case "EUR": return "€"
        case "USD": return "$"
        case "GBP": return "£"
        case "CHF": return "Fr"
        case "JPY": return "¥"
        case "CAD": return "CA$"
        case "AUD": return "A$"
        case "SEK", "NOK", "DKK": return "kr"
        default: return self
        }
    }
}

extension Int {
    /// Converts minor units (cents) to a locale-formatted currency string.
    func asCurrency(_ code: String = "EUR") -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        let decimal = Decimal(self) / 100
        return formatter.string(from: decimal as NSDecimalNumber) ?? "\(code) \(self)"
    }

    /// Absolute value of minor units as currency string, no sign.
    func absAsCurrency(_ code: String = "EUR") -> String {
        abs(self).asCurrency(code)
    }
}
