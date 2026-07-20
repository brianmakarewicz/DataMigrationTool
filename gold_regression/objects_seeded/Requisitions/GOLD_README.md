# Requisitions — v2 seeded gold fixture

Converted from the frozen v1 fixture (`../../objects/Requisitions/`). Same one good + one bad
requisition (each a header + line + distribution across three CSVs), loaded via
`loadAndImportData` under `fin_impl` — a single SOAP call that loads the three interface
tables and chains **Import Requisitions** (`RequisitionImportJob`) — with read-only BIP
verification against the base and interface tables. The one difference from v1: every
upstream reference (Business Unit, ledger, preparer, deliver-to location, unit of measure,
currency, category, charge account) is **hard-coded to a standard seeded value** instead of
discovered at load time. The discovery block is removed from `recipe.json`.

## The hard-coded seeds (what v1 discovered → now literals)

All confirmed live via read-only BIP on `fa-esew-dev28` (2026-07-20). Every one is standard
seeded demo data we never loaded — none carries an `RT-` or numeric run prefix:

| Reference | Literal value | Where used |
|---|---|---|
| Requisitioning / Procurement BU name | `US1 Business Unit` | header cols 3, 9 (`REQ_BU_NAME`, `PRC_BU_NAME`) |
| Requisitioning BU id | `300000046987012` | ParameterList arg 4 |
| Primary ledger id (of that BU) | `300000046975971` | (derived by Import Requisitions from arg-4 BU; not written) |
| Preparer email | `CALVIN.ROTH_esew-dev28@oraclepdemos.com` | header col 8, line col 8 (requester) |
| Deliver-to location | `Louisville` | line col 5 |
| Unit of measure (good line) | `ECH` (Each) | line col 14 |
| Currency | `USD` | line col 17 |
| Purchasing category | `Miscellaneous` | line col 10 |
| Charge-account segments | `101 / 10 / 68010 / 120 / 000 / 000` | distribution cols 85–90 |

`${PREFIX}` stays on the new record's own keys only: the requisition number
(`${PREFIX}RT-REQ-G1` / `${PREFIX}RT-REQ-BAD1`), the interface header/line/distribution
source keys that chain the three CSVs (`${PREFIX}_RQHDR_*`, `${PREFIX}_RQLN_*`,
`${PREFIX}_RQDIST_*`), and the header `BATCH_ID` (col 4). `BATCH_ID` must equal ParameterList
arg 2 (Import Batch ID) — both are `${PREFIX}`; if they differ, Import Requisitions selects
zero rows.

### Date field — derived token, not a hardcoded future date

v1 hardcoded `NEED_BY_DATE` (line col 11) to `2027/12/31`. v2 uses the prefix-independent
derived token `${GL_DATE_SLASH}` (today, `YYYY/MM/DD`), so the need-by date is always the day
the run executes and never drifts into the past on a future re-run. A blank or malformed value
here fails the whole load with `ORA-01841` under `DeleteOnLoadFailure = Y`, so the column is
never left empty.

## Bad row

BAD-1 differs from the good row in exactly one field: `UOM_CODE = ZZZ` (line col 14). It passes
SQL*Loader (a syntactically valid string) and is then rejected by Import Requisitions with a
line-level row in `POR_REQ_IMPORT_ERRORS` ("The UOM isn't valid…"). It reaches the interface
and is rejected there — not a pre-validation drop — and never reaches `POR_REQUISITION_HEADERS_ALL`.

## ESS orchestration (unchanged from v1)

`loadAndImportData` (auth `fin_impl`) uploads the zip to UCM (`prc/requisition/import`), runs
one SQL*Loader child per CSV into the three interface tables, then chains **Import
Requisitions** which validates each interface row: valid rows create a requisition in the base
tables, invalid rows stay in the interface with a `POR_REQ_IMPORT_ERRORS` row. The load parent
reaches `SUCCEEDED` once the import child completes; no separate downstream job.

**Auth note (carried from v1):** `calvin.roth` returns HTTP 401 on the ERP Integration SOAP
service on this pod, so the SOAP call runs as `fin_impl`. The ledger is derived correctly from
the requisitioning BU (ParameterList arg 4), which has a primary ledger, so `fin_impl` loads
cleanly. The requisition is created as an unsubmitted draft (`DOCUMENT_STATUS = INCOMPLETE`) —
reaching the base table is the pass bar.

The 8-argument ParameterList: `#NULL,${PREFIX},#NULL,300000046987012,NONE,#NULL,NO,ALL`
(arg 2 = Import Batch ID = `${PREFIX}`; arg 4 = Requisitioning BU id, now a literal).

## Live evidence (v2, via `GOLD_OBJECTS_SUBDIR=objects_seeded`)

**2026-07-20 — LIVE-PROVEN both directions. PASS.**

| Field | Value |
|---|---|
| Prefix | `18526` |
| Pod | `fa-esew-dev28` |
| Load ESS request (fin_impl, loadAndImportData) | `9766258` → SUCCEEDED |
| Hard-coded BU / ledger | `US1 Business Unit` (`300000046987012`) / `300000046975971` |
| Hard-coded preparer / location / UOM / currency / category | `CALVIN.ROTH_esew-dev28@oraclepdemos.com` / `Louisville` / `ECH` / `USD` / `Miscellaneous` |
| Hard-coded charge account | `101/10/68010/120/000/000` |

Good row → base `POR_REQUISITION_HEADERS_ALL` (1/1):

| REQUISITION_NUMBER | REQUISITION_HEADER_ID | DOCUMENT_STATUS |
|---|---|---|
| `18526RT-REQ-G1` | `128995` | `INCOMPLETE` (created draft) |

Bad row → `POR_REQ_IMPORT_ERRORS`, absent from base (1/1):

| REQUISITION_NUMBER | Error |
|---|---|
| `18526RT-REQ-BAD1` | `UOM_CODE=ZZZ: The UOM isn't valid. Verify that the UOM is active. When the UOM isn't the primary UOM of the item in the inventory organization, there must be an active standard UOM conversion or interclass UOM conversion for the provided UOM.` |

## How to run

```bash
cd gold_regression/harness
GOLD_OBJECTS_SUBDIR=objects_seeded python run_object.py Requisitions
```

## Files

- `recipe.json` — FBDI, 3-CSV member list, **no discovery block**, literal 8-arg ParameterList
  (BU id hard-coded), verify block.
- `artifact/PorReq*.csv` — the three templated CSVs (`${PREFIX}` on natural keys + hard-coded
  seeds; `${GL_DATE_SLASH}` for NEED_BY_DATE).
- `Requisitions_gold.zip` — last assembled ready-to-load artifact (prefix 18526).
