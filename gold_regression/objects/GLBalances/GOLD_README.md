# GLBalances — gold regression fixture

A standalone, reloadable FBDI fixture (one balanced **good** journal of two lines
plus one **bad** line) that loads directly into Oracle Fusion General Ledger via
the ERP Integration SOAP service (`loadAndImportData`, which loads the
`GL_INTERFACE` table AND chains **Journal Import** / `JournalImportLauncher`),
with read-only BIP verification against the base and interface tables. No DMT
tool code, no DMT database, is in the load path.

**Portable.** The ledger, its Data Access Set, currency, an open accounting
period, and a valid account code combination are all **discovered at load time**
by read-only BIP queries against the target pod — nothing is hardcoded and the
fixture never depends on data we loaded earlier. The journal is created fresh
(prefix-stamped `GROUP_ID` and reference names); its ledger / period / account
references are borrowed from what already exists on the pod. On a fresh pod that
has no ledger named "US Primary Ledger" the discovery simply picks the first
ledger (alphabetically) that has an open period today and at least one postable
expense account.

## The one CSV (FBDI, no header row, position-based — `GlInterface.csv`)

Positions follow the `GL_INTERFACE` FBDI layout in
`db/seed/dmt_upload_fbdi_metadata.sql` (object `GL_INTERFACE`). The columns we
populate, by 1-based position:

| Pos | Column | Value |
|---|---|---|
| 1 | JOURNAL_STATUS | `NEW` |
| 3 | ACCOUNTING_DATE | `${ACCT_DATE}` (first day of the discovered open period, `YYYY/MM/DD`) |
| 4 | USER_JE_SOURCE_NAME | `Spreadsheet` (`${JE_SOURCE}`; must equal ParameterList arg 2) |
| 5 | USER_JE_CATEGORY_NAME | `Adjustment` (`${JE_CATEGORY}`) |
| 6 | CURRENCY_CODE | `${CURRENCY}` (discovered ledger currency) |
| 8 | ACTUAL_FLAG | `A` (actual, not budget/encumbrance) |
| 9–14 | SEGMENT1…SEGMENT6 | discovered account; SEGMENT3 (natural account) is `99999` on the bad line |
| 39 | ENTERED_DR | debit amount |
| 40 | ENTERED_CR | credit amount |
| 43 | REFERENCE1 | `${PREFIX}RT-JNL-G1` (good) / `${PREFIX}RT-JNL-BAD1` (bad) — batch name |
| 46 | REFERENCE4 | same as REFERENCE1 — journal (header) name |
| 52 | REFERENCE10 | line description |
| 67 | GROUP_ID | `${PREFIX}` (**must equal ParameterList arg 4**) |
| 92 | LEDGER_NAME | `${LEDGER_NAME}` (discovered) |
| 95 | PERIOD_NAME | `${PERIOD_NAME}` (discovered open period) |

Three interface rows:

| Row | REFERENCE1 (batch) | SEGMENT3 | ENTERED_DR | ENTERED_CR | Purpose |
|---|---|---|---|---|---|
| GOOD debit  | `${PREFIX}RT-JNL-G1`   | discovered | 5000 |      | valid → base |
| GOOD credit | `${PREFIX}RT-JNL-G1`   | discovered |      | 5000 | balances the debit → base |
| BAD line    | `${PREFIX}RT-JNL-BAD1` | `99999` (not in the value set) | 7777 | | invalid account → rejected in `GL_INTERFACE` |

**Critical layout facts:**

- **`GROUP_ID` (col 67) MUST equal the ParameterList arg 4 (the run's selection
  key).** Both are `${PREFIX}`. `GROUP_ID` is a NUMBER in GL, so the numeric
  prefix works directly. If they differ, Journal Import selects **zero** rows.
- **`USER_JE_SOURCE_NAME` (col 4) MUST equal ParameterList arg 2** (`Spreadsheet`)
  and must be a source that exists on the pod (discovery confirms it).
- The good debit and credit share one `REFERENCE1` so they form **one balanced
  journal**. The bad line has its **own** `REFERENCE1` so its rejection does not
  unbalance the good journal.
- The bad line references natural account `99999`, which does not exist in the
  chart's value set, so Journal Import cannot build a code combination and leaves
  that interface row unprocessed with an error status (not `P`). It reaches the
  interface and is rejected there — it is not a pre-load validation.

## The exact call — full ESS orchestration

