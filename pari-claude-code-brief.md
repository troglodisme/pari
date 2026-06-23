# Pari — Claude Code Build Brief

> Paste this file into the repo root as `BRIEF.md` (and copy the "Working agreement" section into `CLAUDE.md`). Then run the milestones in order. Each milestone is a self-contained prompt you can hand to Claude Code.

---

## 0. What we're building

**Pari** is an iOS app for **couples** to share life costs and budget together, without the cold "who-owes-who" ledger feeling that makes couples abandon Splitwise.

The name is Italian: *siamo pari* = "we're even." That's the whole emotional promise. The app's job is to keep two people feeling *square and relaxed about money*, not to invoice each other.

### Product principles (these override any feature when they conflict)

1. **Fairness, not debt.** The home screen shows one soft, glanceable state — "You're even" / "Kate's €30 ahead this month" — never a list of itemised IOUs. We track a running balance but present it gently.
2. **Two people, not a group graph.** The data model is a *household of 2*. No n-person debt simplification, no "who owns what" itemisation. Optimise hard for the couple case; groups are explicitly out of scope for v1.
3. **Auto-split by default.** Every expense splits automatically per the household rule (50/50 or income-proportional). Changing the split is a deliberate, one-tap exception — not the default workflow.
4. **Free where Splitwise charges.** Unlimited expenses (no daily limit), receipt photos, multi-currency, and CSV export are all free. No ads. These are the explicit anti-Splitwise wedges.
5. **Minimal, warm, a little cute.** Calm and friendly, not fintech-severe. Precision in spacing and type over decoration.

### Out of scope for v1 (do NOT build yet)

- Groups larger than 2 / multi-household.
- Bank or card connections / open banking imports.
- Web and React Native clients (the backend is built so these can come later — see §3).
- Push-notification "debt collector" reminders (we do *soft* settle only).

---

## 1. Platform & stack

- **iOS 17+**, **SwiftUI**, Swift 5.9+. Use `@Observable` (Observation framework), `NavigationStack`, Swift Concurrency (`async/await`).
- **Backend: Supabase** (Postgres + Auth + Storage + RLS). Use the official `supabase-swift` SDK via Swift Package Manager.
- **Auth: Sign in with Apple** only for v1 (clean, no password UI, fits the audience).
- **Native extras (later milestones):** WidgetKit home/lock-screen widget showing the balance; App Intents for "Add expense to Pari" via Siri/Shortcuts.
- **Architecture:** lightweight MVVM. Views ← `@Observable` view models ← a thin `PariClient` wrapping Supabase calls. No heavyweight architecture; keep it legible.

> **Why Supabase over CloudKit:** one backend serves the future web (Next.js) and React Native clients with one auth model and one set of RLS policies. CloudKit's web story (CloudKit JS) is Apple-ID-gated and would lock the product to Apple forever. We already run Supabase in production elsewhere, so RLS is familiar ground.

> **Create a NEW Supabase project for Pari.** Do not reuse or touch the existing `ambient` / `ambient-supabase` project. Pari is fully separate.

---

## 2. Data model (Supabase / Postgres)

Apply as a migration. Balance is **derived**, never stored. Currency stored in **minor units (integer cents)** to avoid float drift.

