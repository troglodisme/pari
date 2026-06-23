# Pari — Web/Debug Reference

Supabase project: `mldfxdaevtdbltlwhvld` (eu-north-1)  
URL: `https://mldfxdaevtdbltlwhvld.supabase.co`

---

## Auth

Email + password via Supabase Auth. Email confirmation is **disabled** (toggle in Dashboard → Auth → Providers → Email).

```js
const { data, error } = await supabase.auth.signUp({ email, password })
const { data, error } = await supabase.auth.signInWithPassword({ email, password })
```

Every request automatically carries the user's JWT. All RLS policies use `auth.uid()` to identify the caller.

---

## Schema

### `households`
| column | type | notes |
|---|---|---|
| id | uuid | PK, gen_random_uuid() |
| name | text | |
| base_currency | text | e.g. "EUR" |
| split_mode | text | "equal" or "proportional" |
| invite_code | text | 6-char alphanumeric, unique |
| created_at | timestamptz | |

### `members`
| column | type | notes |
|---|---|---|
| id | uuid | PK |
| household_id | uuid | FK → households |
| user_id | uuid | FK → auth.users |
| display_name | text | |
| avatar_emoji | text | |
| income_share | int | 0–100, used when split_mode = proportional |
| created_at | timestamptz | |

### `categories`
| column | type | notes |
|---|---|---|
| id | uuid | PK |
| household_id | uuid | FK → households |
| name | text | |
| icon | text | emoji |
| color_hex | text | |
| monthly_budget | int | nullable, minor units (cents) |
| sort_order | int | |

### `expenses`
| column | type | notes |
|---|---|---|
| id | uuid | PK |
| household_id | uuid | FK → households |
| payer_id | uuid | FK → members.id (who paid) |
| amount | int | **minor units (cents), never floats** |
| currency | text | e.g. "EUR" |
| category_id | uuid | nullable, FK → categories |
| description | text | nullable |
| spent_on | date | "YYYY-MM-DD" |
| split_type | text | "default", "equal", "proportional", "custom", "treat" |
| custom_split | jsonb | nullable, `{ "<member_id>": <cents> }` |
| is_treat | bool | payer covers it all, excluded from balance |
| receipt_path | text | nullable |
| created_by | uuid | FK → members.id |
| created_at | timestamptz | |

### `settlements`
| column | type | notes |
|---|---|---|
| id | uuid | PK |
| household_id | uuid | FK → households |
| from_member | uuid | FK → members.id (who pays) |
| to_member | uuid | FK → members.id (who receives) |
| amount | int | minor units |
| settled_on | date | defaults to CURRENT_DATE |
| note | text | nullable |

### `goals`
| column | type | notes |
|---|---|---|
| id | uuid | PK |
| household_id | uuid | FK → households |
| name | text | |
| target_amount | int | minor units |
| saved_amount | int | minor units |
| target_date | date | nullable, "YYYY-MM-DD" |
| created_at | timestamptz | |

---

## RLS

Every table has RLS enabled. All policies use a single `SECURITY DEFINER` helper:

```sql
-- reads members bypassing RLS, so it can't recurse
get_my_household_id() → uuid
```

A user can read/write any row whose `household_id` matches the one returned by this function. This means:
- You must have a row in `members` before you can read anything else.
- The household and member must be created before doing any other queries.

**Policies on `members` itself** use the same function (no recursion because `SECURITY DEFINER` bypasses RLS when querying the table).

---

## Helper functions (RPC)

```sql
-- Seeds 8 default categories for a new household
create_default_categories(p_household_id uuid) → void

-- Looks up a household by its invite code (bypasses RLS, safe for unauthenticated-ish join flow)
find_household_by_invite_code(p_code text) → uuid
```

Call via PostgREST:
```js
await supabase.rpc('find_household_by_invite_code', { p_code: 'ABC123' })
await supabase.rpc('create_default_categories', { p_household_id: '...' })
```

---

## Typical flow

```
1. signUp / signInWithPassword
2. INSERT into households (no .select() — member doesn't exist yet, RLS blocks RETURNING)
3. INSERT into members (same — no .select())
4. SELECT household + member (now committed, RLS passes)
5. rpc('create_default_categories', ...)
6. App is ready: load expenses, settlements, categories, goals
```

**Partner join:**
```
1. signUp / signInWithPassword
2. rpc('find_household_by_invite_code', { p_code }) → household_id
3. INSERT into members (no .select())
4. SELECT household + member
```

---

## Balance logic

The balance is computed client-side (not in SQL) from raw expenses + settlements:

```
for each non-treat expense:
  shares = split(expense.amount, expense.split_type, household.split_mode)
  net[payer] += expense.amount - shares[payer]   // payer covered more than their share
  net[other] -= shares[other]                     // other owes their share

for each settlement:
  net[from_member] += settlement.amount   // from_member paid down their debt
  net[to_member]   -= settlement.amount
```

`balance > 0` → you are owed money  
`balance < 0` → you owe money  
`balance = 0` → pari (even)

Split types:
- `equal` → 50/50 (odd cent goes to payer)
- `proportional` → weighted by `income_share`
- `custom` → per `custom_split` jsonb field
- `treat` → excluded from balance entirely
- `default` → uses household's `split_mode`

---

## Money rule

**All amounts are integers in minor units (cents).** Never store or compute with floats. Display only: divide by 100 using `Decimal` or integer arithmetic, never `Float`/`Double`.

```js
// display
const euros = (cents / 100).toFixed(2)  // "12.50"

// parse input
const cents = Math.round(parseFloat(input) * 100)
```
