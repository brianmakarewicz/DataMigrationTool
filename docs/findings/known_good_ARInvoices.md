# ARInvoices — known-good Fusion run vs DMT (why the owner's AutoInvoice succeeds and ours crashes)

Date: 2026-10-07. Object: ARInvoices (AutoInvoice import, one FBDI zip = `RaInterfaceLinesAll.csv`).
Known-good reference: the owner's successful run, Fusion process **10071776** (Import AutoInvoice),
file `ArAutoinvoiceImport.zip` built from `AutoInvoiceImportTemplate1.xlsm`. All artefacts are in
`objects/ARInvoices/known_good/`.

All Fusion reads were read-only (`scripts/fusion_bip_query.py --cred fin_impl`, ESS logs via
`downloadESSJobExecutionDetails`). The local DMT database was only read (runs 234/236/238). The
only Fusion writes were my own standalone test loads (prefixes 97731–97734) and two
`InterfaceLoaderPurge` runs scoped to my own load requests (see "Cleanup").

## Short answer

1. **The consolidated-billing crash is history, not the current blocker.** In run 234 (July) the
   AutoInvoice log for US1 Business Unit printed `Consolidation Billing Enabled Y` and refused to
   run. In runs 236 and 238 (2026-10-06) the same log prints `Consolidation Billing Enabled N`, so
   the setting has since been switched off on the pod. The job now gets past that check.
2. **DMT's External Source job now crashes on the line flexfield context.** Every DMT row carries
   `INTERFACE_LINE_CONTEXT = 'LEGACY'`. `LEGACY` is not a defined context of the Line Transactions
   flexfield (`RA_INTERFACE_LINES`); the known-good file uses `EXTERNAL_SOURCE`, which is. AutoInvoice
   treats an undefined context as a fatal error, so the whole job aborts with *"You must enter a valid
   context for the LEGACY flexfield."* (request 10069691, run 236; identical in 10070598, run 238).
   No row gets a per-row verdict, so all rows are UNACCOUNTED.
3. **DMT's BAD-row job crashes for a different reason.** The BAD row puts an invalid value in a
   partition key (batch source `Manual-Other`), so its whole partition job aborts with *"The
   transaction source isn't valid for the business unit based on reference set association."*
   (10069706 / 10070604). A bad partition key always produces a job-level crash, never a per-row error.
4. **The ESS parameters are not the problem.** DMT submits the same job (`AutoInvoiceImportEss`
   chained from `loadAndImportData`) with the same 24-argument shape. BU and batch source come from
   the data file. The only other difference is a constant flag (argument 23).
5. **The known-good file works outside the tool.** Re-prefixed and re-submitted standalone, all 5
   GOOD lines reached `RA_CUSTOMER_TRX_ALL` and the deliberate BAD line was rejected per row with a
   real Fusion error.
6. **Three further problems would bite DMT even with a valid context** (all proven live): DMT always
   sends a TRX_NUMBER (rejected on an auto-numbering source), DMT does not run-prefix an
   STG-supplied `INTERFACE_LINE_ATTRIBUTE1` (re-runs rejected as duplicates), and DMT submits a second
   `AutoInvoiceMasterEss` job that is not needed and points reconciliation at the wrong request.

## STEP 1 — ESS job chain and parameter comparison

### Known-good chain (submitter CASEY.BROWN, 2026-10-07)

| Request | Job | State | Notes |
|---|---|---|---|
| 10071771 | InterfaceLoaderPurge | SUCCEEDED | Purged AR interface (id 2) load requests 10071608–10071761 *before* the clean load. This removed DMT's stale rows. |
| 10071773 | InterfaceLoaderController (Load Interface File for Import) | SUCCEEDED | args: `2`, UCM doc `7890181`, `N`, `N`; file `ArAutoinvoiceImport.zip`, job "Import AutoInvoice" |
| 10071774 / 10071775 | InterfaceLoaderAsyncJob / InterfaceLoaderSqlldrImport | SUCCEEDED | children of 10071773 |
| **10071776** | **AutoInvoiceImportEss** (Import AutoInvoice) | **SUCCEEDED** | created 4 invoices (trx 102101–102104) |
| 10071777 | AutoInvoiceMainEss | SUCCEEDED | AutoInvoice Execution Report (BIP); argument1 = 10071776 |
| 10071788 / 10071790 | AutoInvoiceImportEss / AutoInvoiceMainEss | SUCCEEDED | second import run; created the 5th invoice (102105) |

