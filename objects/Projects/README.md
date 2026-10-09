# Projects

## Status
E2E LOADED on the frozen stack (9 LOADED: 3 Projects, 2 Tasks, 2 Team Members, 2 Txn Controls).

**DMT2 offline port — DONE 2026-07-09** (branch `obj/projects-offline`):
- Identity-PK conversion of all 8 Projects STG/TFM tables (GENERATED ALWAYS AS IDENTITY;
  the 8 per-table sequences retired); `check_column_dictionary.sql` passes for all 8 with
  no identity deferral.
- Golden byte-compare of the generated 4-CSV zip vs `test/fbdi_zips/Projects_116.zip` is
  BYTE-IDENTICAL after the one declared token (run prefix). No date masking, no undeclared diffs.
- Reconciler (`dmt_project_results_pkg`) ported to the accepted architecture: shared BIP
  transport (`DMT_UTIL_PKG.RUN_BIP_REPORT`, no private UTL_HTTP), Contract v1 params
  (`P_RUN_ID / P_LOAD_REQUEST_ID / P_IMPORT_ESS_ID / P_PREFIX`; `P_BATCH_ID` retired in the
  package and the BIP data model), `FETCH_BIP_RESULTS` is a procedure with an error code,
  TFM is the sole outcome record (the write-back-to-staging `echo_to_stg` block removed).