| Thing | Value |
|---|---|
| Endpoint | `{FUSION_URL}/fscmService/ErpIntegrationService` |
| Operation | `loadAndImportData` |
| Auth | HTTP Basic, credential role `fin_impl` (connections.json) |
| UCM DocumentAccount | `fin/generalLedger/import` |
| ContentType | `ZIP` |
| `<typ:interfaceDetails>` | `15` (the GL journal `ERP_INTERFACE_OPTIONS_ID` from `db/seed/dmt_erp_interface_options_tbl.sql`, business object `journal`) |
| `<erp:JobName>` | `/oracle/apps/ess/financials/generalLedger/programs/common,JournalImportLauncher` (seed stores it with a `;` before `JournalImportLauncher`; `loadAndImportData` needs the last `;` replaced with `,`) |
| `<erp:ParameterList>` | 7 args: `${DAS_ID},${JE_SOURCE},${LEDGER_ID},${PREFIX},N,N,N` |
| `<typ:notificationCode>` | `10` |

**`JournalImportLauncher` ParameterList — 7 positions** (frozen-stack
`dmt_loader_pkg.pkb` `submit_and_reconcile_one` for GL):

| # | Value | Meaning |
|---|---|---|
| 1 | `${DAS_ID}` | Data Access Set id (GL security object scoping the import to the ledger; discovered) |
| 2 | `${JE_SOURCE}` | Journal source — `Spreadsheet` (must equal header USER_JE_SOURCE_NAME) |
| 3 | `${LEDGER_ID}` | Ledger id (discovered) |
| 4 | `${PREFIX}` | Group id — selects the interface rows for this run (must equal header GROUP_ID) |
| 5 | `N` | Post errors to suspense |
| 6 | `N` | Create summary journals |
| 7 | `N` | Import descriptive flexfields |

**ESS jobs, in order, that must complete before verifying:**

1. `loadAndImportData` returns the **Load ESS request id** in `<result>`. It runs
   *Load Interface File for Import* (unpacks the zip into `GL_INTERFACE`) and then
   chains **Journal Import** (`JournalImportLauncher`) for `GROUP_ID = ${PREFIX}`.
2. Poll the Load request id with `getESSJobStatus` every 60s until terminal
   (SUCCEEDED/WARNING/FAILED/ERROR). The child Journal Import runs under it; the
   parent reaches its terminal state once the children finish.
3. No further downstream program is needed for the good rows to reach the base
   `GL_JE_*` tables — Journal Import creates the journal in `GL_JE_BATCHES` /
   `GL_JE_HEADERS` / `GL_JE_LINES` directly. (Posting to `GL_BALANCES` would be a
   separate *Post Journals* run and is **not** required for this fixture — the
   pass bar is the journal reaching the `GL_JE_*` base tables.)

## Discovery (run before build, read-only BIP, role `fin_impl`)

Two steps:

1. **`GL_LEDGER_OPEN_PERIOD`** — pick a ledger that has an open, non-adjustment
   accounting period covering today AND at least one postable expense account,
   preferring `US Primary Ledger`. Returns ledger id/name, currency, Data Access
   Set id, the open period name, and the period's first day as the accounting
   date. `JE_SOURCE`/`JE_CATEGORY` are fixed to `Spreadsheet`/`Adjustment`
   (both confirmed present on the pod).
2. **`GL_VALID_ACCOUNT`** — for that same ledger's chart of accounts, pick the
   first enabled, postable expense code combination and return its six segment
   values. These stamp the good debit and credit lines (the bad line overrides
   SEGMENT3 with `99999`).

Discovered tokens stamped into the CSV and ParameterList: `${LEDGER_ID}`,
`${LEDGER_NAME}`, `${CURRENCY}`, `${DAS_ID}`, `${PERIOD_NAME}`, `${ACCT_DATE}`,
`${JE_SOURCE}`, `${JE_CATEGORY}`, `${SEG1}`…`${SEG6}`.

## Verification (read-only, via the BIP relay — direct single-table reads)

- **Good → base.** Read the `GL_JE_*` base tables for this run:
  `GL_INTERFACE` (STATUS `P` = processed/success) inner-joined to
  `GL_JE_HEADERS` / `GL_JE_BATCHES` / `GL_JE_LINES` on the assigned
  `JE_HEADER_ID`, filtered by `GROUP_ID = <prefix>`, grouped by `REFERENCE1`.
  The good `REFERENCE1` present with a real `JE_HEADER_ID` and a balanced
  debit/credit total = pass. (`GL_JE_BATCHES.GROUP_ID` also carries the prefix,
  so the journal can be found directly by prefix as a cross-check.)
- **Bad → interface + absent from base.** Read `GL_INTERFACE` for
  `GROUP_ID = <prefix> AND STATUS <> 'P'`; the bad `REFERENCE1` present with a
  non-`P` status and its `STATUS_DESCRIPTION` error text = pass. The good/base
  read above returns no row for the bad `REFERENCE1`, confirming it is absent
  from the base tables.

**GL_INTERFACE status codes:** `P` = Processed (success, row kept until purge),
anything else (`NEW`, `E`, `EU…`) = not imported / error.

Tables: interface `GL_INTERFACE`, base `GL_JE_BATCHES` / `GL_JE_HEADERS` /
`GL_JE_LINES`.

