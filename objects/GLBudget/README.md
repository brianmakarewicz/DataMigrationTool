# GLBudget FBDI Template Analysis

## Source

- **XLSM template:** Downloaded from Oracle technetwork (24D release):
  `https://www.oracle.com/webfolder/technetwork/docs/fbdi-24d/fbdi/xlsm/GeneralLedgerBudgetBalanceImportTemplate.xlsm`
- **CTL file name (per XLSM instructions):** `glbudgetimport.ctl`
- **Interface table:** `GL_BUDGET_INTERFACE`
- **ESS process:** Load Interface File for Import -> General Ledger Validate and Upload Budgets

## FBDI CSV Column Order (from XLSM template)

The XLSM template defines **38 user-supplied data columns** (excluding the "End of CSV" marker).
The CTL file adds server-side expression/constant columns (CREATION_DATE, CREATED_BY, etc.)
that are NOT present in the CSV.

| Pos | Column (Excel Header) | CTL Column Name | Notes |
|-----|----------------------|-----------------|-------|
| 1   | Run Name             | RUN_NAME        | Required. Identifies the budget data set. |
| 2   | Status               | STATUS          | Required. Set to "NEW" for new data. |
| 3   | Ledger Id            | LEDGER_ID       | Required (or LEDGER_NAME). Numeric. |
| 4   | Budget Name          | BUDGET_NAME     | Required. From Accounting Scenario value set. |
| 5   | Period               | PERIOD_NAME     | Required. GL period name. |
| 6   | Currency             | CURRENCY_CODE   | Required. |
| 7   | Segment1             | SEGMENT1        | Chart of accounts segment values |
| 8   | Segment2             | SEGMENT2        | |
| 9   | Segment3             | SEGMENT3        | |
| 10  | Segment4             | SEGMENT4        | |
| 11  | Segment5             | SEGMENT5        | |
| 12  | Segment6             | SEGMENT6        | |
| 13  | Segment7             | SEGMENT7        | |
| 14  | Segment8             | SEGMENT8        | |
| 15  | Segment9             | SEGMENT9        | |
| 16  | Segment10            | SEGMENT10       | |
| 17  | Segment11            | SEGMENT11       | |
| 18  | Segment12            | SEGMENT12       | |
| 19  | Segment13            | SEGMENT13       | |
| 20  | Segment14            | SEGMENT14       | |
| 21  | Segment15            | SEGMENT15       | |
| 22  | Segment16            | SEGMENT16       | |
| 23  | Segment17            | SEGMENT17       | |
| 24  | Segment18            | SEGMENT18       | |
| 25  | Segment19            | SEGMENT19       | |
| 26  | Segment20            | SEGMENT20       | |
| 27  | Segment21            | SEGMENT21       | |
| 28  | Segment22            | SEGMENT22       | |
| 29  | Segment23            | SEGMENT23       | |
| 30  | Segment24            | SEGMENT24       | |
| 31  | Segment25            | SEGMENT25       | |
| 32  | Segment26            | SEGMENT26       | |
| 33  | Segment27            | SEGMENT27       | |
| 34  | Segment28            | SEGMENT28       | |
| 35  | Segment29            | SEGMENT29       | |
| 36  | Segment30            | SEGMENT30       | |
| 37  | Budget Amount        | BUDGET_AMOUNT   | Required. Positive = debit, negative = credit. |
| 38  | Ledger Name          | LEDGER_NAME     | Alternative to LEDGER_ID. |

## Implementation Status: FIXED (2026-04-01)

The generator, staging table, transform table, and transformer have been corrected to
match the 38-column FBDI spec exactly.

### Changes Made

**Generator** (`packages/generators/fbdi/gl/dmt_gl_budget_fbdi_gen_pkg.pkb`):
- Rewritten to produce exactly 38 CSV columns in CTL order
- Removed: BUDGET_ENTITY_NAME, JOURNAL_STATUS, ATTRIBUTE1-8 (not in GL_BUDGET_INTERFACE)
- Added: RUN_NAME (pos 1), STATUS_FBDI (pos 2), LEDGER_ID (pos 3), LEDGER_NAME (pos 38)
- No header row in CSV output (per FBDI spec)

