# GLBalances — v2 seeded gold fixture

Converted from the frozen v1 fixture (`../../objects/GLBalances/`). Same one balanced good
journal (two lines) plus one bad line, loaded via `loadAndImportData` (which chains
**Journal Import** / `JournalImportLauncher`) with read-only BIP verification. The one
difference from v1: the ledger, its Data Access Set, currency, journal source, category and
the account code combination are **hard-coded to standard seeded values**, not discovered.

## The hard-coded seeds (what v1 discovered → now literals)

All confirmed live via read-only BIP on this pod, all standard seeded demo data we never
loaded (no prefix):

| Reference | Literal value | Where used |
|---|---|---|
| Ledger name | `US Primary Ledger` | CSV col 92 (`LEDGER_NAME`) |
| Ledger id | `300000046975971` | ParameterList arg 3 |
| Data Access Set id | `300000046975980` | ParameterList arg 1 |
| Currency | `USD` | CSV col 6 (`CURRENCY_CODE`) |
| Journal source | `Spreadsheet` | CSV col 4 + ParameterList arg 2 (must match) |
| Journal category | `Adjustment` | CSV col 5 |
| Account code combination | `101.10.62520.510.000.000` (CCID 10196, enabled, expense) | CSV cols 9–14 (SEGMENT1–6) |

The discovery block is removed from `recipe.json`. The 7-arg `JournalImportLauncher`
ParameterList is now `300000046975980,Spreadsheet,300000046975971,${PREFIX},N,N,N`.

## What still carries `${PREFIX}` (unchanged from v1)

- Batch / journal reference name — `${PREFIX}RT-JNL-G1` (good), `${PREFIX}RT-JNL-BAD1` (bad),
  in REFERENCE1 (col 43).
- `GROUP_ID` (col 67) — `${PREFIX}`. **Must equal ParameterList arg 4**, or Journal Import
  selects zero rows. `GROUP_ID` is a NUMBER in GL, so the numeric prefix works directly.
- Per-line unique reference `${PREFIX}-1/-2/-3` (col 53).

## How the OPEN accounting period is handled (no hard-coded period)

A hard-coded period name would break the moment that period closes, so the period is **not**
hard-coded and **no open-period lookup is used**. Instead both date fields are derived from
today, so every re-run always lands in the period that is open now:

- `ACCOUNTING_DATE` (col 3) and `DATE_CREATED` (col 7) = `${GL_DATE_SLASH}` — today's date
  `YYYY/MM/DD` (existing harness derived token).
- `PERIOD_NAME` (col 95) = `${GL_PERIOD}` — a small **additive** token added to
  `harness/build_artifact.py:derived_tokens()`. It is today's date formatted `MM-YY`, which
  is exactly this demo pod's GL calendar period-naming convention (confirmed live: today
  `2026-07-20` → period `07-26`, which `gl_period_statuses` reports OPEN for
  `US Primary Ledger`). Because it is computed from `date.today()` on every run, it always
  names the current, open period — no lookup, no stale literal.

This satisfies the rule "use the harness's derived date token or a today-based period so
re-runs always land in an open period." Only the DATE fields are derived; every FK-style
reference (ledger, DAS, currency, source, category, account) is a hard-coded seed.

## Bad row

BAD-1 sets natural account SEGMENT3 = `99999`, which is not in the chart's value set. Journal
Import cannot build a code combination, leaves the interface row unprocessed with status
`EF04` and error `FLEX-VALUE DOES NOT EXIST`, and never imports it — so it is absent from the
base tables. It has its own REFERENCE1 so its rejection does not unbalance the good journal.

## Verification — base proof is GL_INTERFACE STATUS='P'

The pass bar is the good journal reaching the GL base tables. On this demo pod the read-only
BIP `ApplicationDB_FSCM` GL_JE_* replica lags the transactional tables by many hours, so a
direct `GL_JE_HEADERS` read of a just-created journal returns no row. The authoritative,
immediately-current proof is the interface side: `GL_INTERFACE` for this `GROUP_ID` with
`STATUS = 'P'` (Processed) carries the base `JE_HEADER_ID` that Journal Import assigned when
it wrote the journal into `GL_JE_BATCHES/HEADERS/LINES`. That is the recipe's `base_read`.
The bad row is proven by `GL_INTERFACE` `STATUS <> 'P'` with real error text, and by being
absent from the `STATUS='P'` base read.

## Live evidence (v2, via `GOLD_OBJECTS_SUBDIR=objects_seeded`)

**2026-07-20 — LIVE-PROVEN on first run. PASS.**

Standalone load path only (no DMT database / code in the load path); verification via the
read-only BIP relay only.

| Field | Value |
|---|---|
| Prefix | `90654` |
| Hard-coded ledger / DAS / currency / account | `US Primary Ledger` (`300000046975971`) / `300000046975980` / `USD` / `101.10.62520.510.000.000` |
| Derived open period | `07-26` (from today `2026/07/20`) |
| ParameterList used | `300000046975980,Spreadsheet,300000046975971,90654,N,N,N` |
| Load ESS request id | `9766183` |
| Terminal status | `SUCCEEDED` |
| Credential role | `fin_impl` |

Good journal → imported into GL base tables (1/1 balanced, 2 lines), via `GL_INTERFACE`
STATUS='P' with assigned base id:

| REFERENCE1 | STATUS | Base JE_HEADER_ID | Debit | Credit |
|---|---|---|---|---|
| `90654RT-JNL-G1` | `P` | `2461689` | 5000 | 5000 |

Bad line → rejected in `GL_INTERFACE`, absent from base (1/1):

| REFERENCE1 | STATUS | Error |
|---|---|---|
| `90654RT-JNL-BAD1` | `EF04` | `FLEX-VALUE DOES NOT EXIST (SEGMENT=Account) (VALUESET=Corporate Account) (VALUE=99999)` |

## How to run

```bash
cd gold_regression/harness
GOLD_OBJECTS_SUBDIR=objects_seeded python run_object.py GLBalances
```
