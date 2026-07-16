# Requisitions

## Status
E2E LOADED (18 LOADED)

## Pipeline
- Module: Procurement
- FBDI Template: PorReqHeadersInterface.xlsm
- Interface Tables: POR_REQ_HEADERS_INTERFACE, POR_REQ_LINES_INTERFACE, POR_REQ_DISTS_INTERFACE
- UCM Account: prc/requisition/import
- ESS Job: RequisitionImportJob
- ParameterList: 8-arg format; see memory/project_c012_requisitions.md
- Loader Type: SQLLOADER
- Auth User: calvin.roth
- Pipeline: Single-zip pipeline

## Code References
- STG Table DDL (Headers): `schema/tables/162_dmt_por_req_headers_stg_tbl.sql`
- STG Table DDL (Lines): `schema/tables/164_dmt_por_req_lines_stg_tbl.sql`
- STG Table DDL (Distributions): `schema/tables/166_dmt_por_req_dists_stg_tbl.sql`
- TFM Table DDL (Headers): `schema/tables/163_dmt_por_req_headers_tfm_tbl.sql`
- TFM Table DDL (Lines): `schema/tables/165_dmt_por_req_lines_tfm_tbl.sql`
- TFM Table DDL (Distributions): `schema/tables/167_dmt_por_req_dists_tfm_tbl.sql`
- Validator: `packages/validators/dmt_req_validator_pkg.*`
- Transformer: `packages/transformers/dmt_req_transform_pkg.*`
- FBDI Generator: `packages/generators/fbdi/requisitions/dmt_req_fbdi_gen_pkg.*`
- Results/Reconciliation: `packages/reconciliation/dmt_req_results_pkg.*`
- BIP Data Model/Report: `bip/Requisitions/`

## Reference Files
None in this folder.

## Known Issues
- **Requisitions must run as calvin.roth (PO_USERNAME).** Running as fin_impl (FUSION_USERNAME) causes `po_core_s.get_ledger_id` ORA-01403 and Import ESS returns "You must enter a valid ledger ID." Fixed 2026-04-07: added Requisitions to per-CEMLI credential override in `run_one_object_type`. Credentials also passed through to POLL_ESS_JOB (l_ess_user/l_ess_pass promoted to function scope).
- **UOM_CODE is 'ECH' (not 'Ea').** Verified 2026-04-16: `ECH` exists in `inv_units_of_measure` and loads successfully. 'Ea' does NOT exist on this instance.
- **Header errors ARE in por_req_import_errors (INTERFACE_TYPE='HEADER').** Verified 2026-04-16: errors join via `e.interface_id = h.req_header_interface_id`. BIP XDM Source 1 captures these with `[HDR]` prefix. Caveat: if the BU is completely invalid (NONEXISTENT_BU_99), the import rejects the row pre-validation with `process_flag=NULL` and writes NO error rows — these fall through to "Unrecognized interface status: NULL".

## History
- E2E LOADED confirmed with 18 rows reaching LOADED status in Fusion.
- 8-arg ParameterList documented in memory/project_c012_requisitions.md.
- 2026-04-01: ALL mode code review found a bug in `dmt_loader_pkg.pkb`. The ParameterList lookup for Requisitions (line ~1048) queried `WHERE STATUS IN ('NEW', 'RETRY')` but runs BEFORE `reset_scenario_status` (Step 1.4) sets rows to RETRY. In ALL mode, if all rows are TRANSFORMED/LOADED/FAILED, the SELECT INTO raises NO_DATA_FOUND and crashes the run. Fix: widened the ParameterList query to accept any status when `p_run_mode='ALL'`, and added scenario_id filter for correctness.
- 2026-04-01: ALL mode fix verified on ATP (integration_id 100000025). Starting state: 3 headers, 3 lines, 3 dists all in LOADED status. Pipeline ran end-to-end: reset to RETRY, re-transformed, generated FBDI zip (892 bytes), submitted to Fusion (Load ESS 9391727 SUCCEEDED in 60s), Import ESS 9391732 SUCCEEDED, BIP reconciliation completed. Results: 1 header LOADED, 2 headers FAILED (Fusion rejection), cascaded to child lines/dists. CONVERSION_MASTER updated: total=9, valid=3, loaded=3, failed=6, status=FAILED. The fix works correctly -- ALL mode no longer crashes on non-NEW/RETRY rows.
- 2026-04-02: BIP audit — switched to two-tier reconciliation.
  - Tier 1: POR_REQ_HEADERS_INTERFACE_ALL (interface table errors/status)
  - Tier 2: POR_REQUISITION_HEADERS_ALL (base table, positive confirmation)
  - Added P_IMPORT_ESS_ID parameter to BIP data model
  - Eliminated absence=LOADED fallback. Unmatched GENERATED rows now FAILED with RECONCILE_ERROR.