**STG table** (`schema/tables/150_dmt_gl_budget_int_stg_tbl.sql`):
- Added: RUN_NAME, LEDGER_ID, LEDGER_NAME
- Removed: ATTRIBUTE1-8 (not in GL_BUDGET_INTERFACE)
- Kept: BUDGET_ENTITY_NAME (user input only, NOT sent in FBDI CSV)
- Kept: JOURNAL_STATUS (maps to FBDI STATUS column; renamed from original STATUS via alter script)

**TFM table** (`schema/tables/151_dmt_gl_budget_int_tfm_tbl.sql`):
- All 38 FBDI columns present plus standard TFM trailing columns
- Added: RUN_NAME, STATUS_FBDI, LEDGER_ID, LEDGER_NAME
- Removed: BUDGET_ENTITY_NAME, JOURNAL_STATUS, ATTRIBUTE1-8
- STATUS_FBDI is named to avoid clash with TFM_STATUS (pipeline lifecycle)

**Transformer** (`packages/transformers/dmt_gl_budget_transform_pkg.pkb`):
- Populates RUN_NAME from STG (defaults to 'DMT_{integration_id}')
- Populates STATUS_FBDI from STG JOURNAL_STATUS (defaults to 'NEW')
- Passes through LEDGER_ID and LEDGER_NAME from STG

**Test data** (`scripts/insert_regression_test_data.py`):
- Added LEDGER_NAME ('US Primary Ledger') to all GL Budget test inserts

### Column Name Mapping: STG -> TFM -> CSV

| STG Column | TFM Column | CSV Position | Notes |
|------------|-----------|-------------|-------|
| RUN_NAME | RUN_NAME | 1 | Defaults to 'DMT_{integration_id}' if NULL |
| JOURNAL_STATUS | STATUS_FBDI | 2 | Defaults to 'NEW' if NULL |
| LEDGER_ID | LEDGER_ID | 3 | User supplies either LEDGER_ID or LEDGER_NAME |
| BUDGET_NAME | BUDGET_NAME | 4 | |
| PERIOD_NAME | PERIOD_NAME | 5 | |
| CURRENCY_CODE | CURRENCY_CODE | 6 | |
| SEGMENT1-30 | SEGMENT1-30 | 7-36 | |
| BUDGET_AMOUNT | BUDGET_AMOUNT | 37 | |
| LEDGER_NAME | LEDGER_NAME | 38 | Alternative to LEDGER_ID |
| BUDGET_ENTITY_NAME | *(not on TFM)* | *(not in CSV)* | User input only, not in FBDI |

## CTL File

The reconstructed CTL file `GlBudgetInterface.ctl` in this directory is based on:
- The XLSM template column order (verified by parsing the actual Oracle XLSM file)
- Standard Oracle FBDI CTL patterns (matching FaMassAdditions.ctl and other CTLs in this repo)
- Server-side columns (CREATION_DATE, CREATED_BY, etc.) added as expression/constant per Oracle convention

**Note:** This CTL was reconstructed, not downloaded from the Fusion instance. The actual CTL
(`glbudgetimport.ctl`) is embedded in the Fusion application server and loaded by the
"Load Interface File for Import" ESS process. The column order and data columns match
what the XLSM template produces. Verify against the actual Fusion instance CTL if possible
by downloading the XLSM from the Fusion instance directly and inspecting the VBA macro.

## Pipeline Test Results

### Run 1 (2026-04-01, integration_id=100000026, prefix=9122)

Initial end-to-end test with rewritten 38-column packages.

