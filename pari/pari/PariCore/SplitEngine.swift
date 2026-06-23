import Foundation

// Pure math — no actor isolation required.
public enum SplitEngine {

    /// Returns each member's share in minor units for a given expense.
    /// Shares sum exactly to `expense.amount` (payer absorbs any odd cent).
    /// Treat expenses should not be passed here; callers should check `expense.isTreat` first.
    public static func shares(
        for expense: Expense,
        household: Household,
        primary: HouseholdMember,
        partner: HouseholdMember
    ) -> [UUID: Int] {
        let a = primary.id
        let b = partner.id
        let amount = expense.amount
        let payerId = expense.payerId

        switch resolved(splitType: expense.splitType, householdMode: household.splitMode) {
        case .equal:
            let half = amount / 2
            let remainder = amount - half * 2
            // Payer absorbs the odd cent so shares always sum to amount.
            return payerId == a
                ? [a: half + remainder, b: half]
                : [a: half, b: half + remainder]

        case .proportional:
            let total = primary.incomeShare + partner.incomeShare
            guard total > 0 else {
                return equalSplit(amount: amount, payerId: payerId, a: a, b: b)
            }
            let portionA = (amount * primary.incomeShare) / total
            return [a: portionA, b: amount - portionA]

        case .custom:
            guard let dict = expense.customSplit else {
                return equalSplit(amount: amount, payerId: payerId, a: a, b: b)
            }
            return [
                a: dict[a.uuidString] ?? 0,
                b: dict[b.uuidString] ?? 0
            ]
        }
    }

    // MARK: - Private

    private enum ResolvedMode { case equal, proportional, custom }

    private static func resolved(splitType: SplitType, householdMode: SplitMode) -> ResolvedMode {
        switch splitType {
        case .equal:        return .equal
        case .proportional: return .proportional
        case .custom:       return .custom
        case .treat:        return .equal  // treats are excluded by BalanceEngine; fallback is safe
        case .`default`:
            return householdMode == .equal ? .equal : .proportional
        }
    }

    private static func equalSplit(amount: Int, payerId: UUID, a: UUID, b: UUID) -> [UUID: Int] {
        let half = amount / 2
        let remainder = amount - half * 2
        return payerId == a ? [a: half + remainder, b: half] : [a: half, b: half + remainder]
    }
}
