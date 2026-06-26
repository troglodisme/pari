import Foundation
import Supabase
import AuthenticationServices

enum AppState: Equatable {
    case loading
    case unauthenticated
    case noHousehold
    case waitingForPartner
    case ready
}

// MARK: - Insert payloads (snake_case via encoder strategy)

private struct HouseholdInsert: Encodable {
    let id: UUID          // pre-generated so we can INSERT without RETURNING
    let name: String
    let baseCurrency: String
    let splitMode: String
    let inviteCode: String
}

private struct MemberInsert: Encodable {
    let householdId: UUID
    let userId: UUID
    let displayName: String
    let avatarEmoji: String
}

private struct ExpenseInsert: Encodable {
    let householdId: UUID
    let payerId: UUID
    let amount: Int
    let currency: String
    let categoryId: UUID?
    let description: String?
    let spentOn: String
    let splitType: String
    let customSplit: [String: Int]?
    let isTreat: Bool
    let eventId: UUID?
    let createdBy: UUID
}

private struct EventInsert: Encodable {
    let householdId: UUID
    let name: String
    let emoji: String
}

private struct RecurringInsert: Encodable {
    let householdId: UUID
    let payerId: UUID
    let amount: Int
    let currency: String
    let categoryId: UUID?
    let description: String?
    let cadence: String
    let dayOfMonth: Int
    let nextRun: String
    let active: Bool
}

private struct GoalInsert: Encodable {
    let householdId: UUID
    let name: String
    let targetAmount: Int
    let targetDate: String?
}

private struct SettlementInsert: Encodable {
    let householdId: UUID
    let fromMember: UUID
    let toMember: UUID
    let amount: Int
    let note: String?
}

private struct ExpenseUpdate: Encodable {
    let payerId: UUID
    let amount: Int
    let currency: String
    let categoryId: UUID?
    let description: String?
    let spentOn: String
    let splitType: String
    let isTreat: Bool
    let eventId: UUID?
}

private struct HouseholdUpdate: Encodable {
    let name: String
    let baseCurrency: String
    let splitMode: String
}

private struct MemberUpdate: Encodable {
    let displayName: String
    let avatarEmoji: String
}

private struct DefaultCategoriesParams: Encodable { let pHouseholdId: UUID }
private struct InviteCodeParams: Encodable { let pCode: String }

// MARK: - PariClient

@Observable
final class PariClient {

    // MARK: State
    var appState: AppState = .loading
    var currentUser: User?
    var household: Household?
    var members: [HouseholdMember] = []
    var expenses: [Expense] = []
    var settlements: [Settlement] = []
    var categories: [Category] = []
    var goals: [Goal] = []
    var events: [Event] = []
    var recurringExpenses: [RecurringExpense] = []
    var errorMessage: String?

    // MARK: Derived
    var myMember: HouseholdMember? { members.first { $0.userId == currentUser?.id } }
    var partnerMember: HouseholdMember? { members.first { $0.userId != currentUser?.id } }

    var balance: Int {
        guard let me = myMember, let partner = partnerMember, let hh = household else { return 0 }
        return BalanceEngine.balance(
            expenses: expenses, settlements: settlements,
            primary: me, partner: partner, household: hh
        )
    }

    var thisMonthTotal: Int {
        let prefix = monthPrefix(Date())
        return expenses
            .filter { !$0.isTreat && $0.spentOn.hasPrefix(prefix) }
            .reduce(0) { $0 + $1.amount }
    }

    var recentExpenses: [Expense] { Array(expenses.prefix(10)) }

    // MARK: Supabase
    let supabase: SupabaseClient

    init() {
        // supabase-swift's default encoder/decoder handle dates but NOT snake_case.
        // Copy the date strategies and layer on key conversion.
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = PostgrestClient.Configuration.jsonEncoder.dateEncodingStrategy

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = PostgrestClient.Configuration.jsonDecoder.dateDecodingStrategy

        supabase = SupabaseClient(
            supabaseURL: Secrets.supabaseURL,
            supabaseKey: Secrets.supabaseAnonKey,
            options: SupabaseClientOptions(db: .init(encoder: encoder, decoder: decoder))
        )
    }