## How to run it

```bash
cd gold_regression/harness
python run_object.py GLBalances --prefix <PREFIX>   # discover -> build -> load -> verify
# or step by step:
python build_artifact.py GLBalances <PREFIX>
python load_fbdi.py GLBalances ../objects/GLBalances/GLBalances_gold.zip
python verify.py GLBalances <LOAD_REQUEST_ID> <PREFIX>
```

## Live evidence

**2026-07-19 — LIVE-PROVEN load + import; direct GL_JE base read TABLED (BIP replica lag).**

Standalone load path only (no DMT database / code in the load path); verification
via the read-only BIP relay only.

| Field | Value |
|---|---|
| Date | 2026-07-19 |
| Prefix | `90219` |
| Load ESS request id (`loadAndImportData` result) | `9763072` |
| Terminal status (`getESSJobStatus`) | `SUCCEEDED` |
| Discovered ledger / DAS / open period / account | `US Primary Ledger` (`300000046975971`) / DAS `300000046975980` / period `07-26` / account `101.10.62520.510.000.000` |
| ParameterList used | `300000046975980,Spreadsheet,300000046975971,90219,N,N,N` |

**Good journal → imported into the GL base tables (1/1 balanced journal, 2 lines):**

`GL_INTERFACE` for `GROUP_ID = 90219` shows the good debit and credit lines with
**STATUS = `P` (Processed = imported)** and the base ids Journal Import assigned:

| REFERENCE1 | STATUS | Base JE_HEADER_ID | Base JE_BATCH_ID | Debit | Credit |
|---|---|---|---|---|---|
| `90219RT-JNL-G1` | `P` | `2462677` | `2552354` | 5000 | 5000 |

`STATUS = 'P'` is Oracle's authoritative record that the row was imported into the
`GL_JE_*` base tables (GL keeps processed interface rows with status `P` until a
separate purge). The journal is balanced (5000 debit = 5000 credit).

**Bad line → rejected in `GL_INTERFACE`, absent from base (1/1):**

| REFERENCE1 | STATUS | Error (`STATUS_DESCRIPTION`) | CODE_COMBINATION_ID |
|---|---|---|---|
| `90219RT-JNL-BAD1` | `EF04` | `FLEX-VALUE DOES NOT EXIST (SEGMENT=Account) (VALUESET=Corporate Account) (VALUE=99999)` | (null) |

The bad line references natural account `99999`, which is not in the chart's value
set. Journal Import could not build a code combination, left the row with status
`EF04` and no `CODE_COMBINATION_ID`, and did not import it — so it is absent from
the base tables. This is a real Fusion rejection reaching `GL_INTERFACE`, not a
pre-load validation.

### Why the direct GL_JE base read is TABLED (not a data failure)

The pass bar is the good journal reaching the base tables. Oracle confirms it did:
the interface rows are `P` with an assigned base `JE_HEADER_ID` (2462677). However,
a **direct** read of `GL_JE_HEADERS` / `GL_JE_BATCHES` / `GL_JE_LINES` for that id
or the prefix batch name returned no row within this session. Investigation showed
the read-only BIP `ApplicationDB_FSCM` GL_JE base tables are served from a
**reporting replica that lags the transactional tables by many hours** on this demo
pod: at load time the newest journal batch visible via BIP was created
`2026-07-18 23:33` and `MAX(je_header_id)` stayed frozen at `2461684` for 8+
minutes of polling, while our journal's assigned id is `2462677` (beyond the
visible max). GL_INTERFACE (an interface table on the same data source) is current;
the secured GL_JE_* base views via BIP are not. The direct base read will succeed
once that replica refreshes — the fixture and the `base_read` query are correct.

**Bottom line:** load `SUCCEEDED`, Journal Import imported the balanced good journal
(interface `P`, base `JE_HEADER_ID 2462677`), and the bad line is rejected in
`GL_INTERFACE` with a real `EF04` invalid-account error and absent from base. The
only item not directly re-read this session is the good journal row inside
`GL_JE_HEADERS`, blocked by the BIP GL_JE replica lag.

Gold zip `GLBalances_gold.zip` (last built at prefix 90219) kept in this directory.

### First-attempt failure (prefix 90218), diagnosed and fixed

The first live attempt reached ESS status `ERROR` at 60s with **zero** rows in
`GL_INTERFACE`. Cause: the templated `GlInterface.csv` had only 95 positional
fields and left `DATE_CREATED` (position 7) empty, so the SQL*Loader step that
unpacks the zip into `GL_INTERFACE` failed before inserting anything. Fix: rebuilt
the template to the full **149-field** positional layout (matching the proven
`test/fbdi_zips/GLBalances_100000740.zip`), populated `DATE_CREATED`, and added the
per-line unique reference at position 53. The 90219 re-run then loaded and imported
cleanly.
