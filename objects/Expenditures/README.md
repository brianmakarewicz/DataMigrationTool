# Expenditures

## Status
Import-job + ParameterList + unique-batch fix applied (2026-07-20, branch
fix/expenditure-correct-import-job). Good rows now target base table PJC_EXP_ITEMS_ALL.
Live proof pending the owner's full regression rerun. (Prior "3/3 LOADED" was a false
positive — it used the crashing parallel job and 0 rows actually reached base.)

## Pipeline
- Module: Projects
- FBDI Template: PjcExpendituresInterface.xlsm
- CSV Filename: PjcTxnXfaceStageAll.csv
- Interface Table: PJC_TXN_XFACE_STAGE_ALL (base success table: PJC_EXP_ITEMS_ALL)
- UCM Account: prj/projectCosting/import
- ESS Job: /oracle/apps/ess/projects/costing/transactions/onestop,ImportAndProcessTxnsJob
  (the NON-parallel "Import and Process Cost Transactions" job — 10-arg. See the
  Import-job fix note below.)
- ParameterList (10 positions, tilde-delimited):
  `IMPORT_AND_PROCESS~{BU_ID}~ALL~#NULL~#NULL~{TXN_SOURCE_ID}~{DOCUMENT_ID}~#NULL~#NULL~#NULL`
  - Position 2 BU_ID: numeric business-unit id, resolved from lookup BU_NAME_TO_BU_ID
    (config EXPENDITURE_BU_NAME). Never the BU name.
  - Position 6 TXN_SOURCE_ID: numeric transaction-source id, resolved from lookup
    PJC_TXN_SOURCE_NAME_TO_ID keyed by the USER_TRANSACTION_SOURCE the rows carry.
  - Position 7 DOCUMENT_ID: numeric document id, resolved from lookup PJC_DOC_NAME_TO_ID
    keyed by the DOCUMENT_NAME the rows carry.
  - Positions 6 and 7 are import FILTERS, so they must match the source/document each
    interface row names (Time Card/Time Card for the labor fixture, or External
    Miscellaneous/Miscellaneous for the non-labor gold path).
- InterfaceDetails ID: 20
- Loader Type: SQLLOADER
- Auth User: fin_impl

## Import-job fix (2026-07-20) — the reason rows never reached base
The pipeline previously submitted the PARALLEL job
`onestop;ImportProcessParallelEssJob` (14-arg). That job crashes on this pod with
ORA-06502 (character-to-number) in its own parameter parsing every run — the old
ParameterList put the BU NAME and a date string into numeric argument slots, so zero
rows ever costed to base. The gold-proven job is the NON-parallel
`onestop,ImportAndProcessTxnsJob` (10-arg). The fix, in three parts:
1. Seed `db/seed/dmt_erp_interface_options_tbl.sql` row 20 IMPORT_JOB_NAME: only the
   definition name changed, from `ImportProcessParallelEssJob` to
   `ImportAndProcessTxnsJob`. The seed keeps the semicolon storage convention
   (`...onestop;ImportAndProcessTxnsJob`); `get_erp_options` converts the last semicolon
   to a comma at submit time, producing the gold's comma form
   `...onestop,ImportAndProcessTxnsJob` for the loadAndImportData JobName. (Storing a
   comma here would break that converter and yield a leading-comma path.)
2. Loader `dmt_loader_pkg.pkb.sql` Expenditures branch builds the 10-position tilde list
   above. The two numeric ids come from lookups, never hardcoded (design section 7).
3. Two new lookups, PJC_TXN_SOURCE_NAME_TO_ID and PJC_DOC_NAME_TO_ID, populated by
   `DMT_UTIL_PKG.REFRESH_LOOKUPS` at pipeline preflight from Fusion views
   `pjf_txn_sources_vl` and `pjf_txn_document_b`/`pjf_txn_document_vl` (same
   BIP-data-model pattern as the BU, ledger and AR-batch-source lookups).

Before/after generated ParameterList (offline-proven on dmt2-local):
- BEFORE: `US1 Business Unit,300000046987012,IMPORT_AND_PROCESS,PREV_NOT_IMPORTED,#NULL,#NULL,#NULL,#NULL,#NULL,#NULL,#NULL,{SYSDATE},#NULL,ORA_PJC_DETAIL`
- AFTER:  `IMPORT_AND_PROCESS~300000046987012~ALL~#NULL~#NULL~300000049907116~300000049907117~#NULL~#NULL~#NULL`