Earlier attempts by the same user that morning (10071637–10071765) include one ERROR (10071725).
`fin_impl` cannot download CASEY.BROWN's ESS logs (FND-2 fault), so their log text is not available.

### Positional arguments: AutoInvoiceImportEss (Import AutoInvoice)

| Pos | Meaning (from the job's own log echo) | Known-good 10071776 | DMT run 236 10069691 (External Source) | DMT run 236 10069706 (Manual-Other) | Difference |
|---|---|---|---|---|---|
| 1 | Business Unit (org id) | `300000075888561` (Progress US Business Unit) | `300000046987012` (US1 Business Unit) | `300000046987012` | Business value. DMT's comes from TFM `BU_NAME` (the file) — correct; the test data simply uses a different BU. |
| 2 | Transaction (batch) source name | `External Source` | `External Source` | `Manual-Other` | Same for GOOD rows. DMT's comes from TFM `BATCH_SOURCE_NAME` (the file) — correct. |
| 3 | Default date | `2026-10-07` | `2026-10-06` | `2026-10-06` | Run date (SYSDATE) in both. No issue. |
| 4–22 | Transaction type, customer/date/number/order ranges | empty | empty (`#NULL`) | empty | None |
| 23 | Base Due Date on Transaction Date | **`Y`** | **`N`** | `N` | Constant flag. Not a crash cause. The template documents `Yes` as the default; recommend aligning. |
| 24 | Due Date Adjustment Days | empty | empty | empty | None |

The raw argument list in the AutoInvoice log is identical in shape for both (RAXTRX, MAIN, mode T,
source name, default date, ..., "Call RAXTRX from RAXMTR flag N", org id). The load request
(InterfaceLoaderController) arguments are also the same shape: `2, <UCM doc id>, N, N`.

**No hardcoded business values found.** In `DMT_LOADER_PKG.RUN_AR_INVOICES` the ParameterList is
built from `grp_rec.BU_NAME` and `grp_rec.BATCH_SOURCE_NAME`, which come from
`SELECT DISTINCT BU_NAME, BATCH_SOURCE_NAME FROM DMT_RA_LINES_TFM_TBL` — i.e. the data file — and the
object partitions on both. The only literals are constant flags (`#NULL`, `N`).

### What happened to the consolidated-billing crash

| Run | Request | Log line | Outcome |
|---|---|---|---|
| 234 (2026-07-21) | 9773727 | `Consolidation Billing Enabled Y` → "Run AI from Master!!!" → *The invoices couldn't be imported because consolidated billing is enabled...* | job ERROR |
| 236 (2026-10-06) | 10069691 | `Consolidation Billing Enabled N` → "AutoInvoice Import is not called from Master" → 94 rows selected → *You must enter a valid context for the LEGACY flexfield.* → `Error calling fdfdfa()/raagtf()/raamil()` | job ERROR |
| 238 (2026-10-06) | 10070598 | identical to 236 | job ERROR |
| standalone (this work) | 10073584 | `Consolidation Billing Enabled N` (Progress US BU) → 7 rows selected → invoices created | SUCCEEDED |

So the consolidated-billing abort was real in July for US1 Business Unit, but that pod setting has
since been turned off (by the functional owner — not something DMT should change). The job that
crashes today crashes on the `LEGACY` context instead. In run 236 the job also swept up 94 stale
External Source rows left in the interface by earlier DMT runs; the owner's purge (10071771) has
since removed them.

## STEP 2 — the known-good file, and how it differs from DMT's file

### How the template builds the CSV

The `.xlsm` sheet `RA_INTERFACE_LINES_ALL` has 371 columns (column A = Business Unit Identifier,
column B = Business Unit Name). The `GenCSV` macro (`evidence/AutoInvoiceImportTemplate1_vba_macro.txt`)
cuts column B and re-inserts it before column KB, so BU Name lands at **CSV position 287**, then
appends an `END` column. Result: 372 columns, no header row, CRLF line ends. Template data rows
5–9 hold exactly the 5 lines in the zip.

### Column-by-column comparison (1-indexed CSV positions)

| Pos | Field | Known-good (row 1) | DMT run 238 (RT-AR-G1) | Matters? |
|---|---|---|---|---|
| 1 | Business Unit Identifier (ORG_ID) | empty | empty | no |
| 2 | Transaction Batch Source Name | `External Source` | `External Source` | same |
| 3 | Transaction Type Name | `Invoice` | `Invoice` | same |
| 4 | Payment Terms | `30 Net` | `Net 30` | both valid term names on the pod |
| 5 / 6 | Transaction Date / Accounting Date | `2026/03/17` | `2025/06/15` | both periods open today; must be in an open period at run time |
| **7** | **Transaction Number** | **empty** | **`93294RT-AR-G1`** | **YES — External Source uses automatic numbering; a supplied number is rejected per row (proven below)** |
| 19 | Bill-to Customer Account Number | `122133` | `10060` | business data |
| 20 | Bill-to Customer Site Number | `1430587` | empty | known-good always supplies it (10060 has six bill-to sites) |
| 26 | Line Type | `LINE` | `LINE` | same |
| 27 | Description | `Sentinal Desktop` | `RT professional services` | data |
| 28 / 29 | Currency / Conversion Type | `USD` / `User` | `USD` / `User` | same |
| 31 | Conversion Rate | `1.00` | empty | not a crash cause |
| 32 | Line Amount | `1000.00` | `3200` | data |
| 33 / 35 | Quantity / Unit Selling Price | `1.00` / `1000.00` | empty | known-good supplies them |
| **37** | **Line Transactions Flexfield Context** | **`EXTERNAL_SOURCE`** | **`LEGACY`** | **YES — `LEGACY` is not a defined context → job-level crash** |
| 38 | Line Transactions Flexfield Segment 1 | `86753091` | `RT-AR-G1` (not run-prefixed) | YES — must be unique across all runs (proven below) |
| 39 | Line Transactions Flexfield Segment 2 | `867530912` | `1` | combined with 38 must be unique |
| 77 | Default Taxation Country | `US` | empty | not a crash cause |
| 111 | Memo Line Name | `Venue Fee` | empty | known-good supplies it |
| 204 | Invoice Lines Flexfield Segment 1 (line DFF ATTRIBUTE1) | empty | `DMT:238:1546:100029491` (DMT reference id) | harmless — proven to round-trip to the base line |
| 287 | Business Unit Name | `Progress US Business Unit` | `US1 Business Unit` | business value from the file |
| 372 / 373 | `END` / extra empty | `END` (372 cols) | 373 cols, no `END` | harmless (extra trailing fields are ignored; DMT loads succeed) |

Fields that drive consolidated billing / bill-to / terms / type / source: none of the CSV values
trigger consolidated billing — that was a BU-level pod setting (see Step 1). Batch source, type and
terms are equivalent between the two files.

Valid contexts for `RA_INTERFACE_LINES` on this pod (from `FND_DF_CONTEXTS_B`) include
`EXTERNAL_SOURCE`, `DOO`, `FOS`, `INTERCOMPANY`, `CONTRACT INVOICES`, `Contracts Context`, ...;
neither `LEGACY` nor DMT's transformer default `DMT Migration` exists. `EXTERNAL_SOURCE` has two
segments: `Header_ID` = INTERFACE_LINE_ATTRIBUTE1 and `Line_ID` = INTERFACE_LINE_ATTRIBUTE2 (value
set 50731; the known-good values are numeric).

### Standalone run outside DMT (prefix 97731)

Script: `objects/ARInvoices/known_good/scripts/standalone_ar.py 97731` (pure Python, reuses the
`gold_regression/harness` SOAP helpers; no DMT code or DB in the path). It copies the known-good CSV
byte-for-byte except that the flexfield keys (positions 38/39) get the prefix `97731` (checked: no
existing interface or base line used `97731%`), then adds one BAD row and one PROBE row.
Submitted with `loadAndImportData`, job `AutoInvoiceImportEss`, interface details `2`, UCM account
`fin/receivables/import`, and the known-good argument list
`Progress US Business Unit,External Source,2026-10-07,#NULL×19,Y,#NULL` (BU and source read from the
file's own columns 287 and 2).

| Request | Job | State |
|---|---|---|
| 10073567 | InterfaceLoaderController (load) | SUCCEEDED — 7 rows loaded |
| 10073584 | AutoInvoiceImportEss | SUCCEEDED (log: `Consolidation Billing Enabled N`, `7 row(s) updated`) |
| 10073648 | AutoInvoiceMainEss | SUCCEEDED (Execution Report) |

**GOOD rows → base tables (all 5):**

| INTERFACE_LINE_ATTRIBUTE1 | Amount | RA_CUSTOMER_TRX_ALL.CUSTOMER_TRX_ID | TRX_NUMBER (auto) | RA_CUSTOMER_TRX_LINES_ALL.CUSTOMER_TRX_LINE_ID | REQUEST_ID |
|---|---|---|---|---|---|
| 9773186753091 | 1000 | 1586942 | 103101 | 2765097 | 10073584 |
| 9773186753092 | 250 | 1586941 | 103102 | 2765098 | 10073584 |
| 9773186753093 | 50 | 1586939 | 103103 | 2765099 | 10073584 |
| 9773186753094 | 15 | 1586943 | 103104 | 2765100 | 10073584 |
| 9773186753095 | 35 | 1586940 | 103105 | 2765101 | 10073584 |

Note: the base header `REQUEST_ID` is the **AutoInvoiceImportEss** request id, not the Main/Master id.

**BAD row → real per-row Fusion error** (`RA_INTERFACE_ERRORS_ALL`, interface_line_id 2765102,
bill-to account `999999999`):
> You must enter a valid bill-to customer account number. The current number is {BILL_CUSTOMER_ACCOUNT_NUMBER. [invalid value 999999999]

**PROBE row (TRX_NUMBER supplied, exactly as DMT does)** → rejected per row (interface_line_id 2765103):
> You must provide a transaction number if the transaction source indicates manual transaction numbering. Otherwise don't provide a transaction number.

### Follow-up probes (same day)

| Prefix | What it tested | Request(s) | Result |
|---|---|---|---|
| 97731 dup | Re-sent good row 1 with the SAME flexfield keys (what DMT does on a re-run, because it does not prefix an STG-supplied ATTRIBUTE1) | load 10073678 / import 10073683 | Rejected per row (2765104): *Each line must have a unique combination of INTERFACE_LINE_CONTEXT and INTERFACE_LINE_ATTRIBUTE values for the transaction flexfield.* [trx_number=103101, customer_trx_id=1586942] |
| 97732 | Same good line with the DMT reference id in line DFF ATTRIBUTE1 (position 204) | load 10073698 / import 10073701 | Not imported **and no error row** — see next row |
| 97733 | Control: identical line, position 204 blank | load 10073721 / import 10073725 | Also not imported, no error row |
| 97734 | After purging only the errored dup row (InterfaceLoaderPurge 10073730, load 10073678 only), one more control line | load 10073731 / import 10073734 | 97732, 97733 and 97734 all imported into ONE invoice: customer_trx_id **1585948**, trx 102106, lines 2766127 / 2765107 / 2766132, request 10073734. Line ATTRIBUTE1 `DMT:0:0:97732` round-tripped to the base line. |

What the 97732/97733 result means: the errored dup row had the same invoice-grouping attributes
(same bill-to account, site, dates, type, terms, currency, no transaction number). The source's
invalid-lines rule is "Reject invoice", so AutoInvoice held back every valid line that would have
joined that invoice, **without writing any error for them**. Once the errored row was purged the
held lines imported. Consequences for DMT: (a) a BAD regression row must never share grouping
attributes with a GOOD row (a bad bill-to account, as below, is safe — proven in run 97731); (b) any
errored line left in the interface from an earlier run can silently hold back later GOOD rows,
which DMT would report as UNACCOUNTED.

### INTERNAL_NOTES grouping probes (2026-10-07, prefixes 97741 / 97742)

Question: can DMT make AutoInvoice put each DMT source invoice on its own Fusion invoice? The
pod's External Source grouping rule ignores `INTERFACE_LINE_ATTRIBUTE1`, so two DMT invoices with
the same customer and dates merge (probes 97732-97734 above), and a rejected line left in the
interface holds back later lines with the same grouping values. `INTERNAL_NOTES` is one of
Oracle's mandatory grouping attributes and a header-level internal text field.

CSV position: **289** of `RaInterfaceLinesAll.csv` (template label "Notes from Source", after the
GenCSV column move; 287 = Business Unit Name, 288 = Comments). `DMT_AR_FBDI_GEN_PKG` already
writes `INTERNAL_NOTES` at position 289. Script: `objects/ARInvoices/known_good/scripts/internal_notes_probe.py`
(rows built from the known-good row 1; every row: Progress US Business Unit, External Source,
Invoice, 30 Net, USD, bill-to 122133 / site 1430587, trx and GL date 2026/03/19; only
`INTERNAL_NOTES`, the flexfield key, amount and (row C) memo line differ).

| Load | Row | INTERNAL_NOTES | Result |
|---|---|---|---|
| 10074732 (import 10074736) | A, good | `DMT 97741A` | LOADED: customer_trx_id **1586950**, trx 103108, header INTERNAL_NOTES `DMT 97741A` |
| 10074732 (import 10074736) | B, good, same grouping as A | `DMT 97741B` | LOADED as a **separate** invoice: customer_trx_id **1586951**, trx 103109 |
| 10074732 (import 10074736) | C, bad memo line, same grouping as A/B | `DMT 97741C` | Rejected per row (*You must enter a valid memo line name...*); did not hold A or B back |
| 10074738 (import 10074742) | D, good, same grouping as C, C still in the interface | `DMT 97742D` | LOADED: customer_trx_id **1586953**, trx 103110 -- **not held** by the leftover rejected C |

Both proofs hold: different `INTERNAL_NOTES` split otherwise identical lines into two invoices, and
a leftover rejected line no longer holds back a later load's good line. `INTERNAL_NOTES`
round-trips to `RA_CUSTOMER_TRX_ALL.INTERNAL_NOTES`.

Cleanup: InterfaceLoaderPurge **10074752** for load 10074732 (row C), arguments `2, , <id>, <id>,
, ORA_FBDI, USER`; 0 interface rows remain for `9774%`. Load 10074738 left nothing in the
interface. The base invoices 1586950, 1586951 and 1586953 remain.

Adopted in DMT (owner decision 2026-10-07): `DMT_AR_TRANSFORM_PKG` stamps
`'DMT ' || <run-prefixed invoice key>` (after any source note) into `INTERNAL_NOTES`, switchable
through config `AR_GROUP_BY_DMT_INVOICE` (default Y).

### Cleanup

All my interface leftovers were purged (InterfaceLoaderPurge 10073730 for load 10073678 and 10073739
for load 10073567; arguments `2, , <load id>, <load id>, , ORA_FBDI, USER`, mirroring the owner's
10071771). Only my own AR loads were in that request window. `RA_INTERFACE_LINES_ALL` now has 0 rows
for `9773%`. The base-table invoices above remain (1586939–1586943, 1585948).

Note for US1 Business Unit: the interface still holds 3 rows from 2016 for `External Source` /
`EXTERNAL_SOURCE` in org 300000046987012. Any AutoInvoice run for US1 + External Source will select them too.

## Why DMT's run crashes (consolidated explanation)

- **July (run 234):** US1 Business Unit had consolidated billing on, so the standalone Import
  AutoInvoice job refused to run at all. That was pod configuration, not DMT.
- **Now (runs 236/238):** consolidated billing is off. The External Source partition crashes because
  DMT sends `INTERFACE_LINE_CONTEXT = 'LEGACY'`, an undefined flexfield context, which AutoInvoice
  treats as fatal. The value comes from the regression STG data (`DMT_RA_LINES_STG_TBL`, scenario 222);
  if STG left it blank the transformer would default to `'DMT Migration'`, which is equally undefined.
- **The Manual-Other partition** crashes because the BAD row's bad value is in a partition key
  (batch source not assigned to the BU's reference set). That is a job-level failure by design.
- **Once the context is fixed**, the GOOD rows would still be rejected per row because DMT sends a
  TRX_NUMBER to an auto-numbering source, and a second run of the same scenario would be rejected as
  duplicate flexfield keys.

## Code changes needed (NOT made — listed for the main session)

1. **`db/packages/dmt_ar_transform_pkg.pkb.sql`, lines TRANSFORM (insert-select, around line 276–279):**
   `NVL(s.INTERFACE_LINE_ATTRIBUTE1, DMT_UTIL_PKG.PREFIXED(l_prefix, s.TRX_NUMBER, 30))` passes an
   STG-supplied ATTRIBUTE1 through **without** the run prefix. Change to always prefix:
   `DMT_UTIL_PKG.PREFIXED(l_prefix, NVL(s.INTERFACE_LINE_ATTRIBUTE1, s.TRX_NUMBER), 30)` (or an
   equivalent that guarantees run-uniqueness when TRX_NUMBER is NULL, e.g. fall back to SOURCE_ID).
   Proven need: re-sent keys are rejected (*Each line must have a unique combination of
   INTERFACE_LINE_CONTEXT and INTERFACE_LINE_ATTRIBUTE values...*, 10073683). RECON_KEY is stamped from
   ATTRIBUTE1, so it follows automatically. The distributions transform (same package, the
   `DMT_RA_DISTS_TFM_TBL` insert, `s.INTERFACE_LINE_ATTRIBUTE1` at about line 586) must apply the identical prefix to its
   ATTRIBUTE1 so distributions still link to their lines.
2. **Same procedure, line ~276:** remove the hardcoded fallback context `NVL(s.INTERFACE_LINE_CONTEXT,
   'DMT Migration')`. `DMT Migration` is not a defined context on the pod and would crash the job
   exactly like `LEGACY`. The context is business data and must come from the file;
   `db/packages/dmt_ar_validator_pkg.pkb.sql` should reject (STG FAILED, real message) a line whose
   INTERFACE_LINE_CONTEXT is NULL.
3. **`db/packages/dmt_loader_pkg.pkb.sql`, procedure `AR_SUBMIT_AND_RECONCILE_ONE` (the "AR
   AutoInvoice is a TWO-job flow" block, about lines 1893–2002):** remove the `AutoInvoiceMasterEss`
   submission and the line `x_import_ess_id := l_master_ess_id;`. Evidence: with consolidated billing
   off, `AutoInvoiceImportEss` creates the transactions itself (known-good 10071776; standalone
   10073584 and 10073734), and `RA_CUSTOMER_TRX_ALL.REQUEST_ID` equals the AutoInvoiceImportEss
   request id. The Master block has never executed in DMT (AutoInvoiceImportEss ERRORED in 40 of 40
   DMT runs since run 120, so the block is unreached), it sends the whole tilde-separated argument list
   inside ONE `<typ:paramList>` element (against the one-element-per-argument rule), and every
   standalone Master attempt on this pod aborted ("load request id N is invalid"). Left in place, it
   will fire on the first run where the import succeeds and re-point reconciliation at the wrong job.
4. **`db/packages/dmt_loader_pkg.pkb.sql`, procedure `RUN_AR_INVOICES` (ParameterList build, about
   line 3201):** argument 23 (Base Due Date on Transaction Date) `N` → `Y` to match the known-good run
   and the template's documented default. Constant flag; low priority; not a crash cause.

No change is needed for TRX_NUMBER handling: `DMT_UTIL_PKG.PREFIXED` returns NULL for a NULL input,
so STG rows that leave TRX_NUMBER empty (as the known-good file does) reach the CSV empty.

## Proposed regression rows (mirror the known-good record; do NOT edit existing scenario 222)

Target table: `DMT_RA_LINES_STG_TBL`. All three rows sit in ONE partition (same BU + batch source)
so a single AutoInvoice job judges them all per row. These rows depend on code change 1 (the run
prefix on INTERFACE_LINE_ATTRIBUTE1); without it the second run of the scenario is rejected as
duplicate keys. Dates must fall in an open AR period of the Progress US ledger at run time
(MAR-26 is open today).

| Column | GOOD-1 | GOOD-2 | BAD-1 |
|---|---|---|---|
| SOURCE_ID | `RT-AR-KG-G1` | `RT-AR-KG-G2` | `RT-AR-KG-BAD1` |
| BU_NAME | `Progress US Business Unit` | `Progress US Business Unit` | `Progress US Business Unit` |
| BATCH_SOURCE_NAME | `External Source` | `External Source` | `External Source` |
| CUST_TRX_TYPE_NAME | `Invoice` | `Invoice` | `Invoice` |
| TERM_NAME | `30 Net` | `30 Net` | `30 Net` |
| TRX_DATE / GL_DATE | `2026-03-17` | `2026-03-17` | `2026-03-17` |
| TRX_NUMBER | NULL (source auto-numbers) | NULL | NULL |
| BILL_CUSTOMER_ACCOUNT_NUMBER | `122133` | `70075` | `999999999` (nonexistent) |
| BILL_CUSTOMER_SITE_NUMBER | `1430587` | `245921` | `1430587` |
| LINE_TYPE | `LINE` | `LINE` | `LINE` |
| DESCRIPTION | `Sentinal Desktop` | `Sentinal Desktop Monitor` | `BAD: nonexistent bill-to account` |
| CURRENCY_CODE / CONVERSION_TYPE / CONVERSION_RATE | `USD` / `User` / `1` | `USD` / `User` / `1` | `USD` / `User` / `1` |
| AMOUNT / QUANTITY / UNIT_SELLING_PRICE | `1000` / `1` / `1000` | `250` / `1` / `250` | `1000` / `1` / `1000` |
| INTERFACE_LINE_CONTEXT | `EXTERNAL_SOURCE` | `EXTERNAL_SOURCE` | `EXTERNAL_SOURCE` |
| INTERFACE_LINE_ATTRIBUTE1 | `86753101` | `86753102` | `86753103` |
| INTERFACE_LINE_ATTRIBUTE2 | `1` | `1` | `1` |
| DEFAULT_TAXATION_COUNTRY | `US` | `US` | `US` |
| MEMO_LINE_NAME | `Venue Fee` | `Tuition and Fees` | `Venue Fee` |

Expected outcomes: GOOD-1 and GOOD-2 → LOADED (`RA_CUSTOMER_TRX_ALL` / `RA_CUSTOMER_TRX_LINES_ALL`,
matched on INTERFACE_LINE_CONTEXT + prefixed INTERFACE_LINE_ATTRIBUTE1). BAD-1 → FAILED with
*"You must enter a valid bill-to customer account number..."* from `RA_INTERFACE_ERRORS_ALL`.
GOOD-1 and BAD-1 have different bill-to accounts, so they are never grouped into the same invoice
(proven: in run 97731 the BAD row was rejected while the good row with the same site loaded).

## Artefacts (`objects/ARInvoices/known_good/`)

- `ArAutoinvoiceImport.zip`, `RaInterfaceLinesAll.csv` — the owner's submitted file, unchanged.
- `AutoInvoiceImportTemplate1.xlsm` — the FBDI template used to build it; macro in
  `evidence/AutoInvoiceImportTemplate1_vba_macro.txt`.
- `WRITEUP_EXCERPT.txt` — the owner's writeup and the known-good ESS chain.
- `RaInterfaceLinesAll_97731.csv`, `ArAutoinvoiceImport_97731.zip` — prefixed GOOD + BAD + PROBE file;
  `run_97731.json` — its load request and ParameterList.
- `ArAutoinvoiceImport_97731_dup.zip`, `_97732_refid.zip`, `_97733_control.zip`, `_97734_control.zip` — probe files.
- `scripts/standalone_ar.py`, `scripts/dup_probe.py`, `scripts/refid_probe.py`, `scripts/esslog.py` — the standalone submit, probes and ESS-log download.
- `evidence/` — ESS logs: 10073584 (standalone success), 10073683 (duplicate-key rejection),
  10073725 (lines held by an errored sibling), 10073734 (held lines loaded after purge), 10069691
  (DMT run 236 LEGACY crash), 10069706 (DMT Manual-Other reference-set crash), 9773727 (DMT run 234
  consolidated billing); DMT run 238 generated CSVs for both partitions.