    // MARK: - Initialization

    func initialize() async {
        // Iterate the async stream — yields .initialSession on start, then .signedIn/.signedOut.
        for await (event, session) in supabase.auth.authStateChanges {
            currentUser = session?.user
            switch event {
            case .initialSession:
                if session != nil {
                    do { try await loadHousehold() }
                    catch { appState = .noHousehold }
                } else {
                    appState = .unauthenticated
                }
            case .signedIn:
                do { try await loadHousehold() }
                catch { appState = .noHousehold }
            case .signedOut:
                resetState()
                appState = .unauthenticated
            default:
                break
            }
        }
    }

    private func resetState() {
        household = nil
        members = []
        expenses = []
        settlements = []
        categories = []
        goals = []
        events = []
        recurringExpenses = []
    }

    // MARK: - Auth

    func signOut() async throws {
        try await supabase.auth.signOut()
    }

    // MARK: - Household

    func loadHousehold() async throws {
        guard let uid = currentUser?.id else { throw PariError.notAuthenticated }

        let memberships: [HouseholdMember] = try await supabase
            .from("members")
            .select()
            .eq("user_id", value: uid)
            .execute()
            .value

        guard let mine = memberships.first else {
            appState = .noHousehold
            return
        }

        let hh: Household = try await supabase
            .from("households")
            .select()
            .eq("id", value: mine.householdId)
            .single()
            .execute()
            .value
        household = hh

        let allMembers: [HouseholdMember] = try await supabase
            .from("members")
            .select()
            .eq("household_id", value: hh.id)
            .execute()
            .value
        members = allMembers

        if allMembers.count < 2 {
            appState = .waitingForPartner
            return
        }

        async let e  = fetchExpenses(householdId: hh.id)
        async let s  = fetchSettlements(householdId: hh.id)
        async let c  = fetchCategories(householdId: hh.id)
        async let g  = fetchGoals(householdId: hh.id)
        async let ev = fetchEvents(householdId: hh.id)
        async let re = fetchRecurringExpenses(householdId: hh.id)
        (expenses, settlements, categories, goals, events, recurringExpenses) = try await (e, s, c, g, ev, re)

        // Auto-create any recurring expenses that are due
        let created = try await materializeRecurring(householdId: hh.id)
        if created > 0 { expenses = try await fetchExpenses(householdId: hh.id) }

        appState = .ready
    }

    func createHousehold(name: String, displayName: String, avatarEmoji: String, splitMode: SplitMode) async throws {
        guard let uid = currentUser?.id else { throw PariError.notAuthenticated }
        let householdId = UUID()
        let inviteCode = Self.generateInviteCode()

        // INSERT without RETURNING: no member row exists yet so the SELECT policy
        // (household_id = get_my_household_id()) would return NULL and block the response.
        try await supabase
            .from("households")
            .insert(HouseholdInsert(
                id: householdId,
                name: name,
                baseCurrency: "EUR",
                splitMode: splitMode.rawValue,
                inviteCode: inviteCode
            ))
            .execute()

        // Same reason: first-ever member INSERT can't use RETURNING because
        // get_my_household_id() reads a snapshot that predates this statement.
        try await supabase
            .from("members")
            .insert(MemberInsert(
                householdId: householdId,
                userId: uid,
                displayName: displayName,
                avatarEmoji: avatarEmoji
            ))
            .execute()

        // Both rows are now committed — SELECT policies work.
        let hh: Household = try await supabase
            .from("households")
            .select()
            .eq("id", value: householdId)
            .single()
            .execute()
            .value
        household = hh

        let member: HouseholdMember = try await supabase
            .from("members")
            .select()
            .eq("user_id", value: uid)
            .eq("household_id", value: householdId)
            .single()
            .execute()
            .value
        members = [member]

        try await supabase
            .rpc("create_default_categories", params: DefaultCategoriesParams(pHouseholdId: householdId))
            .execute()
        categories = try await fetchCategories(householdId: householdId)
        appState = .waitingForPartner
    }

