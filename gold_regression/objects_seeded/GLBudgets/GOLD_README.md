# GLBudgets — v2 seeded gold fixture

Converted from the frozen v1 fixture (`../../objects/GLBudgets/`). Same 4 good +
1 bad GL budget-balance rows, loaded via the two-step GL Budgets path
(`loadAndImportData` into `GL_BUDGET_INTERFACE`, then one standalone
`ValidateAndLoadBudgets` ESS submission per distinct Run Name), with read-only
BIP verification against the budget base cube and the budget interface table. No
DMT database and no DMT pipeline code are in the load path.

The one difference from v1: the ledger, budget name, currency, and account code
combinations are **hard-coded to standard seeded values** instead of discovered
at load time. The accounting period is the single exception — see below.

## The hard-coded seeds (what v1 discovered → now literals)

v1 discovered "the most-populated USD budget combo in `GL_BUDGET_BALANCES`" plus
four real accounts under it. On this demo pod that resolved to the values below,
all of which are **standard seeded demo data we never loaded** (none carries an
`RT`/prefix). Confirmed present and prefix-free via read-only BIP before writing:

| Reference | Literal value |
|---|---|
| Ledger name | `US Primary Ledger` |
| Ledger id | `300000046975971` |
| Budget name (Accounting Scenario) | `Budget` |
| Currency | `USD` |
| Account segments 1/2 and 4/5/6 | `101` / `10` and `000`/`000`/`000` |
| Four natural accounts (segment 3) | `11102`, `11200`, `12101`, `12310` |
| Four concat accounts (good rows) | `101-10-{11102,11200,12101,12310}-000-000-000` |

These are written as literals directly into `artifact/GlBudgetInterface.csv` and
into the verify base read in `recipe.json`. The v1 `GL_BUDGET_REF` discovery
block is deleted.

`${PREFIX}` stays exactly as in v1 on the two Run Names (`${PREFIX}RT-GLBUD-G`
for the four good rows, `${PREFIX}RT-GLBUD-B` for the bad row) and inside the bad
budget name, so the fixture reloads on a fresh prefix without colliding.

## Open-period handling (the one lookup kept, and why)

The accounting period cannot be hard-coded: a fixed period (v1 resolved `07-26`)
**closes** at month end, after which the load would reject with a closed-period
error and every future re-run would fail. Budget cells must land in an **open**
period.

Because "which period is open" changes over time and is not derivable from the
prefix, this object keeps **one minimal discovery step**, `GL_OPEN_PERIOD`, that
returns only `${PERIOD_NAME}`. It queries `GL_PERIOD_STATUSES` for the hard-coded
ledger (`300000046975971`, application 101 = GL) and prefers the open period that
**contains today**, falling back to the most-recent open period if none contains
today. Everything else on this object is a hard-coded literal; this is the only
value read at load time, and it is documented here as the unavoidable minimal
lookup the seeded model allows for a date that must stay valid.

The period token flows into the CSV rows and into the verify base read, so the
read is scoped to exactly the period the rows were loaded into.

## The two-step ESS orchestration (unchanged from v1)

1. `loadAndImportData` (endpoint `{FUSION_URL}/fscmService/ErpIntegrationService`,
   UCM account `fin/budgetBalance/import`, `interfaceDetails` 17, ParameterList
   `#NULL`) loads the CSV into `GL_BUDGET_INTERFACE`. Its chained
   `ValidateAndLoadBudgets` gets no Run Name and errors harmlessly in ~1s.
2. `submitESSJobRequest` for `ValidateAndLoadBudgets` with the single argument
   `${PREFIX}RT-GLBUD-G` — validates and loads the four good rows into the cube
   (expected SUCCEEDED).
3. `submitESSJobRequest` for `ValidateAndLoadBudgets` with `${PREFIX}RT-GLBUD-B`
   — the bad Run Name, whose budget name `RT NONEXISTENT BUDGET ${PREFIX}` is not
   a valid Accounting Scenario, so it fails at validation (expected ERROR) and
   its row stays in `GL_BUDGET_INTERFACE` with a reportable error.

## Verification (read-only, via the BIP relay)

- **Good → base cube `GL_BUDGET_BALANCES` (4/4).** Direct read scoped to the
  hard-coded ledger/budget/currency, the discovered open period, and the four
  hard-coded concat accounts, requiring `PERIOD_NET_DR = 1000` and
  `LAST_UPDATE_DATE` within the last 4 hours (this run). Each account present =
  pass. (The 4-hour window scopes the read to this run and excludes months-old
  pre-existing cells for the same accounts, since budget cells carry no
  prefix-bearing key.)
- **Bad → interface, absent from base.** Direct read of `GL_BUDGET_INTERFACE` by
  the bad Run Name; the row is present with a reportable error
  (`You must specify a valid budget name.`) and never reaches the cube.

## How to run it

```bash
cd gold_regression
GOLD_OBJECTS_SUBDIR=objects_seeded python harness/run_object.py GLBudgets
```

## Live evidence (v2, via `GOLD_OBJECTS_SUBDIR=objects_seeded`)

**2026-07-20 — LIVE-PROVEN. PASS.**

Standalone load path only (no DMT database / code in the load path);
verification via the read-only BIP relay only.

| Field | Value |
|---|---|
| Date | 2026-07-20 |
| Prefix (kept in the gold zip) | `68853` |
| Load ESS request id (`loadAndImportData`) | `9766179` |
| Load terminal status | `SUCCEEDED` |
| `ValidateAndLoadBudgets` GOOD Run Name req | `9766211` → `SUCCEEDED` |
| `ValidateAndLoadBudgets` BAD Run Name req | `9766217` → `ERROR` |
| Seeded ledger / budget / currency | `US Primary Ledger` (`300000046975971`) / `Budget` / `USD` |
| Open period used (looked up) | `07-26` (contains today) |
| Accounts (good rows) | `101-10-{11102,11200,12101,12310}-000-000-000` |

**Good rows → base cube `GL_BUDGET_BALANCES` (4/4)** — each account present with
`PERIOD_NET_DR = 1000`, `LAST_UPDATE_DATE = 2026-07-20 04:25:09` (this run):

| CONCAT_ACCOUNT | PERIOD_NET_DR |
|---|---|
| `101-10-11102-000-000-000` | 1000 |
| `101-10-11200-000-000-000` | 1000 |
| `101-10-12101-000-000-000` | 1000 |
| `101-10-12310-000-000-000` | 1000 |

**Bad row → interface, absent from base (1/1):**

| RUN_NAME | Error |
|---|---|
| `68853RT-GLBUD-B` | `You must specify a valid budget name.` (`GL_BUDGET_INTERFACE`) |
