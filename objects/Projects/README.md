# Projects

## Status
E2E LOADED (9 LOADED: 3 Projects, 2 Tasks, 2 Team Members, 2 Txn Controls)

## Pipeline
- Module: Projects
- FBDI Template: PjfProjectsInterface.xlsm
- Interface Tables: PJF_PROJECTS_INTERFACE, PJF_TASKS_INTERFACE, PJF_TEAM_MEMBERS_INTERFACE, PJC_TXN_CONTROLS_INTERFACE
- UCM Account: prj/projectImport/import
- ESS Job: ImportProjectJobDef
- ParameterList: UNKNOWN -- needs verification
- Loader Type: SQLLOADER
- Auth User: fin_impl

## Sub-Objects
1. Projects
2. Tasks
3. TeamMembers
4. TransactionControls

## Code References
- STG Table DDL (Projects): `schema/tables/50_dmt_pjf_projects_stg_tbl.sql`
- STG Table DDL (Tasks): `schema/tables/51_dmt_pjf_tasks_stg_tbl.sql`
- STG Table DDL (TeamMembers): `schema/tables/52_dmt_pjf_team_members_stg_tbl.sql`
- STG Table DDL (TxnControls): `schema/tables/53_dmt_pjc_txn_controls_stg_tbl.sql`
- TFM Table DDL (Projects): `schema/tables/54_dmt_pjf_projects_tfm_tbl.sql`
- TFM Table DDL (Tasks): `schema/tables/55_dmt_pjf_tasks_tfm_tbl.sql`
- TFM Table DDL (TeamMembers): `schema/tables/56_dmt_pjf_team_members_tfm_tbl.sql`
- TFM Table DDL (TxnControls): `schema/tables/57_dmt_pjc_txn_controls_tfm_tbl.sql`
- Validator: `packages/validators/dmt_project_validator_pkg.*`
- Transformer: `packages/transformers/dmt_project_transform_pkg.*`
- FBDI Generator: `packages/generators/fbdi/projects/dmt_project_fbdi_gen_pkg.*`
- Results/Reconciliation: `packages/reconciliation/dmt_project_results_pkg.*`
- BIP Data Model/Report: `bip/Projects/`

## Reference Files
None in this folder.

## Known Issues
- ~~**BIP Tier 2 reconciliation broken:** PJF_PROJECTS_ALL_B does NOT populate REQUEST_ID for project imports.~~ **RESOLVED 2026-04-03 (DB-17):** Tier 2 now uses `SEGMENT1 LIKE :P_PREFIX || '%'` with prefix looked up from CONVERSION_MASTER. Confirmed working — run 100000036 (prefix 9180) matched all rows via Tier 1 (NOT_RECONCILED: 0).
- **Interface table gets purged after import:** PJF_PROJECTS_ALL_XFACE rows are deleted after ImportProjectJobDef + ImportProjectReportJob complete. Tier 1 still works for error detection (FAILURE rows remain), but cannot confirm successful loads alone. Tier 2 (prefix-based PJF_PROJECTS_ALL_B match) provides positive LOADED confirmation.
- **Interface table has NO error message column:** Confirmed 2026-04-05 — `pjf_projects_all_xface` only has `IMPORT_STATUS` and `LOAD_STATUS`. No MESSAGE_TEXT, no ERROR_MESSAGE, no rejection table. The `CAST(NULL AS VARCHAR2(4000))` in the BIP query was correct — there is nothing to return.
- **Primary error source is the Import Report XML:** ESS output from ImportProjectReportJob (downloadable via `downloadESSJobExecutionDetails` SOAP + MTOM parsing) contains `ESS_O_{id}_BIP.xml` with all accepted/rejected/error details. Use `DMT_IMPORT_REPORT_PKG.PARSE_ERRORS` to extract. This must be the PRIMARY source, not a fallback — it is the ONLY place error detail exists for Projects.