    func joinHousehold(inviteCode: String, displayName: String, avatarEmoji: String) async throws {
        guard let uid = currentUser?.id else { throw PariError.notAuthenticated }

        let householdId: UUID = try await supabase
            .rpc("find_household_by_invite_code", params: InviteCodeParams(pCode: inviteCode.uppercased()))
            .execute()
            .value

        // INSERT without RETURNING for the same snapshot reason as createHousehold.
        try await supabase
            .from("members")
            .insert(MemberInsert(
                householdId: householdId,
                userId: uid,
                displayName: displayName,
                avatarEmoji: avatarEmoji
            ))
            .execute()

        try await loadHousehold()
    }

    func pollForPartner() async {
        guard let hh = household else { return }
        while members.count < 2 {
            try? await Task.sleep(for: .seconds(3))
            let latest: [HouseholdMember] = (try? await supabase
                .from("members")
                .select()
                .eq("household_id", value: hh.id)
                .execute()
                .value) ?? members
            members = latest
            if latest.count >= 2 {
                try? await loadHousehold()
            }
        }
    }

    // MARK: - Expenses

    func addExpense(
        amount: Int,
        currency: String = "EUR",
        categoryId: UUID?,
        description: String?,
        spentOn: Date = Date(),
        splitType: SplitType = .default,
        customSplit: [String: Int]? = nil,
        isTreat: Bool = false,
        payerId: UUID,
        eventId: UUID? = nil,
        isRecurring: Bool = false,
        dayOfMonth: Int = 1
    ) async throws {
        guard let me = myMember, let hh = household else { throw PariError.notAuthenticated }
        let spentOnStr = dateString(spentOn)
        let insert = ExpenseInsert(
            householdId: hh.id,
            payerId: payerId,
            amount: amount,
            currency: currency,
            categoryId: categoryId,
            description: description.flatMap { $0.isEmpty ? nil : $0 },
            spentOn: spentOnStr,
            splitType: (isTreat ? SplitType.treat : splitType).rawValue,
            customSplit: customSplit,
            isTreat: isTreat,
            eventId: eventId,
            createdBy: me.id
        )
        let expense: Expense = try await supabase
            .from("expenses")
            .insert(insert)
            .select()
            .single()
            .execute()
            .value
        expenses.insert(expense, at: 0)

        if isRecurring {
            // Compute first next_run = same day next month
            let nextRun = advanceMonthly(from: spentOnStr, dayOfMonth: dayOfMonth)
            let rec = RecurringInsert(
                householdId: hh.id,
                payerId: payerId,
                amount: amount,
                currency: currency,
                categoryId: categoryId,
                description: description.flatMap { $0.isEmpty ? nil : $0 },
                cadence: "monthly",
                dayOfMonth: dayOfMonth,
                nextRun: nextRun,
                active: true
            )
            let created: RecurringExpense = try await supabase
                .from("recurring_expenses")
                .insert(rec)
                .select()
                .single()
                .execute()
                .value
            recurringExpenses.append(created)
        }
    }

    func editExpense(
        id: UUID,
        amount: Int,
        currency: String,
        categoryId: UUID?,
        description: String?,
        spentOn: Date,
        splitType: SplitType,
        isTreat: Bool,
        payerId: UUID,
        eventId: UUID? = nil
    ) async throws {
        let update = ExpenseUpdate(
            payerId: payerId,
            amount: amount,
            currency: currency,
            categoryId: categoryId,
            description: description.flatMap { $0.isEmpty ? nil : $0 },
            spentOn: dateString(spentOn),
            splitType: (isTreat ? SplitType.treat : splitType).rawValue,
            isTreat: isTreat,
            eventId: eventId
        )
        try await supabase
            .from("expenses")
            .update(update)
            .eq("id", value: id)
            .execute()
        if let i = expenses.firstIndex(where: { $0.id == id }) {
            expenses[i].payerId = payerId
            expenses[i].amount = amount
            expenses[i].currency = currency
            expenses[i].categoryId = categoryId
            expenses[i].description = description.flatMap { $0.isEmpty ? nil : $0 }
            expenses[i].spentOn = dateString(spentOn)
            expenses[i].splitType = isTreat ? .treat : splitType
            expenses[i].isTreat = isTreat
            expenses[i].eventId = eventId
            expenses.sort { $0.spentOn > $1.spentOn }
        }
    }