```sql
-- Households: a couple. Exactly 1-2 members in practice.
create table households (
  id            uuid primary key default gen_random_uuid(),
  name          text not null default 'Us',
  base_currency text not null default 'EUR',          -- ISO 4217
  split_mode    text not null default 'equal'         -- 'equal' | 'proportional'
                check (split_mode in ('equal','proportional')),
  invite_code   text unique,                          -- short code partner enters to join
  created_at    timestamptz not null default now()
);

-- Members: link auth.users to a household, with display info and income share.
create table members (
  id           uuid primary key default gen_random_uuid(),
  household_id uuid not null references households(id) on delete cascade,
  user_id      uuid not null references auth.users(id) on delete cascade,
  display_name text not null,
  avatar_emoji text default '🙂',
  income_share numeric not null default 50,           -- % used when split_mode='proportional'
  created_at   timestamptz not null default now(),
  unique (household_id, user_id)
);

-- Categories: per-household, with an optional monthly budget. Seed defaults on household create.
create table categories (
  id            uuid primary key default gen_random_uuid(),
  household_id  uuid not null references households(id) on delete cascade,
  name          text not null,
  icon          text not null default '🧾',           -- emoji for v1 (cheap, cute)
  color_hex     text not null default '#8AB6A6',
  monthly_budget integer,                              -- minor units; null = no budget
  sort_order    integer not null default 0
);

-- Expenses: the core ledger. split_type drives how it affects the balance.
create table expenses (
  id           uuid primary key default gen_random_uuid(),
  household_id uuid not null references households(id) on delete cascade,
  payer_id     uuid not null references members(id),
  amount       integer not null,                       -- minor units, always > 0
  currency     text not null default 'EUR',
  category_id  uuid references categories(id) on delete set null,
  description  text,
  spent_on     date not null default current_date,
  split_type   text not null default 'default'        -- 'default' inherits household split_mode
               check (split_type in ('default','equal','proportional','custom','treat')),
  -- For 'custom': {"<member_id>": <minor_units_owed>, ...} summing to amount.
  custom_split jsonb,
  is_treat     boolean not null default false,         -- gift: payer absorbs, excluded from balance
  receipt_path text,                                   -- Supabase Storage path
  created_by   uuid not null references members(id),
  created_at   timestamptz not null default now()
);

-- Recurring templates: auto-post on a cadence (rent, utilities, nursery).
create table recurring_expenses (
  id           uuid primary key default gen_random_uuid(),
  household_id uuid not null references households(id) on delete cascade,
  payer_id     uuid not null references members(id),
  amount       integer not null,
  currency     text not null default 'EUR',
  category_id  uuid references categories(id) on delete set null,
  description  text,
  cadence      text not null default 'monthly'         -- 'monthly' for v1
               check (cadence in ('monthly')),
  day_of_month integer not null default 1,
  next_run     date not null,
  active       boolean not null default true
);

-- Soft settlements: a recorded "we squared up", optional.
create table settlements (
  id           uuid primary key default gen_random_uuid(),
  household_id uuid not null references households(id) on delete cascade,
  from_member  uuid not null references members(id),
  to_member    uuid not null references members(id),
  amount       integer not null,
  settled_on   date not null default current_date,
  note         text
);

-- Shared savings goals (couple-emotional hook, ties into budgeting).
create table goals (
  id           uuid primary key default gen_random_uuid(),
  household_id uuid not null references households(id) on delete cascade,
  name         text not null,
  target_amount integer not null,
  saved_amount  integer not null default 0,
  target_date  date,
  created_at   timestamptz not null default now()
);
```

### Balance logic (derive in SQL view or client)

For each non-treat expense, each member's *share* is computed from `split_type` (falling back to `households.split_mode` when `'default'`). A member's **net** = (sum they paid) − (sum of their shares) − (settlements they received) + (settlements they paid). With two members, the household balance is a single signed number. **Treats (`is_treat=true`) are excluded entirely** — the payer simply absorbs them.

Build a `member_balances` view for convenience, but the client should also be able to compute it so the widget can render offline-ish.

### RLS (apply to every table)

Enable RLS on all tables. Core policy: a user may read/write a row only if they are a member of that `household_id`.

```sql
alter table expenses enable row level security;
create policy "members read own household expenses"
  on expenses for select
  using (household_id in (select household_id from members where user_id = auth.uid()));
create policy "members write own household expenses"
  on expenses for insert with check (
    household_id in (select household_id from members where user_id = auth.uid()));
-- ...repeat the same pattern for update/delete and for every other table.
-- households: readable/updatable by its members; insertable by the authenticated creator.
-- members: a user can insert their own membership when they hold a valid invite_code.
```

> Test RLS deliberately: sign in as two different test users and confirm neither can read the other's solo data, and both can read the shared household once joined. (You've hit RLS violations in production before — write the policy tests up front this time.)

---

## 3. Future-proofing for web / RN (build now, use later)

- Keep **all business logic** (split math, balance computation, currency formatting) in plain Swift types with **no SwiftUI imports**, in a `PariCore` module, so the rules are documented and portable. The eventual Next.js/RN clients reimplement the same spec against the same tables.
- Treat the **Postgres schema + RLS as the source of truth**. No business rules that live only in the iOS app and can't be enforced at the DB layer.

---

## 4. Core flows (v1)

