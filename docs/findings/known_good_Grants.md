# Grants (Award Import) — known-good comparison

**Date:** 2026-10-07. Investigation only. No DMT code, seed, scenario or local-DB change was
made. All Fusion reads were read-only BIP queries; the four Fusion submissions below were made
outside the DMT pipeline by a standalone script.

## Bottom line

Grants does load on the demo pod. The owner's known-good run (process 10070355) and our own
replay of it (load 10073629 / import 10073644) both created awards in the base tables.

DMT loads nothing for three separate reasons, in the order Fusion hits them:

1. **Wrong Fusion user.** DMT submits Grants as `FIN_IMPL`. The known-good run was submitted as
   `PPM_IMPL`. We replayed the identical known-good award as `FIN_IMPL` and Fusion rejected it with
   exactly the error every DMT regression gets: *"The award contract can't be created because
   requisite setup steps haven't been completed."* As `PPM_IMPL` the same data loads. So the
   "Grants is not configured on the demo" conclusion was wrong; the setup is complete for
   `PPM_IMPL`, and `FIN_IMPL` is simply not set up as a contract resource for the award business unit.
2. **The regression data is too thin.** When DMT's own run-238 file is replayed as `PPM_IMPL`, the
   two good awards get past the setup check and are rejected for missing children: *"No project is
   associated to this award. You must associate at least one project to the award."* The known-good
   award carries funding source, project, project funding source, budget period, funding,
   funding allocation and organization credit rows. The DMT regression only carries a header and a
   personnel row.
3. **Two FBDI file names are wrong in the generator, and the reconciler cannot see a successful
   award.** These have not bitten yet only because nothing has loaded so far. Details below.

The ESS parameters themselves are not the problem: they match the known-good run except for one
Yes/No flag that only controls whether the report lists successes.

## Step 1 — ESS parameter comparison

### Known-good chain (Fusion `fusion_ora_ess.request_history` + `request_property`)

| Request | Job | Parent | Submitter | State |
|---|---|---|---|---|
| 10070343 | InterfaceLoaderController (Load Interface File for Import) | 0 | PPM_IMPL | SUCCEEDED |
| 10070344 | InterfaceLoaderAsyncJob | 10070343 | PPM_IMPL | SUCCEEDED |
| 10070345–10070353 | InterfaceLoaderSqlldrImport ×9 (BDGT_PRDS, FUND_ALLOC, FND_SRC, FUNDING, HEADERS, DEPT_CRDTS, PERSONNEL, PRJ_FND_SRC, PROJECTS) | 10070343 | PPM_IMPL | SUCCEEDED |
| 10070355 | AwardMassImportJob | 0 | PPM_IMPL | SUCCEEDED — TOTAL 5 / SUCCESS 5 / ERROR 0 |
| 10070356 | ImportAwardReportJob (`/Projects/Grants Management/Award/AwardBatchImportReport.xdo`) | 0 | PPM_IMPL | SUCCEEDED |

The load and the import were submitted separately from the UI. DMT submits both in one
`loadAndImportData` call, which chains the same two jobs; the replay below proves that route works.

### DMT chain (local `DMT_ESS_JOB_TBL`, runs 229 / 236 / 238 — identical shape)

| Run | Load | SqlLdr children | Import | Report | Submitter | Import result |
|---|---|---|---|---|---|---|
| 229 | 10065795 | 2 (headers, personnel) | 10065809 | 10065815 | FIN_IMPL | 3 errors |
| 236 | 10069795 | 2 | 10069808 | 10069817 | FIN_IMPL | 3 errors |
| 238 | 10070678 | 2 | 10070691 | 10070699 | FIN_IMPL | TOTAL 3 / SUCCESS 0 / ERROR 3 |

DMT's parameters come from `DMT_LOADER_PKG.RUN_GRANTS` (`fin_after_generate(..., '#NULL,#NULL,#NULL')`)
and seed row 57 of `DMT_ERP_INTERFACE_OPTIONS_TBL` (`prj/grantsManagement/import`,
`AwardMassImportJob`, `FUSION_USERNAME` = NULL, so the global `FIN_IMPL` is used).

