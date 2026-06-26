import Foundation

// MARK: - Enums

public enum SplitMode: String, Codable, Sendable {
    case equal
    case proportional
}

public enum SplitType: String, Codable, Sendable {
    case `default`
    case equal
    case proportional
    case custom
    case treat
}

// MARK: - Domain models (mirror DB schema; amount fields are always minor units)

public struct Household: Codable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var baseCurrency: String
    public var splitMode: SplitMode
    public var inviteCode: String?
    public let createdAt: Date
}

public struct HouseholdMember: Codable, Identifiable, Sendable {
    public let id: UUID
    public let householdId: UUID
    public let userId: UUID
    public var displayName: String
    public var avatarEmoji: String
    public var incomeShare: Int  // 0–100, used when splitMode = .proportional
    public let createdAt: Date
}

public struct Category: Codable, Identifiable, Sendable {
    public let id: UUID
    public let householdId: UUID
    public var name: String
    public var icon: String
    public var colorHex: String
    public var monthlyBudget: Int?  // minor units; nil = no budget
    public var sortOrder: Int
}

public struct Expense: Codable, Identifiable, Sendable {
    public let id: UUID
    public let householdId: UUID
    public var payerId: UUID
    public var amount: Int          // minor units, always > 0
    public var currency: String
    public var categoryId: UUID?
    public var description: String?
    public var spentOn: String      // "YYYY-MM-DD" (DB date type)
    public var splitType: SplitType
    public var customSplit: [String: Int]?  // member_id (string) → minor units
    public var isTreat: Bool
    public var eventId: UUID?
    public var receiptPath: String?
    public let createdBy: UUID
    public let createdAt: Date
}

public struct Event: Codable, Identifiable, Sendable {
    public let id: UUID
    public let householdId: UUID
    public var name: String
    public var emoji: String
    public let createdAt: Date
}

public struct Settlement: Codable, Identifiable, Sendable {
    public let id: UUID
    public let householdId: UUID
    public let fromMember: UUID
    public let toMember: UUID
    public var amount: Int          // minor units
    public var settledOn: String    // "YYYY-MM-DD"
    public var note: String?
}

public struct Goal: Codable, Identifiable, Sendable {
    public let id: UUID
    public let householdId: UUID
    public var name: String
    public var targetAmount: Int    // minor units
    public var savedAmount: Int     // minor units
    public var targetDate: String?  // "YYYY-MM-DD"
    public let createdAt: Date
}

public struct RecurringExpense: Codable, Identifiable, Sendable {
    public let id: UUID
    public let householdId: UUID
    public let payerId: UUID
    public var amount: Int
    public var currency: String
    public var categoryId: UUID?
    public var description: String?
    public var cadence: String      // "monthly" only in v1
    public var dayOfMonth: Int
    public var nextRun: String      // "YYYY-MM-DD"
    public var active: Bool
}
