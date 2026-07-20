# Requisitions — gold regression fixture

A standalone, reloadable FBDI fixture (1 good + 1 bad requisition, each a
header + line + distribution) that loads directly into Oracle Fusion
Self-Service Procurement via the ERP Integration SOAP service
(`loadAndImportData`, which loads the three interface tables AND chains
**Import Requisitions** / `RequisitionImportJob`), with read-only BIP
verification against the base and interface tables. No DMT tool code and no DMT
database is in the load path.

**Portable.** The requisitioning Business Unit (name + id), its primary ledger
id, the preparer email, the deliver-to location, the unit of measure, the
currency, the purchasing category and the charge-account code-combination
segments are all **discovered at load time** by read-only BIP queries against the
target pod — nothing pod-specific is hardcoded, and the fixture never depends on
data we loaded earlier. The new requisitions are created fresh (prefix-stamped);
every reference inside them is borrowed from an existing requisition on the pod.

## The three CSVs (FBDI, no header row, position-based)

One zip, three members, joined by the prefix-stamped interface keys:

- `PorReqHeadersInterfaceAll.csv` — requisition headers (70 columns).
- `PorReqLinesInterfaceAll.csv` — requisition lines (116 columns), joined to a
  header by `INTERFACE_HEADER_KEY` (col 2).
- `PorReqDistsInterfaceAll.csv` — distributions (116 columns), joined to a line
  by `INTERFACE_LINE_KEY` (col 2).

Byte-template taken from the proven `test/fbdi_zips/Requisitions_116.zip` (run
116), then tokenized. Two requisitions (each header + 1 line + 1 dist):

| Row | REQUISITION_NUMBER | INTERFACE_HEADER_KEY | Line UOM | Purpose |
|---|---|---|---|---|
| GOOD-1 | `${PREFIX}RT-REQ-G1` | `${PREFIX}_RQHDR_G1` | `${UOM_CODE}` (discovered, e.g. ECH) | valid → base |
| BAD-1  | `${PREFIX}RT-REQ-BAD1` | `${PREFIX}_RQHDR_B1` | `ZZZ` (deterministic invalid UOM) | rejected → interface error |

### Key column positions (0-based index → FBDI column)

**Headers** — col 1 `INTERFACE_HEADER_KEY`, col 2 `INTERFACE_SOURCE_CODE`=`DMT`,
col 3 `REQ_BU_NAME`=`${REQ_BU_NAME}`, col 4 `BATCH_ID`=`${PREFIX}` (must equal
ParameterList Import Batch ID), col 6 `DOCUMENT_STATUS`=`INCOMPLETE`, col 7
`APPROVER_EMAIL_ADDR`=empty, col 8 `PREPARER_EMAIL_ADDR`=`${PREPARER_EMAIL}`,
col 9 `PRC_BU_NAME`=`${REQ_BU_NAME}`, col 10 `REQUISITION_NUMBER`.

**Lines** — col 1 `INTERFACE_LINE_KEY`, col 2 `INTERFACE_HEADER_KEY` (FK),
col 4 `DESTINATION_TYPE_CODE`=`EXPENSE`, col 5 deliver-to location
=`${DELIVER_TO_LOCATION}`, col 8 requester email=`${PREPARER_EMAIL}`, col 9 item
description, col 10 category=`${CATEGORY_NAME}`, **col 11 `NEED_BY_DATE`
(`YYYY/MM/DD`, must be a real future date)**, col 14 `UOM_CODE`, col 15 line
type=`Goods`, col 16 quantity, col 17 currency=`${CURRENCY_CODE}`, col 18 unit
price.

**Dists** — col 1 `INTERFACE_DIST_KEY`, col 2 `INTERFACE_LINE_KEY` (FK), col 3
percent=`100`, col 4 distribution number=`1`, and charge-account segments at
**cols 85–90** = `${CHG_S1}`..`${CHG_S6}` (discovered code combination).

### Critical layout facts (learned live)

- **`NEED_BY_DATE` (line col 11) must be a real date in `YYYY/MM/DD`.** SQL*Loader
  rejects the row with `ORA-01841: (full) year must be between -4713 and +9999`
  if this column is blank or malformed — and because the load runs with
  `DeleteOnLoadFailure = Y`, one bad date fails the ENTIRE load (parent ESS →
  ERROR, all three interface tables purged, nothing reaches import). This was the
  first-attempt failure on prefixes 90219/90220: a template off-by-one had shifted
  the category into the need-by-date slot. Fixed by putting the category in col 10
  and a valid `2027/12/31` in col 11.
- **`BATCH_ID` (header col 4) MUST equal ParameterList arg 2 (Import Batch ID).**
  Both are stamped with `${PREFIX}`. If they differ, Import Requisitions selects
  zero rows.
- **`DOCUMENT_STATUS` = `INCOMPLETE`.** The requisition is created as an
  unsubmitted draft. This is the expected, legitimate LOADED outcome: the row IS
  created in `POR_REQUISITION_HEADERS_ALL`. `APPROVED` is not attempted (it would
  need a real approver and a clearing approval hierarchy, which is pod-dependent).
