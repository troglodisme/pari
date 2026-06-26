# Pari — Build Status

*Last updated: June 2025*

---

## What it is

Pari is an iOS app for couples to share life costs without the "who owes who" spreadsheet feeling. The name is Italian — *siamo pari* = "we're even." That's the emotional promise: two people staying relaxed about money together, not filing invoices at each other.

---

## What's live in the app today

### Auth & pairing
- Sign in with Apple (no passwords)
- Create a household → get a 6-character invite code
- Partner enters the code to join
- Each person picks a display name and avatar emoji
- Choose split mode: 50/50 (default) or income-proportional

### Home screen
- **Balance glance card** — the signature element. Shows one soft statement: "You're even / Kate covered more this month." Card colour shifts with balance state (sage when square, clay tint when someone is ahead)
- This month's total spend
- Recent expenses list

### Expenses
- Add expense: amount → category → who paid → date → split
- Split is automatic (defaults to household setting); one tap to override: Equal / Proportional / My treat / Custom
- *My treat*: payer absorbs it entirely, excluded from balance
- Edit and delete expenses
- Grouped by month
- **Events** — tag expenses to a trip/activity (e.g. "🏖️ Sardinia"). Filter the expense list by event. View all events with their totals, edit or delete them.
- **Recurring expenses** — mark an expense as monthly recurring (rent, nursery, bills). Auto-posted on the right day each month when you open the app.

### Budget
- Per-category monthly budget amounts
- Progress bars: spent vs budget per category
- Month summary total

### Goals
- Shared savings goals with target amounts and optional dates
- Progress bar per goal
- Add/delete goals

### Settle
- Soft "square up" flow — records a settlement and resets the balance
- No nagging or reminders, intentionally gentle

### Widget *(code written, Xcode setup pending)*
- Home screen widget (small + medium) showing the balance and last expense
- Tap to open the Add Expense sheet directly
- Updates every 30 minutes

---

## Design system

| Token | Hex | Used for |
|-------|-----|---------|
| `sage` | `#8AB6A6` | Primary, "even" state, buttons |
| `clay` | `#E0A47C` | "Ahead" highlight, warmth accent |
| `ink` | `#2E2A26` | All text |
| `paper` | `#FBF8F3` | Background (warm off-white) |
| `mist` | `#EDE7DD` | Cards, dividers, chips |

Copy voice: plain, kind, sentence case. "You're even." Never "Outstanding balance: €30.00 owed."

---

## Architecture (for engineers)

- **iOS 26, SwiftUI, Swift Concurrency** (`async/await`, `@Observable`)
- **Supabase** (Postgres + Auth + RLS) — `eu-north-1`, project `mldfxdaevtdbltlwhvld`
- **PariCore** — pure Swift module (no SwiftUI), holds all split math and balance logic. Portable to web/React Native later.
- **PariClient** — `@Observable` Supabase wrapper, injected into the SwiftUI environment
- Money: always `Int` minor units (cents), never floats
- RLS on every table — access enforced at DB level, not just client-side

---

## What's not built yet

| Item | Notes |
|------|-------|
| Receipt photos | Supabase Storage already in the stack, just needs UI |
| CSV export | Free feature, planned for M7 |
| Widget Xcode wiring | Code is written; needs manual target + App Group setup in Xcode |
| Accessibility pass | Dark mode works; Dynamic Type + VoiceOver labels not yet audited |
| Push notifications | Intentionally out of scope for v1 (no debt-collector reminders) |
| Web / React Native | Backend is future-proof for it; iOS first |

---

## Open design questions — ideas welcome

These are areas where the product direction is open and would benefit from design input:

1. **The balance card** — today it's functional but the visual treatment is minimal. This is the signature element; what makes it feel truly warm and memorable? Illustration? Animation when you hit zero?

2. **Onboarding handoff** — the "waiting for partner" screen just shows a code. Could this be a shareable card / link that feels personal and inviting rather than a tech handoff?

3. **Events / trips view** — you can tag expenses to events (e.g. "🏖️ Sardinia"). There's now a list showing totals per event. What else would be useful here? A per-event breakdown? A photo / cover?

4. **Recurring expense management** — currently you can create recurring templates but there's no management screen. Where should it live? How do you pause or edit a recurring?

5. **Settle flow** — the soft settle is intentionally calm. Does it need more ceremony when you hit zero (a moment of delight)? Or stay quiet?

6. **Empty states** — new users see blank screens. What's the right tone and visual for each one?

7. **Budget beyond categories** — is per-category budgeting enough, or do couples want a single "this month we agreed to spend £X total" mode?

8. **Notifications** — we said no debt-reminders, but are there *good* notifications? ("Kate just added an expense" as a light shared-life moment rather than a nag?)

---

## Running the app

1. Open `pari/pari.xcodeproj` in Xcode 16+
2. In Target → Signing & Capabilities, add **Sign in with Apple** (one click)
3. Select your device, hit Run
4. The backend (Supabase) is live — no local setup needed