- 2026-04-02: Regression test — 0L/18F. BIP working (Tier 1 INTERFACE found rows with status ERROR). Test data values invalid for this Fusion instance. Need valid REQ_BU_NAME, PREPARER_EMAIL, etc.
- 2026-04-07 (DB-27): Credential fix (calvin.roth via PO_USERNAME). UOM ECH→Ea. Still FAILED in Fusion — unknown rejection, needs import error report.

## Lessons Learned
- **Never assume absence=LOADED without positive verification.** Two-tier BIP pattern queries both interface AND base tables. If neither has the row, it's FAILED, not silently LOADED.
- **POLL_ESS_JOB needs same credentials as SUBMIT_LOAD.** When using per-CEMLI credentials (calvin.roth for Requisitions), the credentials must be passed to both POLL_ESS_JOB calls (Load poll + Import poll). Without this, getESSJobStatus returns HTTP 500.
- **por_req_import_errors only contains LINE-level errors.** Header-level rejections produce `process_flag=NULL` with no corresponding error rows. The BIP DM uses `[HDR]` and `[LINE]` prefixes but `[HDR]` will never fire for requisitions.
- **BIP report deployment must include xml in outputFormat.** The FBT_BIP_PKG.DEPLOY_REPORT default template only supports html/pdf/rtf/xlsx/pptx. For DMT reconciliation (which uses `attributeFormat=xml`), the report must be deployed with `outputFormat="xml,html,pdf,rtf,xlsx,pptx"`.
- **process_error column does NOT exist on por_req_lines_interface_all.** The original XDM Source 3 (inline process_error) was wrong and caused ORA-00904. Removed 2026-04-16.
- **Valid test data for demo instance:** UOM=ECH, Location=Louisville, BU=US1 Business Unit, Preparer=CALVIN.ROTH_esew-dev28@oraclepdemos.com, Charge Account=101/10/68010/120/000/000.

## Known-good Fusion record & mapping (2026-07-15)

### The real record we mimic (a genuinely APPROVED requisition on the demo instance)
Queried live via `scripts/fusion_bip_query.py` (read-only, fin_impl). This is a fully
created and approved requisition in the SAME business unit our test data uses:

| Field | Real value |
|---|---|
| Requisition header id | 300000184253598 |
| Requisition number | 204038 |
| Requisitioning BU (`req_bu_id` → name) | **US1 Business Unit** |
| Document status | **APPROVED** |
| Line item description | 20" Flat panel: Dell Monitors;Dell 20 Monitor - P2016 ... |
| UOM code | zzu (a real item's UOM; our fabricated line uses ECH, which also imports fine) |
| Quantity / Unit price / Currency | 1 / 228.99 / USD |
| Destination type | EXPENSE |
| Deliver-to location | **Seattle** (our test data uses Louisville — Louisville also imports OK) |
| Destination organization | **Seattle** |
| Category | **Computer Supplies** (category_id 300000047292806) |
| Charge account (code combination) | **101/10/60540/120/000/000** (note segment3 = 60540; our test data uses 68010, which also imports OK) |

### What actually happened to OUR run-155 GOOD requisition (the real root cause)
Our GOOD requisition was NOT rejected. It imported cleanly and reached the base table.
- Interface header `155_RQHDR_100000244` (req number `10039RT-REQ-001`): `PROCESS_FLAG = SUCCESS`.
- Interface line `155_RQLN_100000292` (UOM=ECH, location=Louisville): `PROCESS_FLAG = SUCCESS`.
- Base table `POR_REQUISITION_HEADERS_ALL`: row exists, `requisition_header_id = 128060`,
  `requisition_number = 10039RT-REQ-001`.
- **BUT its `document_status = INCOMPLETE`, not APPROVED.** Every `RT-REQ-001` row across
  every run is INCOMPLETE. The requisition is created as an unsubmitted draft.

**Root cause is in our own transformer, not Fusion.** `dmt_req_transform_pkg.pkb.sql`
(around lines 107-111) downgrades the header status:
```
CASE WHEN s.DOCUMENT_STATUS = 'APPROVED' AND s.APPROVER_EMAIL_ADDR IS NULL
     THEN 'INCOMPLETE'
     ELSE s.DOCUMENT_STATUS
END
```
Our seed data (`scripts/insert_regression_test_data.py`, section 35) sets
`DOCUMENT_STATUS = 'APPROVED'` but never sets `APPROVER_EMAIL_ADDR`. So the transformer
downgrades every GOOD requisition to INCOMPLETE, the FBDI carries INCOMPLETE, and the
import lands an INCOMPLETE draft. This is why the reconciler could not confirm a GOOD
row as APPROVED/LOADED to match a real record. Fusion is behaving correctly: it will not
approve a requisition that arrives with no approver.

### The precise test-data change needed (propose — do NOT edit the seed script here)
In `scripts/insert_regression_test_data.py`, section 35 (Requisition Headers), the GOOD
header rows (`RT-REQ-G1`, `RT-REQ-G2`) must supply an approver email. Add
`APPROVER_EMAIL_ADDR` to the INSERT column list and pass the same valid demo email used
for the preparer:

- `APPROVER_EMAIL_ADDR = 'CALVIN.ROTH_esew-dev28@oraclepdemos.com'`
  (verified live: this email exists in `per_email_addresses` on the demo instance).

Set it for the two GOOD headers (and the BADLINE/BADDIST headers, whose header must be
valid). Leave the BADHDR row as-is (its bad preparer email is the intended header error).
With a valid approver present, the transformer keeps `DOCUMENT_STATUS = 'APPROVED'`, the
FBDI carries APPROVED, and the requisition should submit into approval and reach an
APPROVED (or IN PROCESS) base-table state that matches the real record.

**Uncertainty / caveat:** Self-approval by the preparer may or may not clear on this
instance (approval-hierarchy dependent). If APPROVED still does not stick after adding
the approver, the fallback is to accept `INCOMPLETE` as a legitimate LOADED outcome for
requisitions (the row IS created in the base table) and update the reconciler's success
criterion accordingly — but try the approver first, since a real approved req is the
stated target. The line/dist reference values (UOM=ECH, Louisville, charge account
101/10/68010/120/000/000) are already accepted by import and need no change.

### Reusable discovery queries (read-only, fin_impl)
```sql
-- a real APPROVED requisition in US1 BU, with resolved BU/status
SELECT h.requisition_header_id, h.requisition_number, h.document_status,
       (SELECT o.name FROM hr_all_organization_units_vl o WHERE o.organization_id=h.req_bu_id) req_bu
FROM   por_requisition_headers_all h
WHERE  h.document_status='APPROVED' AND ROWNUM<=5;

-- line detail for a chosen header (location/org names, category id, uom, qty, price)
SELECT l.line_number, l.item_description, l.uom_code, l.quantity, l.unit_price,
       l.currency_code, l.destination_type_code,
       (SELECT loc.location_code FROM hr_locations_all loc WHERE loc.location_id=l.deliver_to_location_id) loc,
       (SELECT o.name FROM hr_all_organization_units_vl o WHERE o.organization_id=l.destination_organization_id) dest_org,
       l.category_id
FROM   por_requisition_lines_all l
WHERE  l.requisition_header_id = 300000184253598;

-- charge account for the distribution
SELECT d.distribution_number,
       (SELECT g.segment1||'/'||g.segment2||'/'||g.segment3||'/'||g.segment4||'/'||g.segment5||'/'||g.segment6
          FROM gl_code_combinations g WHERE g.code_combination_id=d.code_combination_id) charge_account
FROM   por_req_distributions_all d
WHERE  d.requisition_line_id IN (SELECT requisition_line_id FROM por_requisition_lines_all
                                 WHERE requisition_header_id = 300000184253598);

-- OUR rows: interface status + whether they reached the base table
SELECT interface_header_key, requisition_number, batch_id, process_flag
FROM   por_req_headers_interface_all WHERE interface_header_key LIKE '155\_%' ESCAPE '\';
SELECT requisition_number, requisition_header_id, document_status
FROM   por_requisition_headers_all WHERE requisition_number LIKE '%RT-REQ-001';
```

### One-line summary
The requisition pipeline works: our GOOD row imports SUCCESS and is created in
`POR_REQUISITION_HEADERS_ALL`. It just lands as INCOMPLETE because our own transformer
downgrades APPROVED→INCOMPLETE when no approver is supplied, and the seed data omits
`APPROVER_EMAIL_ADDR`. Add the approver email to the GOOD seed headers.
