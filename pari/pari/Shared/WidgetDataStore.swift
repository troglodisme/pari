import Foundation
import WidgetKit

// Writes the minimal snapshot the widget needs into a shared App Group.
// Call save() after any data load or mutation; call clear() on sign-out.
enum WidgetDataStore {
    private static let suite = "group.ambientworks.pari"

    static func save(
        balance: Int,
        currency: String,
        myName: String,
        partnerName: String,
        lastExpense: (description: String?, amount: Int)?
    ) {
        guard let d = UserDefaults(suiteName: suite) else { return }
        d.set(balance,      forKey: "balance")
        d.set(currency,     forKey: "currency")
        d.set(myName,       forKey: "myName")
        d.set(partnerName,  forKey: "partnerName")
        d.set(true,         forKey: "isSignedIn")
        if let last = lastExpense {
            d.set(last.description ?? "", forKey: "lastDesc")
            d.set(last.amount, forKey: "lastAmount")
        } else {
            d.removeObject(forKey: "lastDesc")
            d.removeObject(forKey: "lastAmount")
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func clear() {
        guard let d = UserDefaults(suiteName: suite) else { return }
        d.set(false, forKey: "isSignedIn")
        WidgetCenter.shared.reloadAllTimelines()
    }
}
