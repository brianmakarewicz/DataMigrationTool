# Billing Events

## Status
E2E LOADED (3/3 regression)

## Pipeline
- Module: Projects
- FBDI Template: PjbBillEventsInterface.xlsm
- CSV Filename: PjbBillingEventsXface.csv
- Interface Table: PJB_BILLING_EVENTS_INT
- UCM Account: prj/projectBilling/import
- ESS Job: /oracle/apps/ess/projects/billing/transactions,ImportBillingEventJob
- ParameterList: #NULL
- InterfaceDetails ID: 68
- Loader Type: SQLLOADER
- Auth User: fin_impl

## Code References
- STG Table DDL: `schema/tables/58_dmt_pjb_bill_events_stg_tbl.sql`
- TFM Table DDL: `schema/tables/59_dmt_pjb_bill_events_tfm_tbl.sql`
- Validator: `packages/validators/dmt_billing_event_validator_pkg.*`
- Transformer: `packages/transformers/dmt_billing_event_transform_pkg.*`
- FBDI Generator: `packages/generators/fbdi/billing/dmt_billing_event_fbdi_gen_pkg.*`
- Results/Reconciliation: `packages/reconciliation/dmt_billing_event_results_pkg.*`
- BIP Data Model/Report: `bip/BillingEvents/`

## Reference Files
None in this folder.

## Reconciliation Strategy (Three-Tier)
1. **Tier 1: BIP → PJB_BILLING_EVENTS_INT** (interface table) — always purged after import (MOS 2534525.1). Will return 0 rows in practice. Kept for completeness.
2. **Tier 2: BIP → PJB_BILLING_EVENTS** (base table) — catches successfully LOADED rows via prefix-based SOURCEREF match.
3. **Tier 3: Import Report XML** — downloaded from the `ImportBillingEventReportJob` child ESS job output. Contains G_6 (full interface row snapshot with IMPORT_STATUS) + G_7 (per-row error codes/messages). This is the primary error source since the interface table is always purged.

Report child job found via: `DMT_ESS_UTIL_PKG.CAPTURE_REPORT_ESS_JOB` which looks up the exact job definition (`ImportBillingEventReportJob`) from `DMT_ERP_INTERFACE_OPTIONS_TBL.REPORT_JOB_DEF`, then queries `DMT_ESS_CHILD_JOB_RPT.xdo` with the exact `P_JOB_DEF`. Captured into `DMT_ESS_JOB_TBL` as a logical child of the import job for APEX UI display.

## Known Issues
- Date format: COMPLETION_DATE uses MM/DD/YYYY per Fusion CTL (to_date with MM/DD/RRRR).
- **BIP Tier 2: pjb_billing_events base table does NOT populate request_id from import job.** Same pattern as Projects (REQUEST_ID NULL). Prefix-based SOURCEREF match used instead.
- **Import ESS SUCCEEDED but import_status NULL on interface rows.** The ImportBillingEventJob ran and completed but didn't update the billing event rows. May be a parameter issue — current ParameterList is '#NULL'. Needs ESS parameter discovery.

## History
- Code complete. FBDI generation working. Awaiting first Fusion submission.
- 2026-04-01: First successful Fusion submission. Integration 100000037, prefix 9133.
  - Fixed: Removed 2 empty placeholder fields (INT_REC_ID, BATCH_ID) from CSV. CTL generates these as EXPRESSION/CONSTANT.
  - Fixed: Changed COMPLETION_DATE format from YYYY/MM/DD to MM/DD/YYYY.
  - Fixed: Validator was incorrectly applying dep_prefix to PROJECT_NUMBER before checking STG table. STG stores unprefixed values.
  - Load ESS 9392985 SUCCEEDED, Import ESS 9392990 SUCCEEDED.
  - 3 TFM rows at GENERATED (BIP not deployed). 3 test billing events reached Fusion.
- 2026-04-02: BIP deployed, reconciliation complete. 3/3 LOADED.
  - Deployed BIP report to /Custom/DMT/BillingEvents/ via deploy_bip_reports.py.
  - Added absence=LOADED fallback to results package (interface table purged after success).
  - All 3 billing events confirmed LOADED in Fusion.
- 2026-04-02: BIP audit — switched to two-tier reconciliation.
  - Tier 1: PJB_BILLING_EVENTS_INT (interface table errors/status)
  - Tier 2: PJB_BILLING_EVENTS (base table, positive confirmation with BILLING_EVENT_ID)
  - Added P_IMPORT_ESS_ID parameter to BIP data model
  - Eliminated absence=LOADED fallback. Unmatched GENERATED rows now FAILED with RECONCILE_ERROR.
- 2026-04-02: Regression test — 0L/6F. RECONCILE_ERROR (0 rows from both tiers). Data didn't reach PJB_BILLING_EVENTS_INT — likely FBDI/SQL*Loader rejection. Test data values need fixing.
- 2026-04-03 (DB-17): **Empty CLOB crash fixed.** FBDI generator now raises -20101 when no STAGED rows exist instead of passing empty CLOB to UTL_ZIP. This was crashing the RUN_PROJECT_PIPELINE when Projects loaded but no billing events data existed.
- 2026-04-04 (DB-18): **Regression LOADED 3/3.**
  - Root cause of 0L/6F: contracts C10026/SC0020 don't exist on demo instance. Import ESS SUCCEEDED but all 3 rows rejected with PJB_INVALID_CONTRACT. Interface table purged after processing.
  - Fixed: CONTRACT_NUMBER to C10028/C10001 (active Sell: Project Lines Soft Limit in US1 BU).
  - Fixed: CONTRACT_TYPE_NAME from `Sell: Project` to `Sell: Project Lines Soft Limit`.
  - Fixed: Added `COMPLETE` to success status list in dmt_billing_event_results_pkg (Fusion returns COMPLETE, not COMPLETED, for billing events).
  - Regression run iid=100000044: 3L/0F. All 3 rows confirmed LOADED via BIP two-tier.
  - **PRE-VALIDATION BUG:** BAD row (NULL CONTRACT_NUMBER) also loads — pre-validation should catch NULL required fields.