## Lessons Learned
- **ImportProjectJobDef processes ALL 4 CSVs from a single zip.** Projects, Tasks, TeamMembers, and TxnControls are all handled by one ESS job submission. Do NOT split into separate submissions.
- **BIP data model must only reference columns that exist on the xface table.** `PROJECT_ID` and `MESSAGE_TEXT` do NOT exist on `pjf_projects_all_xface`. The original BIP query crashed with ORA-00904 on both. Fixed by removing PROJECT_ID and using `CAST(NULL AS VARCHAR2(4000))` for error_message. ~~The "absence = LOADED" pattern handles reconciliation — if a row is absent from the xface table after import, it was successfully imported.~~ **RESOLVED 2026-04-02:** Switched to two-tier BIP (interface + base table). No more absence=LOADED.
- **BIP report crashes block the entire cascade.** When `FETCH_BIP_RESULTS` throws, `PARSE_AND_UPDATE` never runs, so all 4 object types stay at GENERATED — not just Projects. Fix the BIP query first, everything else follows.
- **Reconciliation cascades from Projects → children.** Tasks match on PROJECT_NUMBER, TeamMembers on PROJECT_NAME, TxnControls on PROJECT_NUMBER. If a project is LOADED, all its children are cascaded to LOADED. If FAILED, children get `[FUSION_ERROR] Parent project rejected`.
- **Auth: fin_impl required.** `calvin.roth` lacks the role for ImportProjectJobDef — Import ESS sits in WAIT for 30 min then expires. Always use fin_impl for Projects.
- **Never assume absence=LOADED without positive verification.** Two-tier BIP pattern queries both interface AND base tables. If neither has the row, it's FAILED, not silently LOADED.
- **Fusion returns IMPORT_STATUS='FAILURE' (not 'FAILED').** Added to all 14 reconciliation packages.

- **Tasks CSV had extra PROCESSING_MODE column (col 123).** VBA macro defines 122 columns. The extra column was at the END (not leading). Fixed by removing `PROCESSING_MODE` from `gen_tasks_csv` in `dmt_project_fbdi_gen_pkg.pkb`.
- **BIP Tier 1 used wrong column: `load_request_id` → `request_id`.** Fusion stamps `request_id` (from import ESS job) on xface rows, not `load_request_id`. Fixed in `PROJECT_DM.xdm`. But xface rows are purged anyway (see Known Issues).
- **SOURCE_APPLICATION_CODE must be NULL or a registered value.** 'CONVERSION' and 'EXTERNAL' are both invalid on demo instance. Existing projects have NULL. Leave blank for data migration unless the client registers a source app.
- **ORGANIZATION_NAME must match the template's carrying-out org.** Template `PRGUS Sponsored` uses org ID 300000076861607 = `'Maintenance Prg US'`. Using `'Progress US Project Unit'` fails validation.
- **ESS chain for Projects is NOT parent-child.** Load ESS (InterfaceLoaderController), Import ESS (ImportProjectJobDef), and Report ESS (ImportProjectReportJob) all have `parentrequestid=0`. Find report ESS by: `WHERE DEFINITION LIKE '%ImportProjectReportJob%' AND REQUESTID > :import_ess_id ORDER BY REQUESTID FETCH FIRST 1 ROW ONLY`.
- **downloadESSJobExecutionDetails returns MTOM multipart.** Contains a ZIP with `.log` + `ESS_O_{id}_BIP.xml`. Python can parse via boundary splitting + zipfile. PL/SQL `GET_ESS_OUTPUT_TEXT` returns NULL because it expects inline base64, not XOP references.
- **Import Report XML structure:** `<LIST_PROJECT_ERROR>/<PROJECT_ERROR>` with `ERROR_PROJECT_NAME`, `ERROR_PROJECT_NUMBER`, `PRJ_ERR_SRC_REFERENCE`, `PROJECT_ERR_MSG`. Also `<LIST_PROJECT_SUCCESS>`, `<LIST_TASK_ERROR>`, `<LIST_TXN_CTRL_ERROR>`.
- **BIP Tier 2: REQUEST_ID is NULL for project imports.** PJF_PROJECTS_ALL_B does not populate REQUEST_ID after ImportProjectJobDef. Fixed by matching on SEGMENT1 prefix (e.g. `WHERE segment1 LIKE '9180%'`). P_PREFIX parameter added to BIP data model, looked up from CONVERSION_MASTER in the results package.
- **BIP Tier 1: XDM had wrong column.** The deployed XDM used `request_id` for Tier 1 but the correct column is `load_request_id`. Fixed in DB-17 — XDM now matches query.sql.
- **XDM Tier 1 still works for error detection even after interface purge.** FAILURE rows remain in PJF_PROJECTS_ALL_XFACE; only successfully imported rows are purged. This means Tier 1 catches errors and Tier 2 catches successes — together they cover all outcomes.
- **PROJECT_NAME must be prefixed like PROJECT_NUMBER.** Without prefix, duplicate PROJECT_NAME values across regression runs cause Fusion rejection (import_status=FAILURE). Fixed 2026-04-07 (DB-27): all 4 transformers (Projects, Tasks, TeamMembers, TxnControls) now apply `DMT_UTIL_PKG.PREFIXED(l_prefix, s.PROJECT_NAME, 240)`.