- Transform: removed the reprocess-time `ERROR_TEXT = NULL` reset (ERROR_TEXT is append-only).
- Unit suite `test/unit/test_projects.sql` green (land -> validator -> transform -> generate).
- Live Fusion gate (Rule #1: GOOD rows LOADED, BAD rows FAILED) is deferred to the online phase.

## ONE object, four record-type CSVs
Projects is ONE object: a single FBDI zip (`Projects_*.zip`) carrying four record-type CSVs —
like PurchaseOrders, NOT a family of separate objects. One load ESS job (ImportProjectJobDef).

## Reconciliation by the stamped work-item reference (owner-approved exception, 2026-10-07)

Reconciliation reports find rows by Fusion job id, but the project base tables carry none:
`PJF_PROJECTS_ALL_B.REQUEST_ID` is NULL after import, the task, team-member and
transaction-control base tables have no request-id column, and the interface is purged after a
successful import. The owner approved this exception (design section 5, DECIDED 2026-10-07),
which works like Customers:

- **Stamp.** `DMT_PROJECT_TRANSFORM_PKG.TRANSFORM_PROJECTS` writes the FBDI Source Reference
  (`SOURCE_PROJECT_REFERENCE`, stored by Fusion as `PJF_PROJECTS_ALL_B.PM_PROJECT_REFERENCE`) as
  `<run_id>:<work_queue_id>:<legacy source project reference>`, using the legacy project number
  when the source has no reference. With prefixing off (`USE_PREFIX = N` at cutover) it writes
  the plain legacy value. The work-queue id is `DMT_LOADER_PKG.g_gen_queue_id`, the item the
  transform runs in. TFM column widened 25 -> 100 (Fusion's width); create script, guarded
  ALTER and `db/migrations/2026-10-07_projects_source_ref_widen.sql`.
- **Report V2** `DMT_PROJECT_RECON_V2_DM` / `_RPT` (deployed alongside V1, never overwritten)
  selects base projects by `pm_project_reference LIKE :P_RUN_ID||':'||:P_WQ_ID||':%'`; tasks,
  team members and transaction controls are reached through their project; interface rows are
  selected by `LOAD_REQUEST_ID`. No `LIKE` on the run prefix. Keyset pinned to BINARY.
- **P_WQ_ID** is a seventh report parameter. `DMT_RECON_CONTRACT_PKG.FETCH_ROWS` gained an
  optional `p_work_queue_id` and sends `P_WQ_ID` only when it is given, which only
  `DMT_PROJECT_RESULTS_PKG` does. `RECONCILE_BATCH` uses `p_work_queue_id` when the queue passes
  it (the async reconcile and a reconcile-only rerun do), else the item running now.
- Registry (the Projects row and the three auditor rows) repointed by the seed and
  `db/migrations/2026-10-07_projects_recon_v2_registry.sql`.
- Verified first: `PM_PROJECT_REFERENCE` is VARCHAR2(100), and Fusion keeps the reference with
  `SOURCE_APPLICATION_CODE` left empty (the project gets `PM_PRODUCT_CODE = OPEN_INTERFACE`, a
  defined value of lookup `PJF_PM_PRODUCT_CODE`). No Fusion setup was changed.

Proof run 278 (prefix 93334, scenario RegressionTest2610071920, STANDALONE:Projects): work item
1646 recorded load 10075841 / import 10075849 (Import Projects report child 10075857). Fusion
holds projects 93334RTPRJ001 / 93334RTPRJ002 (ids 300000334930842 / 300000334930867) with
`PM_PROJECT_REFERENCE` `278:1646:RTPRJ001` / `278:1646:RTPRJ002` and `PM_PRODUCT_CODE`
OPEN_INTERFACE. The report returned 8 rows; every LOADED row's Fusion id matches the base table
(2 projects, 2 tasks, 2 team members, 2 transaction controls). RTPRJ-BAD1 FAILED with its own
error from the import report ("The project status isn't valid ..."); 0 UNACCOUNTED; counts match
run 238. A reconcile-only rerun left all 9 TFM rows byte-identical. `dmt_regression_run.py` PASS
with two pre-existing review items (the Team Members REST lookup is NOT_FOUND, as in run 238, and
the error that REST call logs); Playwright click-through PASS. The prefix-off path was not run
live.

## A failed child rejects its project (backlog #545, 2026-10-09)

Proven live. Run 343 (prefix 93393, scenario RegressionTest261009013036, PROJECTS) sent project
RTPRJ-XG1 whose only defect is its team member (`RT Nobody XG1`, `nobody.xg1@fake.com`, a person
that does not exist). Import Projects rejected the whole project: the ImportProjectReportJob output
(request 10084323) lists the member in `LIST_TEAM_MEMBER_ERROR` with its own message "The specified
resource doesn't exist." and the project in `LIST_PROJECT_ERROR` only with the pointer "The project
wasn't imported because import errors exist for the project team members." The valid task and
transaction control were not created.

`DMT_PROJECT_RESULTS_PKG` now handles that:
- The team-member report row is matched on its project-name and member-name tokens (the generic
  parser joins the TM_ERROR_* identifier fields with `/`, empty ones included, so run 343's member
  was left with only the project's pointer).
- `PROPAGATE_DOCUMENT_ERRORS` treats a task, team member or transaction control with its own real
  error as the cause: its error is quoted onto its project and the project's other children, e.g.
  `[FUSION_ERROR] Rejected with document: project 93395RTPRJ-XG1 (team member RT Nobody XG1): The
  specified resource doesn't exist.` The project keeps its pointer text and gains the quote. A
  project's own error is spread downward only when none of its children failed (RTPRJ-BAD1 as before).

Proof run 345 (prefix 93395, same scenario): project, task and transaction control of RTPRJ-XG1
FAILED with the quote, the member FAILED with its own error, all other rows as before, 0
UNACCOUNTED, `dmt_regression_run.py` PASS (72 listed rows met). Matching a task's or transaction
control's own report row is unchanged and has no live example yet (backlog #655).

## Pipeline
- Module: Projects
- FBDI Template: PjfProjectsInterface.xlsm
- Interface Tables: PJF_PROJECTS_INTERFACE, PJF_TASKS_INTERFACE, PJF_TEAM_MEMBERS_INTERFACE, PJC_TXN_CONTROLS_INTERFACE
- UCM Account: prj/projectImport/import
- ESS Job: ImportProjectJobDef
- ParameterList: UNKNOWN -- needs verification
- Loader Type: SQLLOADER
- Auth User: fin_impl

## Record types (four CSVs in the one zip)
1. Projects  -> PjfProjectsAllXface.csv
2. Tasks     -> PjfProjElementsXface.csv
3. TeamMembers -> PjfProjectPartiesInt.csv
4. TransactionControls -> PjcTxnControlsStage.csv

## Code References (DMT2 layout)
- STG Table DDL: `db/tables/dmt_pjf_projects_stg_tbl.sql`, `dmt_pjf_tasks_stg_tbl.sql`,
  `dmt_pjf_team_members_stg_tbl.sql`, `dmt_pjc_txn_controls_stg_tbl.sql`
- TFM Table DDL: `db/tables/dmt_pjf_projects_tfm_tbl.sql`, `dmt_pjf_tasks_tfm_tbl.sql`,
  `dmt_pjf_team_members_tfm_tbl.sql`, `dmt_pjc_txn_controls_tfm_tbl.sql`
- Validator: `db/packages/dmt_project_validator_pkg.{pks,pkb}.sql`
- Transformer: `db/packages/dmt_project_transform_pkg.{pks,pkb}.sql`
- FBDI Generator: `db/packages/dmt_project_fbdi_gen_pkg.{pks,pkb}.sql`
- Results/Reconciliation: `db/packages/dmt_project_results_pkg.{pks,pkb}.sql`
- Retired-sequence drop tool: `db/tools/drop_retired_project_sequences.sql`
- BIP Data Model/Report: `bip/Projects/`
- Unit test: `test/unit/test_projects.sql`
- Golden compare: `test/golden/test_projects_golden.sh` (+ `Projects` entry in `normalization_map.json`)
- Golden inputs: `test/golden/inputs/Project*_input.csv`

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
- **A rejected project's real error is quoted onto its children (2026-10-08, backlog #170).** That old cascade (children copied LOADED from their project, or given a generic `Parent project rejected`) no longer exists: every tier is proven against its own base table. When Import Projects rejects a project, its tasks, team members and transaction controls are rejected with it but the import report names only the project, so `DMT_PROJECT_RESULTS_PKG.PROPAGATE_DOCUMENT_ERRORS` (after the apply and the import-report harvest, before the shared unaccounted sweep) appends `[FUSION_ERROR] Rejected with document: project <number>: <the project's real message>` to each child Fusion received (tasks and transaction controls by PROJECT_NUMBER, team members by PROJECT_NAME) and sets it FAILED. LOADED rows are never touched; a second pass adds nothing. Child-to-project direction is not applied until a live run shows that a child's error rejects its project (backlog #545). Regression: the rejected project RTPRJ-BAD1 carries a valid task, team member and transaction control, each expected FAILED_WITH_DOCUMENT.
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
- **Reconciliation MUST read the child ImportProjectReportJob, not the wrapper import job (run 234, fix `fix/projects-read-child-report-job`).** `ImportProjectJobDef` (the import ESS job the loader passes as `p_import_ess_id`) is only an async submit wrapper — its own ESS output is an essentially empty XML (~4 bytes). The real per-row accept/reject report lives in the child `ImportProjectReportJob` that the wrapper spawns. The loader already captures that child via `DMT_ESS_UTIL_PKG.CAPTURE_REPORT_ESS_JOB`, which stores it in `DMT_ESS_JOB_TBL` with `PARENT_REQUEST_ID = <wrapper import id>` and `JOB_SHORT_NAME/JOB_DEFINITION = 'ImportProjectReportJob'`. `DMT_PROJECT_RESULTS_PKG.apply_import_report` now resolves that child request id from `DMT_ESS_JOB_TBL` (private `resolve_report_ess_id`) and downloads the report XML from the CHILD job. If no child was captured it downloads nothing and leaves rows GENERATED (unaccounted) — it never reads the empty wrapper and never fabricates a FAILED. Before this fix the wrapper's empty XML meant a genuinely-rejected project (e.g. `10115RTPRJ-BAD1`, invalid `PROJECT_STATUS_NAME`) was never surfaced and stayed unaccounted.
- **A true orphan task (parent project never in the load) correctly stays GENERATED.** A task whose parent project number has no project TFM row at all — and for which Fusion emits no per-row message — is left GENERATED (unaccounted). The parent/child FAILED cascade only fires when a matching parent project row is FAILED, and then it quotes the parent's real Fusion error. We never fabricate a parent error to fail an orphan.
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


## Table-name vs FBDI-tab audit (backlog #90, 2026-10-01)

Backlog #90 asks whether every STG/TFM table name mirrors the FBDI CSV tab
(record type) it loads. The object-model rule is "one object = one FBDI zip = one
tab per record type". Projects is ONE zip (`PjfProjectsInterface.xlsm`) with four
CSVs / four interface tables; DMT models all four, one STG + one TFM table each.

**The mapping (from the generator `DMT_PROJECT_FBDI_GEN_PKG` `REGISTER_CSV` calls
and each `gen_*_csv` function's `FROM` table):**

| FBDI tab / CSV | Interface table | Source STG table | Source TFM table | Verdict |
|---|---|---|---|---|
| PjfProjectsAllXface.csv | PJF_PROJECTS_ALL_XFACE | DMT_PJF_PROJECTS_STG_TBL | DMT_PJF_PROJECTS_TFM_TBL | ALIGNED (PJF_PROJECTS) |
| PjfProjElementsXface.csv | PJF_PROJ_ELEMENTS_XFACE (Tasks) | DMT_PJF_TASKS_STG_TBL | DMT_PJF_TASKS_TFM_TBL | NAME-MISALIGNED (Tasks = ProjElements), model correct |
| PjfProjectPartiesInt.csv | PJF_PROJECT_PARTIES_INT (Team Members) | DMT_PJF_TEAM_MEMBERS_STG_TBL | DMT_PJF_TEAM_MEMBERS_TFM_TBL | NAME-MISALIGNED (TeamMembers = ProjectParties), model correct |
| PjcTxnControlsStage.csv | PJC_TXN_CONTROLS_STAGE | DMT_PJC_TXN_CONTROLS_STG_TBL | DMT_PJC_TXN_CONTROLS_TFM_TBL | ALIGNED (PJC_TXN_CONTROLS) |

**Why two rows read NAME-MISALIGNED but the model is correct (synonym, not a
wrong record type):**
- The Fusion "Tasks" record type ships on a tab Oracle names `PjfProjElements`
  (project *elements* = tasks in the work-breakdown structure). DMT names the table
  for the business concept (`TASKS`). Same record type, different label.
- The Fusion "Team Members" record type ships on a tab Oracle names
  `PjfProjectParties` (a project party playing a team-member role). DMT names the
  table for the business concept (`TEAM_MEMBERS`). Same record type, different label.
- `PJF_PROJECTS` and `PJC_TXN_CONTROLS` match their tabs directly (ALIGNED).

**Findings (what was fixed vs deferred):**
1. **NO spec-header fix needed.** The generator spec-header already lists the four
   real Oracle CSV tabs (`PjfProjectsAllXface.csv`, `PjfProjElementsXface.csv`,
   `PjfProjectPartiesInt.csv`, `PjcTxnControlsStage.csv`), matching the `REGISTER_CSV`
   calls in the body. Accurate as-is.
2. **DEFERRED (physical rename, high ripple -- DO NOT do under this item):** renaming
   `DMT_PJF_TASKS_*` to `*_PROJ_ELEMENTS_*` and `DMT_PJF_TEAM_MEMBERS_*` to
   `*_PROJECT_PARTIES_*` would match the Oracle tab labels but trade a clear
   business name for an obscure one, and would ripple across the validator,
   transformer, generator, results package, catalog, pipeline, views and BIP. These
   are synonyms, not wrong record types, so no rename is warranted. Recorded as a
   finding only.
3. **No NOT-MODELED gaps.** All four CSVs in the Projects zip have a STG and a TFM
   table and a generator branch.

**Registry note (not a misalignment):** the "Interface Tables" line in the Pipeline
section lists the generic Oracle names (`PJF_PROJECTS_INTERFACE`, etc.). The actual
load/interface tables Fusion uses are the `*_XFACE` / `*_STAGE` / `*_INT` tables the
CSVs load into (see Known Issues, `PJF_PROJECTS_ALL_XFACE`). The table above uses the
real interface-table names the FBDI tabs resolve to.
