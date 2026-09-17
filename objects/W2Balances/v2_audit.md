# W2 Balances — V2 Audit (2026-04-04) — RESOLVED 2026-09-17

## Status: RESOLVED — re-modeled to the correct HDL business object

## Original problem
The generator emitted `PayrollBalanceInitialization.dat` with objects
`BalanceInitialization` + `BalInitializationDetails`. Fusion REJECTED that file name
(16+ variants all failed). It was the wrong/outdated object.

## Correct model (verified 2026-09-17)
Oracle's current HCM Data Loader business object for initializing payroll balances is
**Balance Initialization**, loaded as TWO objects in ONE zip:

- `InitializeBalanceBatchHeader.dat`
  METADATA: `BatchName|UploadDate|LegislativeDataGroupName`
- `InitializeBalanceBatchLine.dat`
  METADATA: `LegislativeDataGroupName|BatchName|LineSequence|PayrollRelationshipNumber|`
  `TermNumber|AssignmentNumber|PayrollName|TaxUnitName|BalanceName|DimensionName|Value|`
  `ContextOneName|ContextOneValue|AreaOne`

Each file is named after its business object (HDL requirement). One run = ONE batch;
every line references the header by `BatchName`. No worker record is repeated. A
"Load Initial Balances" (Transfer Batch) payroll flow is then run in Fusion to apply
the staged batch — a functional post-load step, not part of the HDL file.

### Evidence
- Oracle docs (HCM Data Loading Business Objects, "Steps to Initialize Balances";
  India HRA balances example): the two file names, discriminators, and METADATA above.
  https://docs.oracle.com/en/cloud/saas/human-resources/22c/fahbo/steps-to-initialize-balances.html
  https://docs.oracle.com/en/cloud/saas/human-resources/faldi/example-of-loading-hra-balances-for-india.html
- Live on this pod (--cred fin_impl):
  `HRC_INTEGRATION_KEY_MAP`: `InitializeBalanceBatchHeader` = 7 keys,
  `InitializeBalanceBatchLine` = 13 keys.
  `PAY_BAL_BATCH_HEADERS.BATCH_NAME` is directly queryable (e.g. `LIKE 'DMT%'` returns
  the DMT batches with their `BATCH_ID`), confirming the base table and business key.

## Reconciliation
Base table `PAY_BAL_BATCH_HEADERS`, matched directly on `BATCH_NAME` = the run's
`BatchName` (`<prefix>_W2BAL`) = the TFM `RECON_KEY`; `BATCH_ID` is the Fusion id.
Balance-init batch objects are keyed by `BatchName` (a user key), not by a person
SourceSystemId, so `BATCH_NAME` matching is correct and robust.

## Shared-seed delta REPORTED (not edited here)
`db/seed/dmt_bip_report_tbl.sql` W2Balances row: `RECON_KEY_SQL` should change from
`DMT_UTIL_PKG.PREFIXED(run_prefix, PERSON_NUMBER, 30) || '_BAL'` to `run_prefix || '_W2BAL'`.
(`OBJECT_TYPE`='Balance Initialization', `TFM_TABLE`='DMT_W2_BAL_TFM_TBL',
`FUSION_ID_COLUMN`='FUSION_BALANCE_ID' stay as-is.)