| Step | Result | Details |
|------|--------|---------|
| Pre-validation | PASS | No rules defined yet; pass-through |
| Transform | PASS | 3 rows transformed (RUN_NAME defaulted to DMT_100000026) |
| FBDI generation | PASS | ZIP created (307 bytes), 3 rows set to GENERATED |
| Load ESS (9391780) | SUCCEEDED | `loadAndImportData` with `fin/budgetBalance/import` account |
| Import ESS (9391786) | ERROR | Fusion rejected: LEDGER_ID was NULL, budget name invalid |
| BIP reconciliation | BLOCKED | BIP report not yet deployed to Fusion catalog |

### Run 2 (2026-04-01, integration_id=100000029, prefix=9125)

Full pipeline with all fixes applied: valid LEDGER_ID, deployed BIP report, fixed BIP query and results package.

| Step | Result | Details |
|------|--------|---------|
| Pre-validation | PASS | No rules defined yet; pass-through |
| Transform | PASS | 3 rows transformed |
| FBDI generation | PASS | ZIP created, 3 rows set to GENERATED |
| Load ESS (9391817) | SUCCEEDED | SqlLoader loaded CSV into GL_BUDGET_INTERFACE (60s) |
| Import ESS (9391820) | ERROR | ValidateAndLoadBudgets failed (expected: "Conversion Budget" does not exist in demo instance) |
| BIP reconciliation | PASS | BIP query matched 3 rows via `run_name = 'DMT_100000029'`; all 3 marked FAILED |
| Master totals | PASS | total=3, successful=0, errored=3, status=FAILED |

**Conclusion:** The full pipeline is working end-to-end including BIP reconciliation. All rows correctly reach terminal FAILED status because the budget name "Conversion Budget" does not exist in the Fusion demo instance. The NONEXISTENT BUDGET row also correctly fails. To achieve LOADED status, test data needs a budget name that exists in the target Fusion instance.

### Run 3 (2026-04-02, integration_id=100000033, prefix=9129)

Fixed BUDGET_NAME from "Conversion Budget" to "Budget" (the only budget name found in GL_BUDGET_INTERFACE).
Period names still in "Jun-25"/"Jul-25" format.

| Step | Result | Details |
|------|--------|---------|
| Transform | PASS | 2 rows transformed |
| Load ESS (9392811) | SUCCEEDED | SqlLoader loaded CSV into GL_BUDGET_INTERFACE (60s) |
| Import ESS (9392814) | ERROR | ValidateAndLoadBudgets failed in 1 second |
| BIP reconciliation | PASS | Rows matched, marked FAILED (Import status: NEW) |

### Run 4 (2026-04-02, integration_id=100000035, prefix=9131)