- 2026-04-07 (DB-27): BIP Tier 2 updated with P_PREFIX param and sourceref subquery. Results package updated. Data reaches interface table but import_status NULL.
- 2026-04-08 (DB-30): **Root cause found — interface table ALWAYS purged (MOS 2534525.1).** Both success AND failure rows deleted after ImportBillingEventJob completes. Tier 1 always returns 0 rows. Tier 2 sourceref subquery through interface table also broken (purged). Fixed BIP query to prefix-based SOURCEREF matching directly on PJB_BILLING_EVENTS. Deployed to Fusion.
- 2026-04-08 (DB-30): **Test data issue identified.** Import validates contracts (C10028/C10001 valid_flag=Y) but rows still don't reach base table. Cause: test PROJECT_NUMBER values (RTPRJ001/RTPRJ002) are DMT regression projects that don't exist in Fusion. Billing events require project to exist in Fusion AND be linked to the contract via PJB_CNTRCT_PROJ_LINKS. Need to use real Fusion project numbers linked to these contracts.
- 2026-04-09 (DB-33): **Three-tier reconciliation wired up.** Added Import Report XML parsing (Tier 3) from ImportBillingEventReportJob ESS output. XML structure: G_6 per interface row (SOURCEREF, IMPORT_STATUS), G_7 nested per-row errors (ERROR_CODE_S3, MESSAGE_TEXT_S3). Report child job found via ESS_CHILD_JOB_RPT BIP query. Verified on ESS job 9436359 (report for import 9436358): 3 rows with PJB_TASK_NOT_LINKED / PJB_EVT_INVALID_TYPE / FND_CMN_CMPLT_FLDS errors parsed correctly.

## Lessons Learned
- **Never assume absence=LOADED without positive verification.** The original BIP query returned 0 rows and assumed all rows were imported. The two-tier pattern queries both interface AND base tables — if neither has the row, it's marked FAILED, not silently LOADED.
- **FBDI generator must guard against empty CLOBs.** When no STAGED rows exist for the integration_id, `gen_billing_events_csv` returns an empty CLOB. Passing this to `UTL_ZIP.add1file` crashes. Fixed in DB-17: short-circuit with `RAISE_APPLICATION_ERROR` before zip creation when `DBMS_LOB.GETLENGTH(csv) = 0`.
- **BillingEvents runs inside RUN_PROJECT_PIPELINE after Projects.** If Projects has 0 LOADED rows, the pipeline skips BillingEvents entirely. This is correct — billing events reference projects that must exist in Fusion first.
- **Contract numbers must exist on the Fusion instance.** Original regression data used C10026/SC0020 (non-existent). Fixed to C10028/C10001 (active Sell:Project Lines Soft Limit contracts in US1 BU).
- **PJB_BILLING_EVENTS_INT is ALWAYS purged after import.** Both accepted and rejected rows are deleted. Tier 1 BIP query against this table will always return 0 rows post-import. Only viable reconciliation is Tier 2 prefix-based SOURCEREF match on PJB_BILLING_EVENTS base table.
- **Billing events require project-contract linkage.** The project referenced in the billing event must exist in Fusion AND be linked to the contract line via PJB_CNTRCT_PROJ_LINKS. Import validates contracts first (valid_flag=Y), then silently rejects events with unlinked projects.
- **ImportBillingEventReportJob output has rejection details.** The child ESS job generates a BIP XML report with per-row rejection reasons. XML structure: `G_6` = one row per interface record (SOURCEREF, IMPORT_STATUS, all FBDI columns), `G_7` nested under G_6 = per-row error codes (ERROR_CODE_S3, MESSAGE_TEXT_S3). This is the authoritative error source — the interface table is purged. Parsed by `parse_import_report` in the results package via `GET_ESS_OUTPUT_XML`.
- **Fusion returns `COMPLETE` as load_status for billing events.** Added to the success list in results package (DB-18). Prior list had `COMPLETED` but not `COMPLETE`.
- **Report child ESS job is NOT a Fusion-modeled child.** `parentrequestid = 0` in ESS_REQUEST_HISTORY. Found via proximity query (requestid > import_ess_id with exact job definition match). Stored in `DMT_ESS_JOB_TBL` with `PARENT_REQUEST_ID = import_ess_id` for UI display.
- **Use exact job definitions, not `%Report%` wildcards.** The proximity-based BIP query (`requestid > X AND definition LIKE '%Report%'`) picks up unrelated report jobs from other CEMLIs. Solution: store the exact report job definition in `DMT_ERP_INTERFACE_OPTIONS_TBL.REPORT_JOB_DEF` and use it as `P_JOB_DEF`. CEMLIs without a seeded value skip the lookup entirely.
