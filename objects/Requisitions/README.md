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