## Unique BATCH_NAME rule (the second blocker)
Import Costs validates each transaction's batch name is unique
(MESSAGE_NAME=PJC_UNIQUE_BATCH_NAME). If interface rows carry an empty/duplicate
BATCH_NAME the GOOD rows collide with each other and across prefixes and are ALL
rejected. The Expenditures transform now synthesises a deterministic unique BATCH_NAME:
the prefixed ORIG_TRANSACTION_REFERENCE (`{PREFIX}RT-EXP-*`, already unique per row and
stamped with the run prefix), so ALL-mode reruns never collide. The transform also stamps
the run prefix onto ORIG_TRANSACTION_REFERENCE (the base-table verification key). Source
is no longer required to supply a batch name.

## CSV Format Notes
- First field is TRANSACTION discriminator: 'LABOR' or 'NONLABOR' (FILLER in CTL, used as WHEN clause)
- TRANSACTION_TYPE column is NOT in CSV -- set as CONSTANT by CTL based on WHEN clause
- ACCRUAL_FLAG is NOT in CTL -- excluded from CSV
- Date format: YYYY/MM/DD (per CTL: to_date with 'YYYY/MM/DD')
- NONLABOR rows have 4 extra fields (NON_LABOR_RESOURCE*) between ORGANIZATION_ID and QUANTITY
- Trailing fields after ATTRIBUTE10: CONTRACT_NUMBER, CONTRACT_NAME, CONTRACT_ID, FUNDING_SOURCE_NUMBER, FUNDING_SOURCE_NAME, PROJECT_ROLE_NAME, PROJECT_ROLE_ID

## Code References
- STG Table DDL: `schema/tables/60_dmt_pjc_expenditures_stg_tbl.sql`
- TFM Table DDL: `schema/tables/61_dmt_pjc_expenditures_tfm_tbl.sql`
- Validator: `packages/validators/dmt_expenditure_validator_pkg.*`
- Transformer: `packages/transformers/dmt_expenditure_transform_pkg.*`
- FBDI Generator: `packages/generators/fbdi/expenditures/dmt_expenditure_fbdi_gen_pkg.*`
- Results/Reconciliation: `packages/reconciliation/dmt_expenditure_results_pkg.*`
- BIP Data Model/Report: `bip/Expenditures/`

## Reference Files
None in this folder.

## Known Issues
- TRANSACTION_TYPE in STG must be 'LABOR' or 'NONLABOR'. 'Miscellaneous' caused the original ORA-06502 (Fusion tried to process NULL QUANTITY/PERSON_NUMBER).
- ~~BIP reconciliation uses "absence=LOADED" pattern: Fusion purges interface table rows after successful import.~~ **RESOLVED 2026-04-02:** Switched to two-tier BIP (interface + base table). No more absence=LOADED.
- `expenditure_item_id` does NOT exist on `PJC_TXN_XFACE_STAGE_ALL` interface table — removed from BIP query and results package.

## Lessons Learned
- **Never assume absence=LOADED without positive verification.** Two-tier BIP pattern queries both interface AND base tables. If neither has the row, it's FAILED, not silently LOADED.
- **PJC_TXN_XFACE_STAGE_ALL uses status 'P' for Processed (success).** Not 'PROCESSED' or 'SUCCESS'.

## Required Fields for LABOR Expenditures
- TRANSACTION_TYPE: 'LABOR'
- PERSON_NUMBER: valid Fusion person number (e.g., '7', '10')
- QUANTITY: non-null (e.g., 8 for hours)
- EXPENDITURE_TYPE: must match Fusion lookup (e.g., 'Administrative', 'Contract Services')
- PROJECT_NUMBER + TASK_NUMBER: must reference LOADED projects/tasks
- DENOM_RAW_COST + DENOM_CURRENCY_CODE
- ORIG_TRANSACTION_REFERENCE: unique per row

## History
- Code complete. FBDI generation working. Awaiting first Fusion submission.
- 2026-04-01: First Fusion submission attempt. Integration 100000040, prefix 9136.
  - Fixed: Removed ACCRUAL_FLAG from CSV (not in Fusion CTL).
  - Fixed: Added PROJECT_ROLE_NAME and PROJECT_ROLE_ID empty fields to CSV tail.
  - Fixed: First CSV field now outputs 'LABOR'/'NONLABOR' discriminator instead of TRANSACTION_TYPE value.
  - Fixed: Validator was incorrectly applying dep_prefix to PROJECT_NUMBER before checking STG table.
  - Load ESS 9393013 SUCCEEDED (SQL*Loader loaded 2 rows to interface table).
  - Import ESS 9393018 ERROR: ORA-06502 character to number conversion in import processing.
