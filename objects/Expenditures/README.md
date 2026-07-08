# Expenditures

## Status
E2E LOADED (3/3 regression, including BAD row — pre-validation issue)

## Pipeline
- Module: Projects
- FBDI Template: PjcExpendituresInterface.xlsm
- CSV Filename: PjcTxnXfaceStageAll.csv
- Interface Table: PJC_TXN_XFACE_STAGE_ALL
- UCM Account: prj/projectCosting/import
- ESS Job: /oracle/apps/ess/projects/costing/transactions/onestop,ImportProcessParallelEssJob
- ParameterList: US1 Business Unit,300000046987012,IMPORT_AND_PROCESS,PREV_NOT_IMPORTED,#NULL,#NULL,#NULL,#NULL,#NULL,#NULL,#NULL,{SYSDATE},#NULL,ORA_PJC_DETAIL
- InterfaceDetails ID: 20
- Loader Type: SQLLOADER
- Auth User: fin_impl

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