1. **Onboarding & pairing.** Sign in with Apple → create a household (auto-generates a short `invite_code`) OR enter a partner's code to join. Pick display name + avatar emoji. Set split mode (50/50 default; or proportional with two income-share %s).
2. **Add expense.** Amount keypad → category → who paid (defaults to you) → date (defaults today). Split is **automatic**; a single "Split: 50/50" chip opens options (equal / proportional / custom / **My treat**). Optional receipt photo and note. Saving feels instant (optimistic UI).
3. **Home / the glance.** One calm card: the current balance state in plain language, this-month total, and a short recent-activity list. This is the screen people open daily — it must feel good and load fast.
4. **Budget.** Per-category monthly budgets with simple progress (spent / budget). A month summary. No charts-heavy dashboard for v1 — keep it glanceable.
5. **Goals.** Create a shared goal, add to it, see progress.
6. **Soft settle.** A gentle "Square up?" that records a settlement and resets the balance to even. No nagging, no reminders.
7. **Export.** CSV of expenses for a date range (free).

---

## 5. Design direction

Audience: couples who live together and find money admin slightly awkward. The feeling to hit is *calm, warm, a bit playful* — the opposite of a banking app. Spend the boldness on the **balance "glance" card**; keep everything else quiet.

**Palette (starting point — iterate in code):**
- `--sage` `#8AB6A6` (primary / "even" state — calm green)
- `--clay` `#E0A47C` (warm accent / "ahead" highlight)
- `--ink` `#2E2A26` (text)
- `--paper` `#FBF8F3` (background, warm off-white)
- `--mist` `#EDE7DD` (cards / dividers)

**Type:** a friendly, slightly characterful rounded or humanist sans for display (the balance number is the hero — set it large and confident), a clean neutral sans for body, system mono only for amounts if it helps alignment. Avoid the default "high-contrast serif on cream + terracotta" AI look — warmth here comes from roundness and softness, not editorial serifs.

**Signature element:** the **balance glance** — a single soft card whose colour and copy shift with state (even → sage and restful; someone ahead → a gentle clay tint). It should read as a *mood*, not a number on a spreadsheet. This is the one thing Pari is remembered by; everything else stays disciplined.

**Copy voice:** plain, kind, sentence case. "You're even." "Kate covered more this month — want to square up?" Never "Outstanding balance: €30.00 owed." Errors are direct and unfussy; empty states invite the first action ("Add your first shared cost").

Quality floor: full dark mode, Dynamic Type, VoiceOver labels on the balance and amounts, reduced-motion respected.

---

## 6. Build milestones (run in order)

Hand these to Claude Code one at a time. Each ends in something runnable.

**M0 — Scaffold.** Create the Xcode SwiftUI project (`Pari`, iOS 17, bundle id `io.ambientworks.pari` or your choice). Add `supabase-swift` via SPM. Set up a `PariCore` module for pure logic and a `PariClient` for Supabase. Add a `Secrets` config (gitignored) for the Supabase URL + anon key. Commit.

**M1 — Backend.** Using the Supabase MCP connection, create the Pari project's schema from §2 as a migration, enable RLS with the §2 policies, seed default categories, and create the `member_balances` view. Add RLS tests with two users.

**M2 — Auth & pairing.** Sign in with Apple → Supabase auth. Create-household and join-by-code flows. Member profile (name, emoji, income share). Persist session.

**M3 — Expenses & auto-split.** Add/edit/delete expense with the keypad-first flow. Implement split logic in `PariCore` (default/equal/proportional/custom/treat). Receipt upload to Supabase Storage. Category picker.

**M4 — The glance.** Home screen balance card with state-driven colour + copy, month total, recent activity. Wire the derived balance from `PariCore`.

**M5 — Budget & goals.** Per-category monthly budgets with progress; month summary; shared goals CRUD + progress.

**M6 — Recurring & soft settle.** Recurring monthly templates (post via a scheduled Supabase Edge Function or on-open catch-up). Soft "square up" recording a settlement.

**M7 — Native polish.** WidgetKit widget (balance glance on home/lock screen). App Intent: "Add expense to Pari." Dark mode + accessibility pass. CSV export.

---

## 7. Working agreement (copy into CLAUDE.md)

- This is a **couples** app of exactly two people. If a feature only makes sense for groups, push back before building it.
- **Money is integer minor units** everywhere. Never store or compute amounts as floats.
- **All split/balance math lives in `PariCore`** with no UI imports, and must match the spec in BRIEF.md §2.
- **RLS is mandatory** on every table; never rely on client-side filtering for access control. Don't point the Supabase MCP at any project other than Pari's, and keep it `read_only` unless a migration is being applied.
- Prefer **optimistic, instant-feeling UI**; the home glance must load fast.
- Keep dependencies minimal. No analytics SDKs, no ad SDKs, ever.
- Ask before adding anything from the §0 "out of scope" list.