- 2026-04-02: Fixed test data and BIP, achieved E2E LOADED. Integration 100000043, prefix 9139.
  - Root cause of ORA-06502: test data had TRANSACTION_TYPE='Miscellaneous' (should be LABOR), NULL PERSON_NUMBER, NULL QUANTITY.
  - Fixed STG data: TRANSACTION_TYPE=LABOR, PERSON_NUMBER=7/10, QUANTITY=8/16, EXPENDITURE_TYPE=Administrative.
  - Removed expenditure_item_id from BIP data model (column doesn't exist on interface table).
  - Added absence=LOADED fallback to results package.
  - BIP deployed to /Custom/DMT/Expenditures/. 2/2 LOADED.
- 2026-04-02: BIP audit — switched to two-tier reconciliation.
  - Tier 1: PJC_TXN_XFACE_STAGE_ALL (interface table errors/status)
  - Tier 2: PJC_EXP_ITEMS_ALL (base table, positive confirmation)
  - Added P_IMPORT_ESS_ID parameter to BIP data model
  - Eliminated absence=LOADED fallback. Unmatched GENERATED rows now FAILED with RECONCILE_ERROR.
- 2026-04-02: Regression test — 0L/6F. BIP working — Fusion returned TRANSACTION_STATUS_CODE='P' (Processed), now recognized as success. All rows marked FAILED because they were found in the interface table with status P but the reconciliation code initially didn't recognize P. Fixed: P added to success list.
- 2026-04-04 (DB-18): Regression confirmed 3L/0F. All 3 rows LOADED including BAD row (PROJECT_NUMBER='NOPROJ999').
  - **PRE-VALIDATION BUG:** BAD row with non-existent project should fail upstream dependency check but loads successfully. Validator VALIDATE_PRE_TRANSFORM is not catching it. Needs investigation.
  - Working GOOD rows: TRANSACTION_TYPE=LABOR, PERSON_NUMBER=7/10, EXPENDITURE_TYPE=Administrative, BU=US1 Business Unit.

## Known-good Fusion record & mapping (2026-07-15)

### The core problem
Our expenditure rows land in the interface staging table `PJC_TXN_XFACE_STAGE_ALL`
with `TRANSACTION_STATUS_CODE = 'P'` and then never move to the base table
`PJC_EXP_ITEMS_ALL`. We had been reading 'P' as "Processed = success". That reading is
wrong here. For these staging rows 'P' means the SQL*Loader placed the row in staging
(pending), not that the Import Project Costs process accepted and costed it. A live count
proves it: **0 rows** with `ORIG_TRANSACTION_REFERENCE LIKE 'RT-EXP-%'` exist in
`PJC_EXP_ITEMS_ALL`. Every one of our 60 staging rows across all runs has a NULL
transaction source and never posted.

### Root cause
The Import Project Costs process needs each row to name a valid **transaction source
document** and **document entry**. Our staging rows leave all three of these blank:
`USER_TRANSACTION_SOURCE`, `DOCUMENT_NAME`, `DOC_ENTRY_NAME`. Without a document and
document entry, the process cannot map the row to a costing document, so it silently
leaves it in staging. This is the single missing piece — projects, tasks, expenditure
type, person, quantity, BU, and currency in our test data are otherwise fine.

Proof — our staging rows (live query result):

    OTR=RT-EXP-RTPRJ001  STATUS=P  TXNTYPE=LABOR  USER_TRANSACTION_SOURCE=(blank)
    DOCUMENT_NAME=(blank)  DOC_ENTRY_NAME=(blank)  EXPENDITURE_TYPE=Administrative
    PROJECT_NUMBER=9629RTPRJ001  TASK_NUMBER=RTPRJ001.1  PERSON_NUMBER=7

### A real expenditure that DID post to base (PCS10001, project "Hilman HCM Implementation")
Two flavours exist on that project. The labor flavour is the one to mimic:

| Attribute | Real value (labor / Straight Time) |
|---|---|
| Project number / name | PCS10001 / Hilman HCM Implementation |
| Task number | 1.0 |
| System linkage function | ST (Straight Time labor) |
| Expenditure type | "Professional" (expenditure_type_id 300000047429543) |
| Expenditure item date | 2013-07-07 |
| Quantity / UOM | 40 / HOURS |
| Expenditure organization | "Consulting South US" (org id 300000047013640) |
| Business unit | US1 Business Unit (org_id/bu_id 300000046987012) |
| Person type / person | EMP / person_number 712 (incurred_by_person_id 300000049471069) |
| Document | "Timecard" (document_id 300000049854173) |
| Document entry | "Straight Time" (system_linkage_function ST) |
| Currency | USD |

The decisive difference from our rows: the real row carries a **document** and a
**document entry**. Ours carry neither.

### Valid documents / document entries for third-party FBDI import (from setup)
`PJF_TXN_DOCUMENT_VL` (documents) joined to `PJF_TXN_DOC_ENTRY_VL` (entries) gives the
allowed combinations. The two that matter:

| Document name | Document entry name | System linkage | Use for |
|---|---|---|---|
| Miscellaneous | Miscellaneous | PJ | non-labor / external actual cost (canonical FBDI third-party source) |
| Time Card | Straight Time | ST | labor with a person |

The `Miscellaneous / Miscellaneous (PJ)` pair is the safest, guaranteed-importable
third-party source. Its `IMPORT_COST_ACC_FLAG = N`, so the import will cost the row
(what we want for raw external costs).

### The exact test-data change needed (in `insert_regression_test_data.py`, section 27)
Add the three document columns to both the GOOD and BAD expenditure INSERTs. Two options:

Option A — keep it labor (mirror the real Timecard row). Add to the column list and
values:

    ..., DOCUMENT_NAME, DOC_ENTRY_NAME
    ..., 'Time Card', 'Straight Time'

and keep TRANSACTION_TYPE 'LABOR', PERSON_NUMBER a real EMP, QUANTITY in hours.
(Note: verify "Time Card"/"Straight Time" is enabled for third-party import on this
instance before relying on it — labor documents are often native-only.)

Option B — switch to the canonical Miscellaneous third-party path (lowest risk). For
each GOOD row use:

    TRANSACTION_TYPE   -> 'NONLABOR'   (PJ linkage, non-labor)
    DOCUMENT_NAME      -> 'Miscellaneous'
    DOC_ENTRY_NAME     -> 'Miscellaneous'
    EXPENDITURE_TYPE   -> a non-labor expenditure type valid on the project/task
    PERSON_NUMBER      -> leave NULL (PJ non-labor does not require a person)
    QUANTITY / UOM     -> a non-labor quantity + UOM the expenditure type allows

Whichever option: the BAD row should stay BAD by keeping its invalid EXPENDITURE_TYPE
('BadValue') OR non-existent project, but it too must carry DOCUMENT_NAME / DOC_ENTRY_NAME
so the failure is attributed to the type/project, not to the still-missing document.

Recommendation: **Option B (Miscellaneous / PJ)** is the more reliable path to reach the
base table, because the Miscellaneous document is the standard, always-import-enabled
third-party source. Confirm the chosen non-labor expenditure type is chargeable on
RTPRJ001/RTPRJ002 tasks before running.

### Reusable discovery queries (read-only, via scripts/fusion_bip_query.py --cred fin_impl)
Real posted labor expenditure:

    SELECT pv.segment1, pv.name, tv.element_number, ei.expenditure_type_id,
           ei.expenditure_item_date, ei.quantity, ei.unit_of_measure,
           ei.expenditure_organization_id, ei.org_id, ei.system_linkage_function,
           ei.document_id, ei.doc_entry_id, ei.incurred_by_person_id, ei.person_type
      FROM pjc_exp_items_all ei
      JOIN pjf_projects_all_vl pv ON pv.project_id=ei.project_id
      JOIN pjf_proj_elements_vl tv ON tv.proj_element_id=ei.task_id
     WHERE ei.system_linkage_function='ST' AND ROWNUM<=3

Expenditure type name:  SELECT expenditure_type_name FROM pjf_exp_types_tl
     WHERE expenditure_type_id=:id AND language='US'
Expenditure org name:   SELECT name FROM hr_organization_units WHERE organization_id=:id
Business unit name:      SELECT bu_name FROM fun_all_business_units_v WHERE bu_id=:id
Person number:          SELECT person_number FROM per_all_people_f WHERE person_id=:id AND ROWNUM<=1

Valid documents:   SELECT document_id, document_name, document_code FROM pjf_txn_document_vl
Valid doc entries: SELECT document_id, doc_entry_name, doc_entry_code, system_linkage_function
                     FROM pjf_txn_doc_entry_vl WHERE system_linkage_function IN ('ST','PJ')

Our own staging rows: SELECT orig_transaction_reference, transaction_status_code,
     transaction_type, user_transaction_source, document_name, doc_entry_name,
     expenditure_type, project_number, task_number, person_number
     FROM pjc_txn_xface_stage_all WHERE orig_transaction_reference LIKE 'RT-EXP-%'
Confirm none reached base: SELECT COUNT(*) FROM pjc_exp_items_all
     WHERE orig_transaction_reference LIKE 'RT-EXP-%'   -- returns 0

### Uncertainty
- I could not read an error message from the interface table: `PJC_TXN_XFACE_STAGE_ALL`
  has no error-text column, and there was no rejection log to pull. The root cause
  (missing document / document entry) is inferred from (a) our rows carrying NULL source,
  (b) 0 rows reaching base, and (c) every real posted row carrying a document + entry.
  It is a strong inference, not a message quoted back from Fusion.
- Whether the labor "Time Card / Straight Time" document is enabled for third-party FBDI
  import on THIS instance was not confirmed. That is why Option B (Miscellaneous) is
  recommended.
- The generator/transform packages were not inspected here; the fix may also require the
  FBDI generator and CTL to emit the DOCUMENT_NAME / DOC_ENTRY_NAME columns. Verify the
  CTL includes those positions before changing only the seed data.