## History
- 2026-03-31 (DB-5): Projects E2E LOADED (Load+Import SUCCEEDED with fin_impl). BIP used DUAL placeholder.
- 2026-03-31 (DB-6): BIP placeholder replaced with real pjf_projects_all_xface query. Query had invalid columns.
- 2026-04-01: BIP crash root cause found — PROJECT_ID and MESSAGE_TEXT don't exist on pjf_projects_all_xface. Fixed and redeployed.
- 2026-04-01: Full pipeline verified. Projects 3L, Tasks 2L/1G, TeamMembers 2L, TxnControls 2L. ESS 9392xxx. Master: total=10, ok=9.
- 2026-04-02: BIP audit — switched to two-tier reconciliation.
  - Tier 1: PJF_PROJECTS_ALL_XFACE (interface table errors/status)
  - Tier 2: PJF_PROJECTS_ALL_B (base table, positive confirmation)
  - Added P_IMPORT_ESS_ID parameter to BIP data model
  - Eliminated absence=LOADED fallback. Unmatched GENERATED rows now FAILED with RECONCILE_ERROR.
- 2026-04-02: Regression test — 0L/18F/2O. BIP working correctly — Fusion returned IMPORT_STATUS=FAILURE (now recognized). All projects rejected by Fusion. Test data needs valid ORGANIZATION_NAME, PROJECT_TYPE, etc. for this instance.
- 2026-04-03: CSV column audit — Tasks CSV had extra PROCESSING_MODE (col 123). Removed. Projects/TeamMembers/TxnControls match VBA.
- 2026-04-03: BIP data model fix — Tier 1 changed from `load_request_id` to `request_id`. Deployed to Fusion.
- 2026-04-03: Test data fix — ORGANIZATION_NAME → `Maintenance Prg US`, SOURCE_APPLICATION_CODE → NULL.
- 2026-04-03: Run 100000029 (prefix 9174): 0L/3F. BIP reconciliation now WORKS (FAILED: 3, NOT_RECONCILED: 0). Error: "source application code isn't valid" (was 'EXTERNAL').
- 2026-04-03: Run 100000030 (prefix 9175): 1 ACCEPTED, 2 REJECTED per Import Report XML. The "bad" project (NULL org) actually loaded (Fusion defaulted from template). But BIP Tier 2 returned 0 because PJF_PROJECTS_ALL_B.REQUEST_ID is NULL.
- 2026-04-03: Discovered Import Report ESS output download via MTOM — working from Python. This is the primary error source for Projects.
- 2026-04-03: Run 100000034 (prefix 9179): **ALL 9 ROWS LOADED.** 3 Projects, 2 Tasks, 2 Team Members, 2 Txn Controls. Valid data: org='Maintenance Prg US', template='PRGUS Sponsored', persons=#7 Alan Cook + #10 Mandy Steward, expenditure type='Professional Services'. Pipeline crashed at downstream BillingEvents (no data, empty CLOB to UTL_ZIP) — Projects themselves fully working.
- 2026-04-03 (DB-17): **BIP Tier 2 fix deployed.** Changed from REQUEST_ID to SEGMENT1 prefix matching. Added P_PREFIX parameter to XDM. Also fixed Tier 1 XDM column (request_id → load_request_id). Run 100000036 (prefix 9180): Tier 1 matched 2 rows (FAILURE — test data quality). NOT_RECONCILED=0. Reconciliation confirmed working.

- 2026-04-07 (DB-27): **PROJECT_NAME prefix fix.** All 3 projects LOADED (9L/0F total with children). Root cause: unprefixed PROJECT_NAME caused duplicate conflicts in Fusion from prior runs.

## Valid Test Data (Demo Instance)
- SOURCE_TEMPLATE_NUMBER: `PRGUS Sponsored`
- ORGANIZATION_NAME: `Maintenance Prg US`
- SOURCE_APPLICATION_CODE: NULL (not registered on demo instance)
- PROJECT_STATUS_NAME: `Active`
- PROJECT_CURRENCY_CODE: `USD`
- Team Member Persons: #7 Alan Cook, #10 Mandy Steward (real Fusion persons)
- Team Member Role: `Project Manager`
- Expenditure Type: `Professional Services`

