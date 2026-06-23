import Foundation

// Pure math — no actor isolation required.
public enum BalanceEngine {

    /// Returns the balance in minor units from `primary`'s perspective.
    ///
    /// Positive  → primary is ahead (paid more than their share; partner owes them).
    /// Negative  → partner is ahead (primary owes partner).
    /// Zero      → perfectly even.
    ///
    /// Formula per §2 of the brief:
    ///   net = Σ(paid) − Σ(shares owed) + Σ(settlements paid out) − Σ(settlements received)
    public static func balance(
        expenses: [Expense],
        settlements: [Settlement],
        primary: HouseholdMember,
        partner: HouseholdMember,
        household: Household
    ) -> Int {
        var paid:  [UUID: Int] = [primary.id: 0, partner.id: 0]
        var owed:  [UUID: Int] = [primary.id: 0, partner.id: 0]

        for expense in expenses where !expense.isTreat {
            paid[expense.payerId, default: 0] += expense.amount

            let shares = SplitEngine.shares(
                for: expense,
                household: household,
                primary: primary,
                partner: partner
            )
            for (memberId, share) in shares {
                owed[memberId, default: 0] += share
            }
        }

        var net = (paid[primary.id] ?? 0) - (owed[primary.id] ?? 0)

        for settlement in settlements {
            if settlement.fromMember == primary.id { net += settlement.amount }
            if settlement.toMember   == primary.id { net -= settlement.amount }
        }

        return net
    }
}