### Side by side

| Job | Position | Meaning | Known-good value | DMT value (run 238, read back from Fusion) | Difference |
|---|---|---|---|---|---|
| Load Interface File | 1 | Interface options id | 57 | 57 | none |
| Load Interface File | 2 | UCM document id | 7889038 | 7889391 | none (per-upload value) |
| Load Interface File | 3 | flag | N | N | none |
| Load Interface File | 4 | flag | N | N | none |
| Load Interface File | 5 | data file | GmsAwardsImport.zip | Grants_238.zip | name only, not significant |
| AwardMassImportJob | 1 | From award number | (blank) | (blank, sent as `#NULL`) | none |
| AwardMassImportJob | 2 | To award number | (blank) | (blank, sent as `#NULL`) | none |
| AwardMassImportJob | 3 | Report success details | `true` | (blank, sent as `#NULL`) | **differs** — constant Yes/No flag; only adds a success list to the report |
| ImportAwardReportJob | 1 | Import request id | 10070355 | 10070691 | none (spawned by Fusion) |
| ImportAwardReportJob | 4 | Report success records | Y | N | follows import position 3 |
| (all) | — | **Submitting user** | **PPM_IMPL** | **FIN_IMPL** | **differs — this is the blocker** |

No business values (business unit, organization, ledger) are ESS parameters for this job. The
business unit, legal entity, organization and burden schedule all travel in the data file, so the
owner's no-hardcoding rule is already satisfied and Grants does not need to partition by business
unit. Award import accepts several business units in one file.

## Step 2 — the known-good file

### How the template builds it

`ImportAwards.xlsm` has one data sheet per record type. Its macro writes one CSV per non-empty
sheet, named from a fixed list (`dataOnlySheets(0..14)`), appends a literal `END` column to every
row, writes no header row, and zips the result as `GmsAwardsImport.zip`. For the Awards, Award
Projects and Award Funding sheets it first reorders columns to the fixed CTL order; every other
sheet is copied as-is from row 5.

The template's file names (from the macro) versus DMT's generator (`DMT_GRANTS_FBDI_GEN_PKG.GENERATE_FBDI`):