Fixed PERIOD_NAME format: "Jun-25" to "06-25", "Jul-25" to "07-25" (matching the instance's AccountingMMYY calendar).

| Step | Result | Details |
|------|--------|---------|
| Transform | PASS | 2 rows transformed |
| Load ESS (9392959) | SUCCEEDED | SqlLoader loaded CSV (60s) |
| Import ESS (9392962) | ERROR | ValidateAndLoadBudgets failed in 1 second -- same as all prior runs |
| BIP reconciliation | PASS | Rows matched, marked FAILED (Import status: NEW) |

### Root Cause Analysis (2026-04-02)

**The ValidateAndLoadBudgets ESS job is broken at the instance level.** Every single execution of this job on the demo instance (all 5 runs: 9391786, 9391812, 9391820, 9392814, 9392962) has STATE=10 (ERROR) and completes in ~1 second. The "Jan14 DE" demo data that was pre-loaded into GL_BUDGET_INTERFACE also has STATUS=FAILED.

Key findings from Fusion instance investigation:
- **Valid budget name:** "Budget" (the only BUDGET_NAME in GL_BUDGET_INTERFACE)
- **Valid period format:** MM-YY (e.g., "06-25", "07-25") -- the period_set_name is "AccountingMMYY"
- **Period statuses:** 06-25 and 07-25 are both OPEN (closing_status='O')
- **Ledger:** US Primary Ledger (ID: 300000046975971, COA_ID: 21)
- **GL_BALANCES has zero budget rows** (actual_flag='B') -- no budget data has ever been successfully loaded
- **GL_BUDGET_VERSIONS** and **GL_BUDGET_ASSIGNMENTS** tables are inaccessible (security/VPD policy)
- **ParameterList:** `#NULL` is correct -- all prior runs also used empty arguments

**Conclusion:** The demo instance lacks required GL budget configuration (likely no open budget version or no budget organization assigned to the "Budget" definition). The pipeline code is correct -- data reaches the interface table with correct format, correct budget name, correct period names, correct ledger. The failure is in Fusion's ValidateAndLoadBudgets process itself. This cannot be fixed from the DMT side; it requires Fusion GL budget setup by a functional admin.

**Updated test data on ATP (2026-04-02):**
- BUDGET_NAME: "Budget" (was "Conversion Budget")
- PERIOD_NAME: "06-25"/"07-25" (was "Jun-25"/"Jul-25")
- The negative test case (NONEXISTENT BUDGET) was left as-is (STATUS=FAILED)

## Fixes Applied (2026-04-01)

1. **LEDGER_ID**: Queried Fusion via BIP -- "US Primary Ledger" = `300000046975971`. Updated STG test data.
2. **BIP report deployed**: `GL_BUDGET_DM.xdm` and `GL_BUDGET_RPT.xdo` deployed to `/Custom/DMT/GLBudgetBalances/` via FBT_BIP_PKG.
3. **BIP query fixed**: Changed from `request_id = :P_BATCH_ID` to `run_name = 'DMT_' || :P_BATCH_ID`. The `request_id` column is NULL when the import ESS job errors before processing rows. `run_name` is set by the transform to `DMT_{integration_id}` and is always populated.
4. **PARSE_AND_UPDATE fixed**: Added `period_name` to the XMLTABLE and UPDATE join to uniquely match rows (budget_name alone is not unique across periods).
5. **FETCH_BIP_RESULTS fixed**: Now passes `p_integration_id` as `P_BATCH_ID` (not `p_load_ess_id`), matching the BIP query's `run_name` pattern.
6. **update_master_totals fixed**: Dynamic SQL now detects whether each TFM table uses `STATUS` or `TFM_STATUS` column name, fixing `ORA-00904` for GL Budget and GL Balance TFM tables.
7. **deploy_bip_reports.py updated**: Added GLBudgetBalances entry to the deployment list.

## Fusion Instance Reference

- **US Primary Ledger ID:** 300000046975971
- **Chart of Accounts ID:** 21
- **Period Set Name:** AccountingMMYY
- **Period Format:** MM-YY (e.g., 01-25, 06-25, 12-25)
- **Valid Budget Name:** "Budget" (only budget found in GL_BUDGET_INTERFACE)
- **UCM Account:** fin/budgetBalance/import
- **ESS Job:** /oracle/apps/ess/financials/generalLedger/ledgers/ledgerDefinitions,ValidateAndLoadBudgets
- **BIP catalog path:** /Custom/DMT/GLBudgetBalances/GL_BUDGET_RPT.xdo
- **Instance limitation:** ValidateAndLoadBudgets ESS job always returns ERROR on this demo instance (budget config incomplete)

### GL Ledgers Available

| Ledger Name | Ledger ID | Currency | COA ID | Period Set |
|-------------|-----------|----------|--------|------------|
| US Primary Ledger | 300000046975971 | USD | 21 | AccountingMMYY |
| Healthcare US Primary Ledger | 300000101474319 | USD | 386 | AccountingMMYY |
| UK Primary Ledger | 300000047488112 | GBP | - | - |
| Spain Primary Ledger | 300000117819959 | EUR | - | - |

## BREAKTHROUGH — Root Cause & Working Process (2026-06-30)

The earlier "instance is broken" conclusion was **WRONG**. The user manually loaded a
known-good template successfully (ESS process **9683000**). Root cause of all prior failures:
**the second ESS job was never submitted with the Run Name parameter.**

### The correct two-step process (confirmed by template instructions + live run)

1. **Load Interface File for Import** → select import process *"General Ledger Validate and
   Load Budgets"* → loads CSV into `GL_BUDGET_INTERFACE`. (This is `loadAndImportData`.)
2. **Validate and Load Budgets** (standalone ESS job) → **parameter = Run Name** (Column A).
   Submit **once per distinct Run Name** in the file.

Prior DMT runs only did step 1; the chained `ValidateAndLoadBudgets` it triggered got
`#NULL` (no run name) and errored in ~1s. DMT never ran step 2 standalone with the run name.

### Known-good data (from `GeneralLedgerBudgetBalanceImportTemplate.xlsm`)

| Field | Value |
|-------|-------|
| Run Name | `Budget_EO_1` |
| Status | `NEW` |
| Ledger Id | `300000046975971` (populated — not just ledger name) |
| Budget Name | `Budget` (must match an **Accounting Scenario** value) |
| Period | `06-26` (MM-YY; *period status is irrelevant* per template) |
| Currency | `USD` |
| Segments | `101.10.{77600,60540,62510,63180}.120.000.000` |
| Budget Amount | `1000` |

### ESS family of the successful run (queried via BIP `ess_request_history`)

- **9683000** = `.../ledgerDefinitions/ValidateAndLoadBudgets` — STATE **12 (SUCCEEDED)**, user `CASEY.BROWN`
- **9683001** = `.../ledgerDefinitions/LoadBudget` (child) — STATE **12 (SUCCEEDED)**

### Reconciliation findings (critical — differs from every other DMT CEMLI)

- **`GL_BALANCES` has ZERO budget rows (`actual_flag='B'`) globally.** In Fusion Cloud, GL
  budget balances live in the **Essbase balances cube, NOT the relational `GL_BALANCES`
  table.** So the standard "confirm GOOD rows in a base table via BIP SELECT" is **structurally
  impossible** for GL Budgets.
- **Interface rows persist for FAILED, are consumed (deleted) for SUCCESS.** The known-good
  `Budget_EO_1` rows are gone post-success; a prior `Budget_EO` attempt remains with
  `STATUS=FAILED`, `ERROR_MESSAGE='You must specify a valid budget name.'` (budget_name was
  the invalid `Test EO`). Old `DMT_86..102` rows remain `STATUS=NEW` (never validated; note
  their `LEDGER_ID` is blank — the NULL-ledger bug).
- **Interface STATUS holds words** (`NEW`/`FAILED`), not `P/S/E`. `request_id` is blank on
  lingering rows → match FAILED rows by `run_name` + per-row keys (segments/period/amount).
- **ESS output download faults** (`JBO-FND: FND-2`) for 9683000/9683001 — but those are
  `CASEY.BROWN`'s jobs; cross-user retrieval may be the cause. Whether the `LoadBudget` child
  emits a parseable loaded-count report is **TBD until DMT runs its own job as `fin_impl`.**

### Latent bugs found in current code (to fix)

1. **BIP query** matches `run_name = 'DMT_' || :P_BATCH_ID` → never matches real run names.
2. **`PARSE_AND_UPDATE`** success test `IN ('Y','PROCESSED','SUCCESS','COMPLETED')` — wrong;
   interface STATUS is words and successful rows don't persist anyway.
3. **Loader** submits GL Budget import as `#NULL` chained job (line ~1371) — never the
   standalone per-run-name `ValidateAndLoadBudgets`.

### Reconciliation design (pending E2E confirmation of report availability)

- Submit `ValidateAndLoadBudgets` standalone per distinct run name (`SUBMIT_IMPORT_JOB`).
- Per run name, after the job is terminal:
  - Job NOT succeeded → all that run_name's rows FAILED (job error).
  - Job succeeded → query interface by `run_name`; **remaining rows = FAILED** (per-row, with
    `ERROR_MESSAGE`); **consumed rows = LOADED**, gated on STATE=12 and (preferred) the
    `LoadBudget` output report's loaded-line count as positive confirmation.
- If the output report proves unavailable even for our own job, LOADED rests on STATE=12 +
  interface consumption — a deliberate deviation from base-table SELECT (cube isn't SQL-queryable),
  to be flagged to the user, NOT adopted silently.

## OTBI Cube Query Avenue (2026-06-30) — viable but blocked on data security

Budget balances live in the Essbase **balances cube**, reachable via the OTBI subject area
**"General Ledger - Balances Real Time"**. Confirmed this IS queryable programmatically:

- **Endpoint:** `{FUSION_URL}/analytics-ws/saw.dll` (BI EE SOAP). `nQSessionService.logon`
  works for `fin_impl` and `calvin.roth` (session IDs returned). `xmlViewService.executeSQLQuery`
  runs **logical SQL**; `metadataService.describeSubjectArea` (param `detailsLevel=IncludeTablesAndColumns`)
  returns the full table/column catalog.
- **Relevant columns:** `"Ledger"."Ledger Name"`, `"Scenario"."Scenario"` (e.g. `Budget`/`Actual`),
  `"Time"."Fiscal Period"` (MM-YY, e.g. `06-26`), `"Natural Account Segment"."Natural Account Segment Code"`,
  measures in `"Balances"` (`Beginning Balance`, `Period Net Activity`, `Ending Balance`).
  `"Amount Type"."Amount Type"` and `"Currency Type"."Currency Type"` are **filter-only** (can't be SELECTed).
- **Dimension members resolve:** `Scenario='Budget'` + the 4 loaded account codes returns exactly
  those 4; `account='77600'` + `Fiscal Period LIKE '%-26'` lists `06-26` among 12 members.
- **BLOCKER — measure amounts are NULL via the SOAP `executeSQLQuery` path for ALL tested
  users**, including **`CASEY.BROWN`** (the user who ran the known-good load, tested with
  `fin_impl`'s password). Null even at the coarsest grain (total budget `Period Net Activity`
  for the ledger, no other dimensions). Since the *loader herself* can't read amounts this way,
  it is **not** a per-user data-access grant problem — it's the **access method**: GL data-access-set
  security session variables that gate the balances cube don't initialize over raw
  `executeSQLQuery`, so the fact is suppressed (null). Filtering by `Fiscal Period` at the
  account-segment grain throws nQSError 14023, consistent with the same suppression.

**BIP "Oracle BI EE" logical-SQL data model — TESTED, NOT AVAILABLE (2026-06-30).** Built a BIP
data model with a logical-SQL `<sql dataSourceRef="...">` dataset over the subject area from
scratch and ran it via the normal `runReport` path (FBT_BIP_PKG). Every candidate BI-Server data
source name (`OracleBIEE`, `Oracle BI EE`, `Oracle BI Server`, `BIEE`, `BISERVER`, ...) fails with:
`oracle.xdo.XDOException: Not able to find data source with name: <name> / Could not get data
source connection`. **In Fusion SaaS the BI Server is not a provisioned BIP data source** — subject
areas are reachable only through OTBI *Analyses*, not BIP logical-SQL data models. Path is a dead
end on this instance.

**Overall conclusion for OTBI amount retrieval:** NOT viable programmatically here. `executeSQLQuery`
confirms cube **presence** (dimension membership) but returns **null amounts** for all users incl.
the loader `CASEY.BROWN` (headless sessions don't initialize the GL Data-Access-Set security
context); BIP logical-SQL can't reach the BI Server at all. The cube amounts ARE visible in the
**OTBI Analysis UI** (interactive session initializes data access) — usable for manual verification,
not automated reconciliation.

**→ Reconciliation must therefore use the `LoadBudget`/`ValidateAndLoadBudgets` ESS output report**
(loaded-line counts = Fusion's own positive statement of rows loaded to the cube) plus FAILED rows
lingering in `GL_BUDGET_INTERFACE`. Test report retrieval against our own `fin_impl`-owned job
(the earlier download fault was on `CASEY.BROWN`'s job — cross-user). This is the same Import-Report
pattern already used for the PPM modules.

## BASE TABLE FOUND: GL_BUDGET_BALANCES (2026-06-30) — the RULE #1 reconciliation source

`GL_BALANCES` has no budget rows, but **`GL_BUDGET_BALANCES` DOES**, and it is SQL-queryable via
BIP (`ApplicationDB_FSCM`). Our known-good load is present with correct amounts. This is the proper
base-table confirmation — no ESS report or cube (OTBI) needed.

**Columns:** `LEDGER_ID, BUDGET_NAME, PERIOD_NAME, SEGMENT1..30, CONCAT_ACCOUNT, CURRENCY_CODE,
CURRENCY_TYPE, PERIOD_NET_DR, PERIOD_NET_CR, CREATION_DATE, CREATED_BY, LAST_UPDATE_DATE,
LAST_UPDATE_LOGIN, LAST_UPDATED_BY, OBJECT_VERSION_NUMBER`. No `run_name`/`request_id`/interface id.

**Our loaded rows** (`ledger 300000046975971`, `Budget`, `06-26`, `CURRENCY_TYPE='T'`):

| CONCAT_ACCOUNT | PERIOD_NET_DR | LAST_UPDATE_DATE | LAST_UPDATE_LOGIN |
|---|---|---|---|
| 101-10-77600-120-000-000 | 1000 | 2026-06-29 19:00:34 | 5569F80C…AE256 |
| 101-10-60540-120-000-000 | 1000 | 2026-06-29 19:00:34 | 5569F80C…AE256 |
| 101-10-62510-120-000-000 | 1000 | 2026-06-29 19:00:34 | 5569F80C…AE256 |
| 101-10-63180-466-000-000 | 1000 | 2026-06-29 19:00:34 | 5569F80C…AE256 |

Pre-existing budget rows for other accounts have DIFFERENT `LAST_UPDATE_LOGIN` GUIDs and older dates
— so **`LAST_UPDATE_LOGIN` + `LAST_UPDATE_DATE` cluster per load run** and scope reconciliation to
our own run amid existing budget data.

### Uniqueness / attribution (budgets are CELLS, not transactions)

`GL_BUDGET_BALANCES` holds ONE row per cell = `LEDGER + BUDGET_NAME + PERIOD + CONCAT_ACCOUNT +
CURRENCY_CODE + CURRENCY_TYPE`. There is no per-source-line identity anywhere in Fusion. Two source
lines that collide on the cell key cannot exist as two rows — the cube collapses them (overwrite/sum).
So reconciliation is inherently **cell-grained**. Design:
1. **Dedup/aggregate staged rows to the cell key before load** (DMT's unit of work = a cell; report
   any collapse per `feedback_no_silent_assumptions`). Each staged cell maps 1:1 to a cube cell.
2. **LOADED** = cell present in `GL_BUDGET_BALANCES` with `PERIOD_NET_DR/CR` = expected AND
   `LAST_UPDATE_DATE >= job_start` (optionally `LAST_UPDATE_LOGIN` captured from our run).
3. **FAILED** = cell absent from balances AND row remaining in `GL_BUDGET_INTERFACE` with
   `ERROR_MESSAGE` (matched by `run_name` + cell key).
4. Cross-check: `staged cells = loaded cells + failed cells`.
DMT's STG/TFM tables remain the system of record for source-line lineage; the cube outcome for a
cell is fanned back to that cell's source line(s).

**Discovery tooling (Python dev/test shims, local only):** `/tmp/otbi*.py` —
logon, executeSQLQuery, describeSubjectArea. Pipeline itself must be PL/SQL (`UTL_HTTP` SOAP).

## IMPLEMENTATION — reconciliation + submission rebuilt (2026-06-30)

Built to match the standard per-object package pattern, with the cell-grain specifics:

1. **BIP report** — `bip/GLBudgetBalances/GL_BUDGET_DM.xdm` + `query.sql`. Params `P_RUN_START`,
   `P_LEDGER_ID`. Returns `BAL` rows (GL_BUDGET_BALANCES cells since run start, DR/CR) UNION
   `IFACE` rows (GL_BUDGET_INTERFACE errors since run start), keyed by a normalised 30-segment
   `ACCOUNT_KEY`. **Deployed + verified** against the known-good run: 4 BAL @ 1000 (LOADED) +
   4 IFACE "Test EO" errors (the prior failed attempt) — pre-existing Feb data correctly excluded.
2. **Results package** — `DMT_GL_BUDGET_RESULTS_PKG` (.pks/.pkb) rewritten: `RECONCILE_BATCH`
   gains optional `p_run_start`/`p_ledger_id`; `PARSE_AND_UPDATE` builds cell keys, marks LOADED
   (BAL match + DR/CR loose confirmation, warns on amount drift), FAILED (interface error), and
   leaves unmatched cells non-terminal (accounting rule). **Compiles VALID.**
3. **Loader** — new custom `GLBudgetBalances` block: load once (loadAndImportData; chained
   validate is a throwaway), then `SUBMIT_IMPORT_JOB(ValidateAndLoadBudgets, <Run Name>)`
   **per distinct Run Name**, capture run-start, then `RECONCILE_BATCH`. **Compiles VALID.**

## E2E PASS — RULE #1 satisfied (2026-06-30, run 112, prefix 9623)

Launched via the working scheduler pattern (inline `create_run_and_queue` — `SUBMIT_OBJECTS`
still hangs per [[project_dmt_pipeline_launch_gotchas]]; the active `DMT_QUEUE_POLLER` drove
`EXECUTE_ONE → RUN_GL_BUDGETS →` the grouped GL-Budget block). Test data: 4 GOOD
(`Budget_EO_1`/`Budget`/`06-26`, accts 77600/60540/62510/63180 @ 1000) + 1 BAD
(`Budget_EO_BAD`/`NONEXISTENT BUDGET` @ 500), tagged scenario `GLBUD_E2E`.

Flow (from the run log):
- `loadAndImportData` ESS 9687625 → SUCCEEDED (CSV → GL_BUDGET_INTERFACE)
- `ValidateAndLoadBudgets` per Run Name: `Budget_EO_1` (9687632) → SUCCEEDED; `Budget_EO_BAD`
  (9687639) → ERROR
- `FETCH_BIP_RESULTS run_start>=2026-06-30 21:46:28 ledger=300000046975971`
- `PARSE_AND_UPDATE complete. LOADED: 4, FAILED: 1, UNACCOUNTED: 0`

Result — **4 LOADED** (confirmed in `GL_BUDGET_BALANCES` via DR/CR cell match, run-start scoped),
**1 FAILED** (`[FUSION_ERROR] You must specify a valid budget name.;`), STG fanned back, run
COMPLETED. Zero unaccounted → object DONE. The distinct-Run-Name loop and cell-grain uniqueness
handling both exercised. `C_SKEW_HOURS=4` window correctly captured our cells and excluded the
months-old pre-existing budget rows.

**Follow-ups (nice-to-have, not blockers):**
- Add these known-good rows to the regression suite (1-2 GOOD + 1 BAD) per the regression-data rule.
- Consider validating `C_SKEW_HOURS` headroom vs. actual ATP↔Fusion `LAST_UPDATE_DATE` TZ offset
  (the run proved 4h is sufficient here).

## Date

Analysis performed: 2026-04-01
Fix implemented: 2026-04-01
Full pipeline verified: 2026-04-01
Budget name/period investigation: 2026-04-02