- The BAD row uses a deliberately invalid `UOM_CODE` of `ZZZ`. It passes
  SQL*Loader (it is a syntactically valid string) and is then rejected by Import
  Requisitions with a line-level row in `POR_REQ_IMPORT_ERRORS`. It reaches the
  interface and is rejected there — it is not a pre-validation drop.

## ESS orchestration (jobs, in order)

`loadAndImportData` is a single SOAP call that runs this chain:

1. **Upload** — base64-embeds `Requisitions_gold.zip` and puts it in UCM under
   DocumentAccount `prc/requisition/import`.
2. **Load Interface File for Import** (`ESS_L_<loadId>`) — spawns one SQL*Loader
   child per CSV that unpacks the zip into the three interface tables
   (`POR_REQ_HEADERS_INTERFACE_ALL`, `POR_REQ_LINES_INTERFACE_ALL`,
   `POR_REQ_DISTS_INTERFACE_ALL`). Every row is stamped with `LOAD_REQUEST_ID`
   = the load request id. If any SQL*Loader child rejects a row, the whole load
   fails and the interface rows are deleted (`DeleteOnLoadFailure = Y`).
3. **Import Requisitions** (`RequisitionImportJob`) — the chained import child.
   Validates each interface row: valid rows create a requisition in the base
   tables (`POR_REQUISITION_HEADERS_ALL` / `POR_REQUISITION_LINES_ALL` /
   `POR_REQ_DISTRIBUTIONS_ALL`); invalid rows are left in the interface with a
   row in `POR_REQ_IMPORT_ERRORS`.

The **load parent** reaches `SUCCEEDED` once the import child completes. Poll the
load request id with `getESSJobStatus` every 60 s until terminal. No further
downstream program is needed before verification (there is no separate accounting
or approval program to wait on for an INCOMPLETE draft).

## The exact call

| Thing | Value |
|---|---|
| Endpoint | `{FUSION_URL}/fscmService/ErpIntegrationService` |
| Operation | `loadAndImportData` |
| Auth | HTTP Basic, credential role `fin_impl` (connections.json). **See note below — `calvin.roth` gets HTTP 401 on this service and cannot be used for the SOAP call.** |
| UCM DocumentAccount | `prc/requisition/import` |
| ContentType | `ZIP` |
| `<typ:interfaceDetails>` | `28` (the Requisition `ERP_INTERFACE_OPTIONS_ID` from `db/seed/dmt_erp_interface_options_tbl.sql`) |
| `<erp:JobName>` | `/oracle/apps/ess/prc/por/createReq/reqImport,RequisitionImportJob` (seed stores it with a `;` before `RequisitionImportJob`; `loadAndImportData` needs the last `;` replaced with `,`) |
| `<erp:ParameterList>` | 8 args: `#NULL,${PREFIX},#NULL,${BU_ID},NONE,#NULL,NO,ALL` |
| `<typ:notificationCode>` | `10` |

### RequisitionImportJob ParameterList — 8 positions

| # | Value | Meaning |
|---|---|---|
| 1 | `#NULL` | Import Source Options (all sources) |
| 2 | `${PREFIX}` | **Import Batch ID** (must equal header BATCH_ID col 4) |
| 3 | `#NULL` | Max Batch Size |
| 4 | `${BU_ID}` | **Requisitioning BU id** (discovered) — required |
| 5 | `NONE` | Group By — required |
| 6 | `#NULL` | Next Requisition Number |
| 7 | `NO` | Initiate Approval — required |
| 8 | `ALL` | Error Level — required |

### Auth note (important)

The frozen DMT stack ran Requisitions as `calvin.roth` (the PO_USERNAME) because
inside the tool's own pipeline a fin_impl submit hit `po_core_s.get_ledger_id`
ORA-01403 ("You must enter a valid ledger ID"). In THIS standalone harness that
turned out **not** to be the blocker: `calvin.roth` gets an HTTP **401** on the
ERP Integration SOAP service (it lacks the integration privilege on this pod), so
the SOAP call must go as `fin_impl`. The load then succeeds — the "valid ledger
ID" is derived correctly from the discovered Requisitioning BU (ParameterList
arg 4), which has a primary ledger. Discovery filters the BU on
`primary_ledger_id IS NOT NULL`, so the ledger is always resolvable. Result: load
as `fin_impl`, discover/verify via BIP as `fin_impl`; `calvin.roth` is not used.

## Discovery (run before build, read-only BIP, role `fin_impl`)

Four steps, each pulling a guaranteed-valid reference from an EXISTING
requisition on the target pod (so every value is already accepted by Import
Requisitions on that pod):

1. **REQ_BU** — a requisitioning BU that has a primary ledger and at least one
   existing requisition. Returns `${BU_ID}`, `${REQ_BU_NAME}`, `${LEDGER_ID}`.
   Prefers `US1 Business Unit` when present.
2. **REQ_PREPARER** — the preparer email of the most recent requisition in that
   BU. Returns `${PREPARER_EMAIL}`.