    func deleteExpense(id: UUID) async throws {
        expenses.removeAll { $0.id == id }
        try await supabase
            .from("expenses")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    // MARK: - Settlement

    func settle(amount: Int, note: String?) async throws {
        guard let hh = household, let me = myMember, let partner = partnerMember else {
            throw PariError.notAuthenticated
        }
        // from = whoever is behind (owes), to = whoever is ahead
        let from = balance < 0 ? me.id : partner.id
        let to   = balance < 0 ? partner.id : me.id
        let insert = SettlementInsert(
            householdId: hh.id,
            fromMember: from,
            toMember: to,
            amount: amount,
            note: note
        )
        let settlement: Settlement = try await supabase
            .from("settlements")
            .insert(insert)
            .select()
            .single()
            .execute()
            .value
        settlements.append(settlement)
    }

    // MARK: - Goals

    func addGoal(name: String, targetAmount: Int, targetDate: Date?) async throws {
        guard let hh = household else { throw PariError.notAuthenticated }
        let insert = GoalInsert(
            householdId: hh.id,
            name: name,
            targetAmount: targetAmount,
            targetDate: targetDate.map { dateString($0) }
        )
        let goal: Goal = try await supabase
            .from("goals")
            .insert(insert)
            .select()
            .single()
            .execute()
            .value
        goals.append(goal)
    }

    func updateGoalSaved(id: UUID, amount: Int) async throws {
        try await supabase
            .from("goals")
            .update(["saved_amount": amount])
            .eq("id", value: id)
            .execute()
        if let i = goals.firstIndex(where: { $0.id == id }) {
            goals[i].savedAmount = amount
        }
    }

    func deleteGoal(id: UUID) async throws {
        goals.removeAll { $0.id == id }
        try await supabase
            .from("goals")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    // MARK: - Settings

    func updateHousehold(name: String, currency: String, splitMode: SplitMode) async throws {
        guard let hh = household else { return }
        try await supabase
            .from("households")
            .update(HouseholdUpdate(name: name, baseCurrency: currency, splitMode: splitMode.rawValue))
            .eq("id", value: hh.id)
            .execute()
        household?.name = name
        household?.baseCurrency = currency
        household?.splitMode = splitMode
    }

    func updateMember(displayName: String, avatarEmoji: String) async throws {
        guard let me = myMember else { return }
        try await supabase
            .from("members")
            .update(MemberUpdate(displayName: displayName, avatarEmoji: avatarEmoji))
            .eq("id", value: me.id)
            .execute()
        if let i = members.firstIndex(where: { $0.id == me.id }) {
            members[i].displayName = displayName
            members[i].avatarEmoji = avatarEmoji
        }
    }

    // MARK: - Events

    func createEvent(name: String, emoji: String) async throws -> Event {
        guard let hh = household else { throw PariError.notAuthenticated }
        let insert = EventInsert(householdId: hh.id, name: name, emoji: emoji)
        let event: Event = try await supabase
            .from("events")
            .insert(insert)
            .select()
            .single()
            .execute()
            .value
        events.insert(event, at: 0)
        return event
    }

    func deleteEvent(id: UUID) async throws {
        events.removeAll { $0.id == id }
        try await supabase.from("events").delete().eq("id", value: id).execute()
    }

    func updateEvent(id: UUID, name: String, emoji: String) async throws {
        try await supabase
            .from("events")
            .update(["name": name, "emoji": emoji])
            .eq("id", value: id)
            .execute()
        if let i = events.firstIndex(where: { $0.id == id }) {
            events[i].name = name
            events[i].emoji = emoji
        }
    }

    // MARK: - Private fetches

    private func fetchExpenses(householdId: UUID) async throws -> [Expense] {
        try await supabase
            .from("expenses")
            .select()
            .eq("household_id", value: householdId)
            .order("spent_on", ascending: false)
            .execute()
            .value
    }

    private func fetchSettlements(householdId: UUID) async throws -> [Settlement] {
        try await supabase
            .from("settlements")
            .select()
            .eq("household_id", value: householdId)
            .execute()
            .value
    }

    private func fetchCategories(householdId: UUID) async throws -> [Category] {
        try await supabase
            .from("categories")
            .select()
            .eq("household_id", value: householdId)
            .order("sort_order", ascending: true)
            .execute()
            .value
    }

    private func fetchGoals(householdId: UUID) async throws -> [Goal] {
        try await supabase
            .from("goals")
            .select()
            .eq("household_id", value: householdId)
            .execute()
            .value
    }

    private func fetchEvents(householdId: UUID) async throws -> [Event] {
        try await supabase
            .from("events")
            .select()
            .eq("household_id", value: householdId)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    private func fetchRecurringExpenses(householdId: UUID) async throws -> [RecurringExpense] {
        try await supabase
            .from("recurring_expenses")
            .select()
            .eq("household_id", value: householdId)
            .eq("active", value: true)
            .execute()
            .value
    }

    @discardableResult
    private func materializeRecurring(householdId: UUID) async throws -> Int {
        guard let me = myMember else { return 0 }
        let today = dateString(Date())
        let due = recurringExpenses.filter { $0.active && $0.nextRun <= today }
        for recurring in due {
            var nextRun = recurring.nextRun
            while nextRun <= today {
                let insert = ExpenseInsert(
                    householdId: householdId,
                    payerId: recurring.payerId,
                    amount: recurring.amount,
                    currency: recurring.currency,
                    categoryId: recurring.categoryId,
                    description: recurring.description,
                    spentOn: nextRun,
                    splitType: SplitType.default.rawValue,
                    customSplit: nil,
                    isTreat: false,
                    eventId: nil,
                    createdBy: me.id
                )
                try await supabase.from("expenses").insert(insert).execute()
                nextRun = advanceMonthly(from: nextRun, dayOfMonth: recurring.dayOfMonth)
            }
            try await supabase
                .from("recurring_expenses")
                .update(["next_run": nextRun])
                .eq("id", value: recurring.id)
                .execute()
            if let i = recurringExpenses.firstIndex(where: { $0.id == recurring.id }) {
                recurringExpenses[i].nextRun = nextRun
            }
        }
        return due.count
    }

    // MARK: - Utility

    private func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func monthPrefix(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: date)
    }

    private func advanceMonthly(from dateStr: String, dayOfMonth: Int) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        guard let date = f.date(from: dateStr) else { return dateStr }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        guard let next = cal.date(byAdding: .month, value: 1, to: date) else { return dateStr }
        var comps = cal.dateComponents([.year, .month], from: next)
        let daysInMonth = cal.range(of: .day, in: .month, for: next)?.count ?? 28
        comps.day = min(dayOfMonth, daysInMonth)
        guard let result = cal.date(from: comps) else { return dateStr }
        return f.string(from: result)
    }

    static func generateInviteCode() -> String {
        let chars = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<6).map { _ in chars.randomElement()! })
    }
}

// MARK: - Errors

enum PariError: LocalizedError {
    case notAuthenticated
    case appleAuthFailed
    case invalidInviteCode

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:  return "You need to be signed in."
        case .appleAuthFailed:   return "Sign in with Apple didn't complete."
        case .invalidInviteCode: return "That invite code isn't valid."
        }
    }
}
