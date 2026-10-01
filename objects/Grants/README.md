# Grants

## Status
BLOCKED — demo instance grants module setup incomplete. Code and pipeline work correctly; Fusion rejects all awards with "requisite setup steps haven't been completed." Original "E2E LOADED" (2026-04-02) was a false positive from the absence=LOADED fallback bug.

## Pipeline
- Module: Projects
- FBDI Template: GmsAwardHeadersInterface.xlsm
- Interface Tables: GMS_AWARD_HEADERS_INTERFACE, GMS_AWARD_FUNDING_INTERFACE, GMS_AWARD_PROJECTS_INTERFACE, GMS_AWARD_PERSONNEL_INTERFACE, GMS_AWARD_FUND_SRC_INTERFACE, GMS_AWARD_PRJ_FUND_SRC_INTERFACE, GMS_AWARD_KEYWORDS_INTERFACE, GMS_AWARD_BDGT_PRDS_INTERFACE, GMS_AWARD_CERTS_INTERFACE, GMS_AWARD_CFDAS_INTERFACE, GMS_AWARD_FUND_ALLOC_INTERFACE, GMS_AWARD_ORG_CREDITS_INTERFACE, GMS_AWARD_PRJ_TSK_BRD_INTERFACE, GMS_AWARD_REFERENCES_INTERFACE, GMS_AWARD_TERMS_INTERFACE
- UCM Account: prj/grantsManagement/import
- ESS Job: AwardMassImportJob
- ParameterList: `#NULL,#NULL,#NULL` (3 optional args: award number LOV IDs + boolean)
- Loader Type: SQLLOADER
- Auth User: fin_impl

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
- Report request for the run-234 evidence chain: ESS 9773862 (child of import ESS 9773857).

## Known Issues
- ~~BIP reconciliation uses "absence=LOADED" pattern: Fusion purges interface table rows after successful import.~~ **RESOLVED 2026-04-02:** Switched to two-tier BIP (interface + base table). No more absence=LOADED.
- ~~Per-award rejection errors were unreadable after import (interface purged) — object left UNACCOUNTED.~~ **RESOLVED (run-234 fix):** reconciler now reads the Award Batch Import Report child (see above).

## Lessons Learned
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
| GmsAwardBudgetPeriodsInterface.csv | GMS_AWARD_BDGT_PRDS_INTERFACE | DMT_GMS_AWD_BDGT_PRDS_STG_TBL | DMT_GMS_AWD_BDGT_PRDS_TFM_TBL | NAME-SHORTENED (BDGT_PRDS = BudgetPeriods), model correct |
| GmsAwardCertsInterface.csv | GMS_AWARD_CERTS_INTERFACE | DMT_GMS_AWD_CERTS_STG_TBL | DMT_GMS_AWD_CERTS_TFM_TBL | ALIGNED |
| GmsAwardCfdasInterface.csv | GMS_AWARD_CFDAS_INTERFACE | DMT_GMS_AWD_CFDAS_STG_TBL | DMT_GMS_AWD_CFDAS_TFM_TBL | ALIGNED |
| GmsAwardFundAllocInterface.csv | GMS_AWARD_FUND_ALLOC_INTERFACE | DMT_GMS_AWD_FUND_ALLOC_STG_TBL | DMT_GMS_AWD_FUND_ALLOC_TFM_TBL | ALIGNED |
| GmsAwardOrgCreditsInterface.csv | GMS_AWARD_ORG_CREDITS_INTERFACE | DMT_GMS_AWD_ORG_CREDITS_STG_TBL | DMT_GMS_AWD_ORG_CREDITS_TFM_TBL | ALIGNED |
| GmsAwardPrjTaskBurdenInterface.csv | GMS_AWARD_PRJ_TSK_BRD_INTERFACE | DMT_GMS_AWD_PRJ_TSK_BRD_STG_TBL | DMT_GMS_AWD_PRJ_TSK_BRD_TFM_TBL | NAME-SHORTENED (PRJ_TSK_BRD = PrjTaskBurden), model correct |
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