| Template CSV name (what Fusion's loader expects) | DMT generator CSV name | Match |
|---|---|---|
| GmsAwardHeadersInterface | GmsAwardHeadersInterface.csv | yes |
| GmsAwardFundSrcInterface | GmsAwardFundSrcInterface.csv | yes |
| GmsAwardProjectsInterface | GmsAwardProjectsInterface.csv | yes |
| GmsAwardPrjFundSrcInterface | GmsAwardPrjFundSrcInterface.csv | yes |
| GmsAwardKeywordsInterface | GmsAwardKeywordsInterface.csv | yes |
| GmsAwardReferencesInterface | GmsAwardReferencesInterface.csv | yes |
| GmsAwardCertsInterface | GmsAwardCertsInterface.csv | yes |
| GmsAwardTermsInterface | GmsAwardTermsInterface.csv | yes |
| GmsAwardCfdasInterface | GmsAwardCfdasInterface.csv | yes |
| **GmsAwardBdgtPeriodsInterface** | **GmsAwardBudgetPeriodsInterface.csv** | **NO** |
| GmsAwardOrgCreditsInterface | GmsAwardOrgCreditsInterface.csv | yes |
| GmsAwardPersonnelInterface | GmsAwardPersonnelInterface.csv | yes |
| GmsAwardFundingInterface | GmsAwardFundingInterface.csv | yes |
| GmsAwardFundAllocInterface | GmsAwardFundAllocInterface.csv | yes |
| **GmsAwardPrjTaskBrdInterface** | **GmsAwardPrjTaskBurdenInterface.csv** | **NO** |

The known-good zip's budget-period file is `GmsAwardBdgtPeriodsInterface.csv` and Fusion loaded it
into `GMS_AWARD_BDGT_PRDS_INT` (SqlLdr child 10070345). A file with DMT's name would not be
matched to a control file. Budget periods are mandatory for an award (the gold-regression notes
record `GMS_BP_ONE_EXISTS`, "You must define at least one budget period", which is what a
mis-named budget-period file produces).

### Column positions

Column-for-column, the DMT generator matches the template for every record type the known-good
file uses. The only layout difference is the template's trailing `END` column, which the control
files ignore (they end with `TRAILING NULLCOLS`; `END` falls past the last mapped field). DMT also
encloses every value in double quotes, which the control files accept (`OPTIONALLY ENCLOSED BY '"'`).

| CSV | Known-good columns | DMT columns | Same order |
|---|---|---|---|
| GmsAwardHeadersInterface | 124 + END | 124 | yes |
| GmsAwardFundSrcInterface | 8 + END | 8 | yes |
| GmsAwardProjectsInterface | 56 + END | 56 | yes |
| GmsAwardPrjFundSrcInterface | 5 + END | 5 | yes |
| GmsAwardBdgtPeriodsInterface | 4 + END | 4 | yes (wrong file name) |
| GmsAwardOrgCreditsInterface | 4 + END | 4 | yes |
| GmsAwardPersonnelInterface | 61 + END | 61 | yes |
| GmsAwardFundingInterface | 10 + END | 10 | yes |
| GmsAwardFundAllocInterface | 4 + END | 4 | yes |

### Data differences (known-good award vs DMT regression award, header row)

| Header column | Known-good (AWDTST04B) | DMT run 238 (RTGNT001) |
|---|---|---|
| 3 Source template | 1 Year Award | 1 Year Award |
| 4 Business unit | Progress US Business Unit | Progress US Business Unit |
| 5 Legal entity | Progress US Legal Entity | Progress US Legal Entity |
| 6 Contract type | (blank — inherited from template) | Sell: Project Award Hard Limit |
| 7 Primary sponsor | State Government | Department of Homeland Security |
| 10 PI number | 1308 | (blank; PI only on personnel row, Sean Murphy 1171) |
| 11–12 Dates | 09/01/2026 – 09/01/2027 | 01/01/2025 – 12/31/2025 |
| 14 Organization | Maintenance Prg US | (blank) |
| 19 Expanded authority | Y | (blank) |
| 21 Default burden schedule | Progress US Burden Schedule | (blank) |
| 66 ATTRIBUTE20 | (blank) | DMT:238:... reference token |
| Child files | FundSrc, Projects, PrjFundSrc, BdgtPeriods, OrgCredits, Personnel, Funding, FundAlloc | Personnel only |

### Standalone replays (outside DMT, same `loadAndImportData` call DMT makes)

Script: `objects/Grants/known_good/kg_grants_standalone.py` (uses the gold-regression harness's
`load_fbdi.submit_load` / `poll`, interface id 57, account `prj/grantsManagement/import`,
job `/oracle/apps/ess/projects/grantsManagement/award,AwardMassImportJob`). Before submitting,
`OKC_K_HEADERS_ALL_B` was checked: no contract number began with 77101 or 77102. Award numbers were
prefixed (`77101AWDTST01B` ...) and award names prefixed (`77101 DOE Test AWD 1B` ...).

| Replay | User | ParameterList | Content | Load | Import | Report | Result |
|---|---|---|---|---|---|---|---|
| A | ppm_impl | `#NULL,#NULL,true` | known-good, 5 awards + 1 BAD | 10073629 | 10073644 | 10073652 | **5 created, 1 rejected** |
| B | fin_impl | `#NULL,#NULL,true` | known-good award 3 only | 10073661 | 10073674 | 10073679 | 0 created — "requisite setup steps haven't been completed" |
| C | ppm_impl | `#NULL,#NULL,#NULL` (DMT's) | DMT run-238 CSVs re-prefixed 77103 | 10073688 | 10073694 | 10073695 | 0 created — goods: "No project is associated to this award..."; BAD: "You must provide a value for the Business Unit attribute." |
| D | ppm_impl | `#NULL,#NULL,true` | award 3 renumbered 77104 but reusing replay A's award name | — | — | — | created (id 300000334921346): award names need not be unique, only numbers |

Replay B against replay A isolates the user as the cause: same data, same parameters, only the user
changed. Replay C shows DMT's `#NULL,#NULL,#NULL` parameter list is fine and that, once the user is
fixed, the next blocker is the missing child rows.

#### Replay A — base-table evidence (GOOD)

Award number is `OKC_K_HEADERS_ALL_B.CONTRACT_NUMBER` (version_type `C`), joined on
`OKC_K_HEADERS_ALL_B.ID = GMS_AWARD_HEADERS_B.ID`. Child counts are rows in each base table for
that award id.

| Award number | GMS_AWARD_HEADERS_B.ID | Budget periods | Funding sources | Projects | Personnel | Dept credits | Fundings | Fund allocations |
|---|---|---|---|---|---|---|---|---|
| 77101AWDTST01B | 300000334921091 | 5 | 2 | 1 | 2 | 2 | 10 | 10 |
| 77101AWDTST02B | 300000334921137 | 1 | 1 | 1 | 2 | 2 | 1 | 1 |
| 77101AWDTST03B | 300000334921164 | 1 | 1 | 2 | 2 | 3 | 1 | 2 |
| 77101AWDTST04B | 300000334921202 | 1 | 1 | 1 | 2 | 2 | 1 | 1 |
| 77101AWDTST05B | 300000334921234 | 1 | 1 | 1 | 2 | 2 | 1 | 1 |

All five are `AWARD_SOURCE='FBDI'`, business unit 300000075888561 (Progress US), created by
`PPM_IMPL` at 2026-10-07 14:45. Budget-period ids for 77101AWDTST01B are 300000334921092–096
(Period 1–5, 2026-09-01 → 2031-09-01).

#### Replay A — BAD record

`77101AWDTST06X` is a copy of award 4 with primary sponsor `No Such Sponsor DMT`. It is absent from
`GMS_AWARD_HEADERS_B` / `OKC_K_HEADERS_ALL_B`. Fusion's Award Batch Import Report (request
10073652, `/DATA_DS/LIST_G_4/G_4`, saved as `award_batch_import_report_10073652.xml`) records:

> `PARENT_AWARD_NUMBER` 77101AWDTST06X — `PROCESSED_MESSAGE`: "The value of the attribute Primary Sponsor isn't valid."

Report header: TOTAL_COUNT 6, SUCCESS_COUNT 5, FAILURE_COUNT 1, BATCH_STATUS `COMPLETED W/ERRORS`.
This is the same place `DMT_GRANTS_RESULTS_PKG` already reads rejections from.

## Two more facts the replays exposed

1. **`FIN_IMPL` cannot poll or download a `PPM_IMPL` request.** `getESSJobStatus` on 10073644 and
   `downloadESSJobExecutionDetails` on 10073652 as `fin_impl` both return HTTP 500
   (`FND_CMN_SYS_ERR`). As `ppm_impl` both work. BIP reads of `fusion_ora_ess.request_history` work
   for `fin_impl`.
2. **A successful FBDI award carries no request id and no sponsor award number.** On all ten
   known-good awards (AWDTST01A–05A, 01B–05B) and the five replay awards, `GMS_AWARD_HEADERS_B.DC_REQUEST_ID`,
   `SUMMARY_REQUEST_ID`, `SPONSOR_AWARD_NUMBER`, `ATTRIBUTE1`, `ATTRIBUTE20` and
   `OKC_K_HEADERS_ALL_B.REQUEST_ID` are all NULL. The DMT base-tier BIP query
   (`bip/Grants/DMT_GRANT_RECON_DM.xdm`) filters `b.dc_request_id = :P_IMPORT_ESS_ID` and keys on
   `NVL(sponsor_award_number, 'AWARD_ID:'||id)`, and the transform stamps `RECON_KEY =
   SPONSOR_AWARD_NUMBER`. A successfully created award would therefore never be found, and every good
   row would stay UNACCOUNTED even after the user fix. (The data model comment also says no
   `GMS_AWARD_PROJ%` table exists; `GMS_AWARD_PROJECTS` does exist and holds the replay's links.)

## Code changes needed (not made — listed for the main session)

1. **`db/seed/dmt_erp_interface_options_tbl.sql`, row 57 (Grants / Award):** set
   `FUSION_USERNAME = 'ppm_impl'` and `FUSION_PASSWORD = '***MASKED-SET-ME***'` (same pattern as the
   `calvin.roth` rows). `db/tools/setup_runtime_config.py` already fills the real password from
   `connections.json` by username. `fin_after_generate` and `DMT_QUEUE_WORKER_PKG` already submit and
   poll with `DMT_UTIL_PKG.GET_CEMLI_CREDENTIALS`, so this alone moves the submit and the polling to
   `PPM_IMPL`.
2. **`db/packages/dmt_ess_util_pkg.pkb.sql`, `CAPTURE_REPORT_ESS_JOB`:** the bounded
   `getESSJobStatus` poll of the report child uses the global credentials via `soap_http`. It must use
   `DMT_UTIL_PKG.GET_CEMLI_CREDENTIALS(p_cemli_code, ...)`, otherwise the poll gets HTTP 500 for every
   `PPM_IMPL` report request.
3. **`db/packages/dmt_ess_util_pkg.pkb.sql` / `.pks.sql`, `GET_ESS_OUTPUT_XML`:** add optional
   `p_username` / `p_password` and pass them to `GET_ESS_ZIP` (which already accepts them).
   **`db/packages/dmt_grants_results_pkg.pkb.sql`** (line ~165, `GET_ESS_OUTPUT_XML(l_report_ess_id)`):
   fetch `GET_CEMLI_CREDENTIALS('Grants', ...)` and pass them, so the Award Batch Import Report can be
   downloaded.
4. **`bip/Grants/DMT_GRANT_RECON_DM.xdm` (+ mirror `bip/Grants/query.sql`), BASE tier:** join
   `okc_k_headers_all_b k ON k.id = b.id AND k.version_type = 'C'`, use `k.contract_number` as
   `RECORD_KEY`, and scope by `k.contract_number LIKE :P_PREFIX || '%' AND b.award_source = 'FBDI'`
   instead of `b.dc_request_id = :P_IMPORT_ESS_ID` (that column is NULL for FBDI awards). Per the
   never-overwrite rule, deploy it as a new version alongside the current report and repoint the
   registry. **`db/packages/dmt_grants_transform_pkg.pkb.sql`, `TRANSFORM_HEADERS`:** stamp
   `RECON_KEY` = the prefixed `AWARD_NUMBER` (not `SPONSOR_AWARD_NUMBER`) so it matches the new key.
5. **`db/packages/dmt_grants_fbdi_gen_pkg.pkb.sql`, `GENERATE_FBDI`:** rename
   `GmsAwardBudgetPeriodsInterface.csv` → `GmsAwardBdgtPeriodsInterface.csv` (file seq 8) and
   `GmsAwardPrjTaskBurdenInterface.csv` → `GmsAwardPrjTaskBrdInterface.csv` (file seq 13), matching
   the Oracle template macro. Also correct `objects/Grants/README.md` (it repeats the wrong names) and
   `gold_regression/objects/Grants/recipe.json` (its budget-period CSV uses the wrong name, which
   explains its `GMS_BP_ONE_EXISTS` failures).
6. **Optional, constant flag only — `db/packages/dmt_loader_pkg.pkb.sql`, `RUN_GRANTS`:** change the
   import ParameterList from `#NULL,#NULL,#NULL` to `#NULL,#NULL,true` to match the known-good run.
   Not required to load (replay C proves `#NULL` is accepted); it makes the Award Batch Import Report
   also list successful awards (`LIST_G_3`), a second success signal next to the base-table read.

After 1–5 the regression also needs the richer data below; with the current header-plus-personnel
rows, Fusion will (correctly) reject the good awards for having no project.

## Proposed regression rows

For the new combined scenario (do not edit the existing write-once scenario). Values mirror
known-good awards AWDTST04B and AWDTST02B. `AWARD_NUMBER` is the raw key; the transform adds the
run prefix to it in every record type. Project numbers are existing Fusion projects and must not be
prefixed (the transform passes them through `DMT_XREF_PKG.PROJECT_NUMBER`, which returns the source
value when there is no cross-reference). Dates are `MM/DD/YYYY` as the transform/generator expect
for the STG date columns. Award names need not be unique.

### DMT_GMS_AWD_HEADERS_STG_TBL

| Column | GOOD 1 | GOOD 2 | BAD 1 |
|---|---|---|---|
| AWARD_NAME | RT Award Good-1 State | RT Award Good-2 AHA | RT Award Bad-1 Sponsor |
| AWARD_NUMBER | RTAWD-G1 | RTAWD-G2 | RTAWD-BAD1 |
| SOURCE_TEMPLATE_NUMBER | 1 Year Award | 5 Year Award | 1 Year Award |
| BUSINESS_UNIT | Progress US Business Unit | Progress US Business Unit | Progress US Business Unit |
| LEGAL_ENTITY | Progress US Legal Entity | Progress US Legal Entity | Progress US Legal Entity |
| CONTRACT_TYPE | (null) | (null) | (null) |
| PRIMARY_SPONSOR | State Government | American Heart Association | **No Such Sponsor DMT** |
| PI_NUMBER | 1308 | 1308 | 1308 |
| AWARD_START_DATE | 09/01/2026 | 09/01/2026 | 09/01/2026 |
| AWARD_END_DATE | 09/01/2027 | 09/01/2031 | 09/01/2027 |
| ORGANIZATION | Maintenance Prg US | Maintenance Prg US | Maintenance Prg US |
| EXPANDED_AUTHORITY_FLAG | Y | Y | Y |
| DEFAULT_BURDEN_SCHEDULE | Progress US Burden Schedule | Progress US Burden Schedule | Progress US Burden Schedule |
| CURRENCY_CODE | USD | USD | USD |

Expected: GOOD 1 and GOOD 2 LOADED (row in `GMS_AWARD_HEADERS_B` via `OKC_K_HEADERS_ALL_B.CONTRACT_NUMBER`).
BAD 1 FAILED with "The value of the attribute Primary Sponsor isn't valid." (proven in replay A).

### DMT_GMS_AWD_FUND_SRC_STG_TBL

| AWARD_NUMBER | FUNDING_SOURCE_NAME |
|---|---|
| RTAWD-G1 | State Government |
| RTAWD-G2 | American Heart Association |
| RTAWD-BAD1 | State Government |

### DMT_GMS_AWD_PROJECTS_STG_TBL

| AWARD_NUMBER | FUNDING_SOURCE_NAME | PROJECT_NUMBER |
|---|---|---|
| RTAWD-G1 | (null) | PRG10008 |
| RTAWD-G2 | (null) | CAP10001 |
| RTAWD-BAD1 | (null) | PRG10008 |

### DMT_GMS_AWD_PRJ_FUND_SRC_STG_TBL

| AWARD_NUMBER | PROJECT_NUMBER | FUNDING_SOURCE_NAME |
|---|---|---|
| RTAWD-G1 | PRG10008 | State Government |
| RTAWD-G2 | CAP10001 | American Heart Association |
| RTAWD-BAD1 | PRG10008 | State Government |

### DMT_GMS_AWD_BDGT_PRDS_STG_TBL

| AWARD_NUMBER | BUDGET_PERIOD | START_DATE | END_DATE |
|---|---|---|---|
| RTAWD-G1 | Period 1 | 09/01/2026 | 09/01/2027 |
| RTAWD-G2 | Period 1 | 09/01/2026 | 09/01/2031 |
| RTAWD-BAD1 | Period 1 | 09/01/2026 | 09/01/2027 |

### DMT_GMS_AWD_ORG_CREDITS_STG_TBL

| AWARD_NUMBER | PROJECT_NUMBER | ORGANIZATION | CREDIT_PERCENTAGE |
|---|---|---|---|
| RTAWD-G1 | PRG10008 | Maintenance Prg US | 100 |
| RTAWD-G2 | CAP10001 | Maintenance Prg US | 100 |
| RTAWD-BAD1 | PRG10008 | Maintenance Prg US | 100 |

### DMT_GMS_AWD_PERSONNEL_STG_TBL

| AWARD_NUMBER | PROJECT_NUMBER | INTERNAL | PERSON_EMAIL | ROLE | START_DATE | END_DATE | CREDIT_PERCENTAGE |
|---|---|---|---|---|---|---|---|
| RTAWD-G1 | (null) | Y | brock.phillips_esew-dev28@oraclepdemos.com | Principal Investigator | 09/01/2026 | 09/01/2027 | 100 |
| RTAWD-G2 | (null) | Y | brock.phillips_esew-dev28@oraclepdemos.com | Principal Investigator | 09/01/2026 | 09/01/2031 | 100 |
| RTAWD-BAD1 | (null) | Y | brock.phillips_esew-dev28@oraclepdemos.com | Principal Investigator | 09/01/2026 | 09/01/2027 | 100 |

### DMT_GMS_AWD_FUNDING_STG_TBL

| AWARD_NUMBER | BUDGET_PERIOD_NAME | FUNDING_SOURCE_NAME | ISSUE_TYPE | ISSUE_NUMBER | ISSUE_DATE | DIRECT_FUNDING_AMOUNT |
|---|---|---|---|---|---|---|
| RTAWD-G1 | Period 1 | State Government | Base | Base 1 | 09/01/2026 | 500000 |
| RTAWD-G2 | Period 1 | American Heart Association | Base | Base 1 | 09/01/2026 | 750000 |
| RTAWD-BAD1 | Period 1 | State Government | Base | Base 1 | 09/01/2026 | 500000 |

### DMT_GMS_AWD_FUND_ALLOC_STG_TBL

| AWARD_NUMBER | PROJECT_NUMBER | ISSUE_NUMBER | FUNDING_AMOUNT |
|---|---|---|---|
| RTAWD-G1 | PRG10008 | Base 1 | 500000 |
| RTAWD-G2 | CAP10001 | Base 1 | 750000 |
| RTAWD-BAD1 | PRG10008 | Base 1 | 500000 |

## Artefacts (`objects/Grants/known_good/`)

| File | What it is |
|---|---|
| GmsAwardsImport.zip | The owner's submitted zip, unchanged |
| ImportAwards.xlsm | The owner's FBDI template, unchanged |
| writeup_excerpt.txt | The owner's writeup line plus the Fusion facts read back for 10070355 |
| GmsAwardsImport_prefixed_77101_good5_bad1.zip | Replay A file: 5 prefixed good awards + BAD 77101AWDTST06X |
| GmsAwardsImport_prefixed_77102_fin_impl_test.zip | Replay B file (the user-isolation test) |
| award_batch_import_report_10073652.xml | Fusion's Award Batch Import Report for replay A |
| evidence_77101.json / evidence_77102.json / evidence_77103.json | Request ids, import counts, report rows and base-table ids for replays A, B, C |
| kg_grants_standalone.py | The standalone submit script (written to run from a scratch folder at the repo root; paths are relative to that) |
