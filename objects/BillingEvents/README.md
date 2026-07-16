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

## Known-good Fusion record & mapping (2026-07-15)

**Goal:** copy a real, already-accepted billing event and re-submit it for $1 so the GOOD
regression row reaches the PJB_BILLING_EVENTS base table (Rule #1).

### The proven-good record (copy this)
Contract **C10001** has SEVEN real accepted billing events in Fusion. Every one of them uses
the same contract line, project and currency:

| Attribute | Value | Fusion id |
|---|---|---|
| Contract number | **C10001** (status ACTIVE) | contract_id 300000137... (resolved by number) |
| Contract line number | **1** | contract_line_id 300000060778404 |
| Project number | **PCS10001** | project_id 300000058778835 |
| Task number | **NULL** (no task on any accepted event) | task_id NULL |
| Business unit / org | US1 BU | org_id 300000046987012 |
| Currency | **USD** | |
| Event type code (internal) | I (invoice event) | |
| Example accepted amount | 7500.00 USD (events 1-6) | |

A second fully-proven contract is **C10013 / line 1 / project PCS10013 / USD** (org
300000046987012), which also has a real accepted event (event 1, 11268.49 USD, project_id
300000137558858). Either works; C10001 has the most accepted history, so prefer it.

### Why our GOOD rows fail with PJB_TASK_NOT_LINKED — uncertainty flagged
Both of our current GOOD rows point at combos whose project-to-contract-line link DOES exist
in `PJB_CNTRCT_PROJ_LINKS`, verified live:
- C10001 / line 1 / PCS10001 — link present ✔ (and has 7 accepted events) — this row is fine.
- C10028 / line 1 / PCS10028 — link present ✔, but C10028 has NO accepted billing events, and
  I could not positively confirm the same USD/US1 setup end to end. This is the weaker of the two.

So the linkage table alone does not explain PJB_TASK_NOT_LINKED for our rows. The remaining
likely causes (not yet isolated to a single field on the live instance):
1. **EVENT_TYPE_NAME mismatch.** Our rows send 'Percent Complete Billing' / 'Percent Spent
   Billing'. Real accepted events carry internal event_type_code 'I'. If the type name we send
   is not a billing (invoice) event type tied to this contract line, the import can reject the
   line as not linked to the contract/task. The name-to-code mapping was NOT confirmed live
   (the PJB event-type name table was not found under the guessed names).
2. **Amount/currency edge:** accepted events are all USD; keep USD.
3. **C10028 is unproven** — swapping it for a second copy of the C10001 combo removes the one
   combo we could not fully verify.

### The exact test-data change to make (do NOT edit the seed here — proposed only)
In `scripts/insert_regression_test_data.py`, section 28 (Billing Events), replace the two GOOD
rows so BOTH mimic the proven C10001 record, at **$1**, keeping TASK_NUMBER NULL:

```python
for src_ref, contract_num, contract_line, proj_num, task_num, evt_type, amount in [
    # Both copy the proven-good C10001 / line 1 / PCS10001 record, $1 each.
    ("RT-BE-G1", "C10001", "1", "PCS10001", None, "Percent Complete Billing", 1.00),
    ("RT-BE-G2", "C10013", "1", "PCS10013", None, "Percent Spent Billing",    1.00),
]:
```

Notes:
- Amount **1.00** (the "$1 duplicate" the owner asked for). Currency stays 'USD',
  ORGANIZATION_NAME stays the US1 BU, CONTRACT_TYPE_NAME stays 'Sell: Project Lines Soft Limit'.
- Keep TASK_NUMBER NULL — every accepted event on these contracts has a NULL task.
- If PJB_TASK_NOT_LINKED still appears after this change, the cause is EVENT_TYPE_NAME (item 1
  above): try the event type name that resolves to the internal 'I' invoice event for these
  contract lines. That name-to-code mapping still needs a live lookup (PJB event-type table not
  yet located).

### Reusable discovery queries (read-only, via scripts/fusion_bip_query.py --cred fin_impl)
Real accepted events on a contract, with line/project/amount:
```
SELECT DISTINCT h.contract_number CONTRACT_NUMBER, be.event_num EVENT_NUM,
       be.event_type_code ETYPE, be.bill_trns_amount AMT, be.bill_trns_currency_code CURR,
       be.project_id PROJ_ID, be.contract_line_id CLINE_ID
FROM pjb_billing_events be JOIN okc_k_headers_all_b h ON h.id=be.contract_id
WHERE h.contract_number IN ('C10001','C10013') AND ROWNUM<=15
```
Confirm a contract-line -> project link exists:
```
SELECT DISTINCT h.contract_number CONTRACT_NUMBER, l.line_number LINE_NUM, p.segment1 LINK_PROJ_NUM
FROM okc_k_headers_all_b h JOIN okc_k_lines_b l ON l.dnz_chr_id=h.id
JOIN pjb_cntrct_proj_links lk ON lk.contract_line_id=l.id
JOIN pjf_projects_all_b p ON p.project_id=lk.project_id
WHERE h.contract_number='C10001' AND ROWNUM<=15
```
Resolve a project_id to its project number:
```
SELECT p.project_id PROJ_ID, p.segment1 PROJ_NUM FROM pjf_projects_all_b p
WHERE p.project_id IN (300000058778835) AND ROWNUM<=5
```

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