3. **REQ_LINE_REF** — the deliver-to location, UOM, currency and category from a
   recent EXPENSE line in that BU. Returns `${DELIVER_TO_LOCATION}`,
   `${UOM_CODE}`, `${CURRENCY_CODE}`, `${CATEGORY_NAME}`.
4. **REQ_CHARGE_ACCT** — an enabled, postable charge-account code combination
   used on a recent distribution in that BU. Returns `${CHG_S1}`..`${CHG_S6}`.

(Full SQL is in `recipe.json`.) The BAD row's invalid `UOM_CODE=ZZZ` is a
literal in the template, not discovered.

## Verification (read-only, via the BIP relay — direct single-table reads)

Both directions are proven with independent single-table reads, never an
ambiguous relayed join:

- **Good → base.** Direct read of `POR_REQUISITION_HEADERS_ALL` by the prefix on
  the natural key:
  `SELECT requisition_number, requisition_header_id, document_status
   FROM por_requisition_headers_all
   WHERE requisition_number LIKE '<prefix>RT-REQ-%'`.
  Each good REQUISITION_NUMBER present with a real REQUISITION_HEADER_ID = pass.
- **Bad → interface + absent from base.** Direct read of
  `POR_REQ_HEADERS_INTERFACE_ALL` by `load_request_id`, with the line-level error
  pulled from `POR_REQ_IMPORT_ERRORS` (join `e.interface_id =
  l.req_line_interface_id` and `e.load_request_id = l.load_request_id`, rolled up
  to the header by `interface_header_key`). The base read above confirms the bad
  REQUISITION_NUMBER is absent.

Tables: interface `POR_REQ_HEADERS_INTERFACE_ALL` / `POR_REQ_LINES_INTERFACE_ALL`
/ `POR_REQ_DISTS_INTERFACE_ALL`, base `POR_REQUISITION_HEADERS_ALL` /
`POR_REQUISITION_LINES_ALL`, errors `POR_REQ_IMPORT_ERRORS`.

## How to run it

```bash
cd gold_regression/harness
python run_object.py Requisitions --prefix <PREFIX>   # discover -> build -> load -> verify
# or step by step:
python build_artifact.py Requisitions <PREFIX>
python load_fbdi.py Requisitions ../objects/Requisitions/Requisitions_gold.zip
python verify.py Requisitions <LOAD_REQUEST_ID> <PREFIX>
```

## Live evidence

**2026-07-19 — LIVE-PROVEN. PASS.**

Standalone load path only (no DMT database / code in the load path);
verification via the read-only BIP relay only.

| Field | Value |
|---|---|
| Date | 2026-07-19 |
| Prefix | `90221` |
| Load ESS request id (`loadAndImportData` result) | `9763076` |
| Terminal status (`getESSJobStatus`) | `SUCCEEDED` |
| Auth (SOAP load) | `fin_impl` |
| Discovered BU / ledger | `US1 Business Unit` (`300000046987012`) / `300000046975971` |
| Discovered preparer | `CALVIN.ROTH_esew-dev28@oraclepdemos.com` |
| Discovered location / UOM / currency / category | `Louisville` / `ECH` / `USD` / `Miscellaneous` |
| Discovered charge account | `101/10/68010/120/000/000` |

**Good row → base table `POR_REQUISITION_HEADERS_ALL` (1/1):**

| REQUISITION_NUMBER | REQUISITION_HEADER_ID | DOCUMENT_STATUS |
|---|---|---|
| `90221RT-REQ-G1` | `128988` | `INCOMPLETE` (created draft) |

**Bad row → interface error, absent from base (1/1):**

| REQUISITION_NUMBER | POR_REQ_IMPORT_ERRORS message |
|---|---|
| `90221RT-REQ-BAD1` | `UOM_CODE=ZZZ: The UOM isn't valid. Verify that the UOM is active. When the UOM isn't the primary UOM of the item in the inventory organization, there must be an active standard UOM conversion or interclass UOM conversion for the provided UOM.` |

The bad requisition landed in `POR_REQ_HEADERS_INTERFACE_ALL`
(load_request_id 9763076) with the invalid-UOM error in
`POR_REQ_IMPORT_ERRORS` and no row in `POR_REQUISITION_HEADERS_ALL`. Gold zip
`Requisitions_gold.zip` (last built at prefix 90221) kept in this directory.

### First-attempt failures, diagnosed and fixed

- **Prefix 90219 (as fin_impl) and 90220 (as calvin.roth):** load parent → ERROR.
  Pulled the ESS execution log with `downloadESSJobExecutionDetails`: SQL*Loader
  rejected both lines with `ORA-01841` on `NEED_BY_DATE`. Root cause was a
  template off-by-one that put the category name in the need-by-date column and
  left the date blank. Because `DeleteOnLoadFailure = Y`, that failed the entire
  load. Fixed the line template (category in col 10, valid `2027/12/31` in col 11)
  and the 90221 re-run passed.
- **Prefix 90220 also surfaced the auth fact:** `calvin.roth` returns HTTP 401 on
  the ERP Integration SOAP service, so the SOAP call must be `fin_impl` (see the
  Auth note above).
