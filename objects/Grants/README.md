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
