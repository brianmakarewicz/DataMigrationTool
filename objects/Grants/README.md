# Grants

## Status
NOT BLOCKED (corrected 2026-10-07, docs/findings/known_good_Grants.md). The old "demo grants
module not configured" conclusion was wrong: "requisite setup steps haven't been completed" is
what Fusion returns when awards are submitted as `FIN_IMPL`. The same awards load when submitted
as `PPM_IMPL` (the owner's known-good run 10070355 and the standalone replay with prefix 77101).
Grants now runs as the per-object user `ppm_impl` (interface options row 57) for submit, poll
and the Award Batch Import Report download. Original "E2E LOADED" (2026-04-02) was a false
positive from the absence=LOADED fallback bug.

## Pipeline
- Module: Projects
- FBDI Template: GmsAwardHeadersInterface.xlsm
- Interface Tables: GMS_AWARD_HEADERS_INTERFACE, GMS_AWARD_FUNDING_INTERFACE, GMS_AWARD_PROJECTS_INTERFACE, GMS_AWARD_PERSONNEL_INTERFACE, GMS_AWARD_FUND_SRC_INTERFACE, GMS_AWARD_PRJ_FUND_SRC_INTERFACE, GMS_AWARD_KEYWORDS_INTERFACE, GMS_AWARD_BDGT_PRDS_INTERFACE, GMS_AWARD_CERTS_INTERFACE, GMS_AWARD_CFDAS_INTERFACE, GMS_AWARD_FUND_ALLOC_INTERFACE, GMS_AWARD_ORG_CREDITS_INTERFACE, GMS_AWARD_PRJ_TSK_BRD_INTERFACE, GMS_AWARD_REFERENCES_INTERFACE, GMS_AWARD_TERMS_INTERFACE
- UCM Account: prj/grantsManagement/import
- ESS Job: AwardMassImportJob
- ParameterList: `#NULL,#NULL,true` (from award number, to award number, "report success
  details" Yes/No flag). `true` matches the known-good run and makes the Award Batch Import
  Report list successful awards (LIST_G_3) as well as failures (LIST_G_4). It is the
  loadAndImportData jobList ParameterList, one comma-delimited element.
- Loader Type: SQLLOADER
- Auth User: `ppm_impl` (per-object override, DMT_ERP_INTERFACE_OPTIONS_TBL row 57; the
  password is filled from connections.json by `db/tools/setup_runtime_config.py`). Polling and
  report download MUST use the same user: Fusion answers another user's ESS request with
  HTTP 500 (FND_CMN_SYS_ERR).

## Sub-Objects (14 sub-tables)
1. AwardHeaders
2. AwardFunding
3. AwardProjects
4. AwardPersonnel
5. AwardTerms
6. AwardFundSrc
7. AwardPrjFundSrc
8. AwardKeywords
9. AwardCerts
10. AwardCfdas
11. AwardFundAlloc
12. AwardOrgCredits
13. AwardPrjTskBrd
14. AwardReferences

## Code References
- STG Table DDLs: `schema/tables/62_dmt_gms_awd_headers_stg_tbl.sql` through `schema/tables/76_dmt_gms_awd_terms_stg_tbl.sql`
- TFM Table DDLs: `schema/tables/77_dmt_gms_awd_headers_tfm_tbl.sql` through `schema/tables/91_dmt_gms_awd_terms_tfm_tbl.sql`
- Validator: `packages/validators/dmt_grants_validator_pkg.*`
- Transformer: `packages/transformers/dmt_grants_transform_pkg.*`
- FBDI Generator: `packages/generators/fbdi/grants/dmt_grants_fbdi_gen_pkg.*`
- Results/Reconciliation: `packages/reconciliation/dmt_grants_results_pkg.*`
- BIP Data Model/Report: `bip/Grants/`

## Reference Files
- `GmsAwardHeadersInterface.ctl`
- `GmsAwardFundingInterface.ctl`
- `GmsAwardProjectsInterface.ctl`
- `GmsAwardPersonnelInterface.ctl`
- `GmsAwardTermsInterface.ctl`
- `GmsAwardFundSrcInterface.ctl`
- `GmsAwardPrjFundSrcInterface.ctl`
- `GmsAwardKeywordsInterface.ctl`
- `GmsAwardCertsInterface.ctl`

## Reconciliation — Award Batch Import Report (per-award errors)
`AwardMassImportJob` can SUCCEED as a job while rejecting every award (Success 0 / Error N).
Fusion PURGES the award interface/error tables right after import, so the base+interface BIP
report returns zero rows and the per-award rejection messages survive ONLY in Fusion's own
**Award Batch Import Report** — a SEPARATE child ESS request (`ImportAwardReportJob`, data model
`AwardBatchImportReportDm`), spawned alongside the import job.

- DMT_ERP_INTERFACE_OPTIONS_TBL row 57 (Grants) now seeds `REPORT_JOB_DEF='ImportAwardReportJob'`,
  so the generic loader routine `DMT_ESS_UTIL_PKG.CAPTURE_REPORT_ESS_JOB` captures that report
  child into DMT_ESS_JOB_TBL (PARENT_REQUEST_ID = the AwardMassImportJob request id). Mirrors
  Projects (`ImportProjectReportJob`) and BillingEvents (`ImportBillingEventReportJob`).
- `DMT_GRANTS_RESULTS_PKG.RECONCILE_BATCH` reads that captured child via `GET_ESS_OUTPUT_XML`
  and parses `/DATA_DS/LIST_G_4/G_4`: `PARENT_AWARD_NUMBER` -> the award number (TFM key),
  `PROCESSED_MESSAGE` -> the real Fusion rejection message. Each matched award is set FAILED
  with `[FUSION_ERROR] <message>`. This is a FAILURE-ONLY list (report runs REPORT_SUCCESS_RECORDS=N).
- LOADED is still confirmed ONLY by the base table (GMS_AWARD_HEADERS_B) via the DMT BIP report.
  Awards neither base-confirmed nor in the report's failure list stay GENERATED (honest UNACCOUNTED).
- **Recon data model V2 (2026-10-07):** `bip/Grants/DMT_GRANT_RECON_V2_DM.xdm` (deployed alongside
  V1, never overwriting it). An award created by FBDI carries NO request id and NO sponsor award
  number (`DC_REQUEST_ID`, `SUMMARY_REQUEST_ID`, `SPONSOR_AWARD_NUMBER`, `ATTRIBUTE1` all NULL), so
  V1's `dc_request_id = :P_IMPORT_ESS_ID` filter and `SPONSOR_AWARD_NUMBER` key could never find a
  loaded award. V2's BASE tier joins `OKC_K_HEADERS_ALL_B` (`k.id = b.id`, `version_type = 'C'`),
  keys on `CONTRACT_NUMBER` (= the prefixed award number) and scopes by
  `CONTRACT_NUMBER LIKE :P_PREFIX || '%'` and `AWARD_SOURCE = 'FBDI'`. The transform stamps
  `RECON_KEY` = the prefixed `AWARD_NUMBER` to match. The report child is downloaded as `ppm_impl`.
- Report request for the run-234 evidence chain: ESS 9773862 (child of import ESS 9773857).

## Cross-grain error attribution (backlog #171, #196, 2026-10-08)
Import Awards rejects a whole award when the award or any one of its children fails, and
the Award Batch Import Report names the row it blamed. Fusion's data model
(`/Projects/Grants Management/Award/Data Models/AwardBatchImportReportDm.xdm`) nests a
rejected award's child failures inside its `G_4` row, one group per record type, each with
the child's own `PROCESSED_MESSAGE` and the keys Fusion read from the CSV:
G_33 personnel, G_2 funding, G_41 funding allocation, G_30 budget period, G_28 org credit,
G_24 project, G_21 CFDA, G_18 term, G_7 certification, G_13 reference, G_14 task burden
schedule, G_19 project funding source, G_25 funding source, G_8 keyword.

- `APPLY_CHILD_REPORT_FAILURES` matches each child failure to its TFM row (award number plus
  the child's business keys; a key the report leaves empty is not compared) and sets it FAILED
  with its own `[FUSION_ERROR] <message>`.
- The award header keeps the `G_4` message as its own error only when the report lists no failed
  child for that award. Otherwise the child caused the rejection, and the `G_4` text is only a
  pointer to it (live: "The award isn't imported because errors exist in the personnel data.").
- `PROPAGATE_DOCUMENT_ERRORS` (after the apply, before the shared unaccounted sweep) quotes the
  blamed row's error onto every other row of the award that has no error of its own:
  `[FUSION_ERROR] Rejected with document: award <AWARD_NUMBER> (<grain> <key>): <message>`
  (no `(<grain> <key>)` part when the award header itself was blamed). FORALL UPDATE,
  APPEND_ERROR, idempotent, never touches LOADED rows. The old header-to-children FAILED
  cascade is retired. Awards whose header is LOADED are never quoted onto (backlog #568).
- Regression: `RTAWD-XG1` (Good-1's shape, personnel PI `PERSON_NUMBER 99999999`, no email)
  in scenario RegressionTest2610081853.

## Each child is accounted on its own evidence (backlog #568 / #670, 2026-10-09)
- **No LOADED by inheritance.** `cascade_children` (every child of a LOADED award set LOADED) is
  retired. `APPLY_CHILD_REPORT_SUCCESSES` sets a child LOADED only when the Award Batch Import
  Report of the run's own import job (job-scoped: the report is a child request of the import
  ESS id) lists that child row as imported, in the success groups under the award's `G_3` row
  (G_35 personnel, G_36 funding, G_40 funding allocation, G_32 budget period, G_27 org credit,
  G_26 project, G_23 funding source, G_16 project funding source), AND the award header is
  already LOADED from `GMS_AWARD_HEADERS_B`. One success line matches one TFM row (lowest
  TFM_SEQUENCE_ID still waiting), so two identical rows need two lines. A child with no line of
  its own stays GENERATED and ends UNACCOUNTED in the shared sweep.
- **Child rejected under a LOADED award.** It keeps its own `[FUSION_ERROR]`; the award stays
  LOADED and no sibling is quoted (`PROPAGATE_DOCUMENT_ERRORS` skips awards whose header is
  LOADED). Fusion never produced this on the pod: probes 77141 / 77142 (2026-10-09, standalone,
  as PPM_IMPL) sent eleven child defects (invalid keyword, term, project, personnel role and
  person; duplicate budget period, project, funding source, personnel, org credit, funding
  allocation) and every one rejected the whole award (`G_4` "The award isn't imported because
  errors exist in the ... data."). So no live scenario can show it; it is proven by the unit
  test `test/unit/test_grants_child_accounting.sql` on a synthetic report.
- **Load failure.** `fin_mark_generated_failed` now fails all 15 Grants TFM tables with the
  load's `[LOAD_ERROR]`, not only the award headers (backlog #670).
- Terms, keywords, certifications, CFDAs, references and task burden schedules have no success
  group in Fusion's report, so a child of those types is never LOADED (backlog #671: give them,
  and every child, a base-table proof with its own Fusion id).

## Award children in the record views (backlog #567, 2026-10-09)
Every award child TFM table now has its own lane in `DMT_RECORD_DETAIL_V`,
`DMT_OBJECT_DETAIL_V`, `DMT_V_CEMLI_TFM_TABLES` and the `DMT_CEMLI_CATALOG_TBL` seed, labelled
with the SUB_OBJECT the Grants transform already writes to `DMT_STG_TFM_ERROR_TBL`: Award Funding,
Award Projects, Award Personnel, Award Terms, Award Funding Sources, Project Funding Sources,
Award Keywords, Award Certifications, Award CFDAs, Funding Allocations, Org Credits, Budget
Periods, Project Task Burden, Award References. DISPLAY_KEY starts with the prefixed award number;
LOOKUP_KEY is the award number, so Verify in Fusion reads the award back through the object-level
`Grants` REST row (`AwardNumber={KEY}`). Because the catalog table drives the accounting gate and
the shared unaccounted sweep, every child row now counts toward the Grants accounting rule.

`scripts/regression_scenario.json` lists every child row of the scenario: children of a LOADED
award are LOADED, children of RTAWD-BAD1 / RTGNT-BAD2 / RTGNT-BAD3 and of RTAWD-XG1 are
`FAILED_WITH_DOCUMENT`, and the XG1 personnel row (`RT-GNT-PERS2-RTAWD-XG1`) is `FAILED` with its
own Fusion error. Re-evaluating local run 339 (scenario RegressionTest261008213401) with the new
lanes: all 249 listed rows met their expected outcome, PASS, and Verify found the award for each
child lane with a LOADED row.

## Known Issues
- ~~BIP reconciliation uses "absence=LOADED" pattern: Fusion purges interface table rows after successful import.~~ **RESOLVED 2026-04-02:** Switched to two-tier BIP (interface + base table). No more absence=LOADED.
- ~~Per-award rejection errors were unreadable after import (interface purged) — object left UNACCOUNTED.~~ **RESOLVED (run-234 fix):** reconciler now reads the Award Batch Import Report child (see above).
- **Live section-7 standard violations in Grants code (pre-existing; logged per the "README Known Issues" rule, 2026-10-07):**
  - Award children are set LOADED on their own success line in the job's Award Batch Import Report
    (backlog #568), but still without their own `FUSION_*_ID` (the "LOADED carries its Fusion id" rule),
    and six child types can never be LOADED (no success group). The child base tables do exist
    (`GMS_AWARD_PERSONNEL`, `GMS_AWARD_PROJECTS`, `GMS_AWARD_BUDGET_PERIODS`, `GMS_AWARD_KEYWORDS`, ...),
    but carry no job id, so a child-tier base recon is not built yet (backlog #671).
  - `bip/Grants/` holds more than one data model (V1 + V2 recon, `GRANTS_DM`, `GRANTS_CMP_DM`); the contract's
    "one data model per folder" conflicts with the never-overwrite BIP versioning rule (V2 deployed alongside V1).
  - `DMT_GRANTS_RESULTS_PKG.find_report_ess_id` / `apply_award_import_report` are functions with nested
    BEGIN/END blocks and swallow-and-log handlers (rules: procedures only, one BEGIN/END, no swallow).
  - `DMT_ESS_UTIL_PKG.GET_ESS_OUTPUT_XML` / `CAPTURE_REPORT_ESS_JOB` are functions returning payload/ids, and
    the package carries private `UTL_HTTP` copies (`soap_http`, `soap_http_blob`) instead of the single shared
    transport; `CAPTURE_REPORT_ESS_JOB` parses the status response with `INSTR`/`SUBSTR` (structured-parsing rule).
  - No NAME/PURPOSE/REVISIONS header on the Grants packages.
  - The Grants transform does not stamp `WORK_QUEUE_ID` on its 15 TFM tables (NULL on runs 229-238), so the
    reconciler cannot scope its UPDATEs by work-queue item ("work queue item is the unit of processing" rule);
    they are scoped by `RUN_ID`. Grants runs as one work item per run, so this is not a cross-batch hazard today.
  - `db/seed/dmt_erp_interface_options_tbl.sql` is insert-and-skip, not MERGE (registry-seed-converge rule);
    the 2026-10-07 per-object user change converges existing databases through
    `db/migrations/2026-10-07_grants_ppm_impl_and_recon_v2.sql`.

**CSV file names (corrected 2026-10-07):** the two CSV names above are the exact names the
Oracle template macro writes (`GmsAwardBdgtPeriodsInterface`, `GmsAwardPrjTaskBrdInterface`) and
the names Fusion's loader matches to a control file. The generator previously wrote
`GmsAwardBudgetPeriodsInterface.csv` / `GmsAwardPrjTaskBurdenInterface.csv`, which Fusion does not
load, so budget periods never reached the interface (an award without a budget period is
rejected).

## Lessons Learned
- **"Requisite setup steps haven't been completed" was the submitting user, not the instance.**
  Before blaming instance setup, replay the owner's known-good file as the DMT user and as the
  owner's user (docs/findings/known_good_Grants.md replays A and B).
- **Regression awards need their children.** A header plus personnel is rejected with "No project
  is associated to this award"; funding source, project, project funding source, budget period,
  funding, funding allocation and organization credit rows are all needed (mirrors known-good
  AWDTST04B / AWDTST02B).
- **Never assume absence=LOADED without positive verification.** Two-tier BIP pattern queries both interface AND base tables. If neither has the row, it's FAILED, not silently LOADED.

## History
- Code complete for all 14 sub-tables. First Fusion submission resulted in ESS timeout, suggesting ParameterList issue.
- 2026-04-02: ParameterList fixed from `NEW,N` to `#NULL,#NULL,#NULL`. Root cause: `NEW,N` passed 2 args to a 3-arg job, causing indefinite WAIT.
  - Load ESS 9393144 SUCCEEDED, Import ESS 9393187 SUCCEEDED.
  - **FALSE POSITIVE:** 3 awards reported LOADED via absence=LOADED fallback. Actually rejected by Fusion.
  - BIP report deployed to /Custom/DMT/Grants/. Added absence=LOADED post-loop fallback.
- 2026-04-02: BIP audit — switched to two-tier reconciliation. Eliminated absence=LOADED.
- 2026-04-02: Regression test — 0L/6F. Correctly identified as FAILED now that absence=LOADED removed.
- 2026-04-04 (DB-18): Systematic investigation of Fusion errors:
  - University US BU: "requisite setup steps haven't been completed" + "Contract Type 'Award' isn't valid"
  - Fixed CONTRACT_TYPE to `Sell: Project Award Hard Limit`, PRIMARY_SPONSOR to valid values (NSF, NCI, DHS, EPA)
  - Added SOURCE_TEMPLATE_NUMBER (`VU Funded Award` for University US, `1 Year Award` for Progress US)
  - Added AwardPersonnel rows (PI=Sean Murphy #1171, 100% credit) for both BUs
  - Switched to Progress US BU: same "requisite setup steps" error
  - **Conclusion:** Demo instance grants module is not configured. All business units affected.
  - Valid contract types (from REST): `Sell: Project Award Hard Limit`, `Sell: Project Award Soft Limit`
  - Valid sponsors: National Science Foundation, National Cancer Institute, Dept of Homeland Security, EPA, Dept of Education, Dept of Health and Human Services, American Heart Association, Bond, MerLabs and Co, National Institute of Health

- 2026-10-07: **First DMT E2E LOAD.** Run 242 (prefix 93298, scenario RegressionTest2610071115, local Docker),
  submitted as PPM_IMPL: load 10073794 (9 SQL*Loader children), import AwardMassImportJob 10073807, report
  10073809. 93298RTAWD-G1 / -G2 LOADED (GMS_AWARD_HEADERS_B ids 300000334921417 / 300000334921449, created by
  PPM_IMPL, one project link each); 93298RTAWD-BAD1 FAILED "The value of the attribute Primary Sponsor isn't
  valid." with all 8 children FAILED quoting it; RTGNT001/002 FAILED "No project is associated to this award";
  RTGNT-BAD1 FAILED "You must provide a value for the Business Unit attribute." 0 UNACCOUNTED.

## Table-name vs FBDI-tab audit (backlog #90, 2026-10-01)

Backlog #90 asks whether every STG/TFM table name mirrors the FBDI CSV tab
(record type) it loads. The object-model rule is "one object = one FBDI zip = one
tab per record type". Grants is ONE zip (`GmsAwardHeadersInterface.xlsm`) with
FIFTEEN CSVs / fifteen interface tables; DMT models all fifteen, one STG + one TFM
table each. The DMT names are direct transliterations of the Oracle interface
tables (`GMS_AWARD_*_INTERFACE` -> `DMT_GMS_AWD_*_TFM_TBL`), shortened only where
needed to fit the 30-byte Oracle identifier limit.

**The mapping (from the generator `DMT_GRANTS_FBDI_GEN_PKG` `REGISTER_CSV` calls
and each `gen_*_csv` function's `FROM` table):**

| FBDI tab / CSV | Interface table | Source STG table | Source TFM table | Verdict |
|---|---|---|---|---|
| GmsAwardHeadersInterface.csv | GMS_AWARD_HEADERS_INTERFACE | DMT_GMS_AWD_HEADERS_STG_TBL | DMT_GMS_AWD_HEADERS_TFM_TBL | ALIGNED |
| GmsAwardFundingInterface.csv | GMS_AWARD_FUNDING_INTERFACE | DMT_GMS_AWD_FUNDING_STG_TBL | DMT_GMS_AWD_FUNDING_TFM_TBL | ALIGNED |
| GmsAwardProjectsInterface.csv | GMS_AWARD_PROJECTS_INTERFACE | DMT_GMS_AWD_PROJECTS_STG_TBL | DMT_GMS_AWD_PROJECTS_TFM_TBL | ALIGNED |
| GmsAwardPersonnelInterface.csv | GMS_AWARD_PERSONNEL_INTERFACE | DMT_GMS_AWD_PERSONNEL_STG_TBL | DMT_GMS_AWD_PERSONNEL_TFM_TBL | ALIGNED |
| GmsAwardFundSrcInterface.csv | GMS_AWARD_FUND_SRC_INTERFACE | DMT_GMS_AWD_FUND_SRC_STG_TBL | DMT_GMS_AWD_FUND_SRC_TFM_TBL | ALIGNED |
| GmsAwardPrjFundSrcInterface.csv | GMS_AWARD_PRJ_FUND_SRC_INTERFACE | DMT_GMS_AWD_PRJ_FUND_SRC_STG_TBL | DMT_GMS_AWD_PRJ_FUND_SRC_TFM_TBL | ALIGNED |
| GmsAwardKeywordsInterface.csv | GMS_AWARD_KEYWORDS_INTERFACE | DMT_GMS_AWD_KEYWORDS_STG_TBL | DMT_GMS_AWD_KEYWORDS_TFM_TBL | ALIGNED |
| GmsAwardBdgtPeriodsInterface.csv | GMS_AWARD_BDGT_PRDS_INTERFACE | DMT_GMS_AWD_BDGT_PRDS_STG_TBL | DMT_GMS_AWD_BDGT_PRDS_TFM_TBL | NAME-SHORTENED (BDGT_PRDS = BudgetPeriods), model correct |
| GmsAwardCertsInterface.csv | GMS_AWARD_CERTS_INTERFACE | DMT_GMS_AWD_CERTS_STG_TBL | DMT_GMS_AWD_CERTS_TFM_TBL | ALIGNED |
| GmsAwardCfdasInterface.csv | GMS_AWARD_CFDAS_INTERFACE | DMT_GMS_AWD_CFDAS_STG_TBL | DMT_GMS_AWD_CFDAS_TFM_TBL | ALIGNED |
| GmsAwardFundAllocInterface.csv | GMS_AWARD_FUND_ALLOC_INTERFACE | DMT_GMS_AWD_FUND_ALLOC_STG_TBL | DMT_GMS_AWD_FUND_ALLOC_TFM_TBL | ALIGNED |
| GmsAwardOrgCreditsInterface.csv | GMS_AWARD_ORG_CREDITS_INTERFACE | DMT_GMS_AWD_ORG_CREDITS_STG_TBL | DMT_GMS_AWD_ORG_CREDITS_TFM_TBL | ALIGNED |
| GmsAwardPrjTaskBrdInterface.csv | GMS_AWARD_PRJ_TSK_BRD_INTERFACE | DMT_GMS_AWD_PRJ_TSK_BRD_STG_TBL | DMT_GMS_AWD_PRJ_TSK_BRD_TFM_TBL | NAME-SHORTENED (PRJ_TSK_BRD = PrjTaskBurden), model correct |
| GmsAwardReferencesInterface.csv | GMS_AWARD_REFERENCES_INTERFACE | DMT_GMS_AWD_REFERENCES_STG_TBL | DMT_GMS_AWD_REFERENCES_TFM_TBL | ALIGNED |
| GmsAwardTermsInterface.csv | GMS_AWARD_TERMS_INTERFACE | DMT_GMS_AWD_TERMS_STG_TBL | DMT_GMS_AWD_TERMS_TFM_TBL | ALIGNED |

**Why the two NAME-SHORTENED rows are correct, not wrong record types:**
`BDGT_PRDS` is "Budget Periods" and `PRJ_TSK_BRD` is "Project Task Burden", both
abbreviated only to stay within Oracle's 30-byte identifier limit for the
`DMT_GMS_AWD_*_TFM_TBL` pattern. Same record type as the tab, just abbreviated.

**Findings (what was fixed vs deferred):**
1. **NO spec-header fix needed.** The generator spec-header says "15 CSVs in one
   ZIP" and the body's numbered `gen_*_csv` comments + `REGISTER_CSV` calls name all
   fifteen real Oracle tabs. Accurate.
2. **DEFERRED (physical rename -- not warranted):** the two abbreviated names are
   forced by the identifier-length limit and are unambiguous; no rename.
3. **No NOT-MODELED gaps.** All fifteen CSVs the Grants import template defines have
   a STG table, a TFM table and a generator branch. (The catalog surfaces only two
   of them -- Award Headers + Award Projects -- in the console view by design; the
   other thirteen are still modeled and loaded, just not shown as separate console
   tiles. That is a display choice, not a modeling gap.)
