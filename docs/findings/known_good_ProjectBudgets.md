# Known-good comparison: ProjectBudgets

**Date:** 2026-10-07. **Known-good run:** owner's Fusion UI run, Import Project Budgets request **10071416** (submitter `brock.phillips`). **DMT runs compared:** 229, 236, 238 (every GOOD row FAILED). Artefacts are in `objects/ProjectBudgets/known_good/` (original zip, xlsm, macro source, writeup excerpt, the four standalone variants, and the Fusion import reports).

## Bottom line

There are two independent reasons DMT loads nothing for ProjectBudgets, and one more problem that would hide a success once those two are fixed.

1. **The FBDI generator leaves CSV column 29 empty, but it must carry the template marker `-1318020000`.** The template's `GenCSV` macro writes `-1318020000` into column 29 of every row, or `-1318020001` when any descriptive flexfield attribute is filled in. Without that marker, Fusion reads the file differently. When I submitted the identical known-good rows in DMT's layout, the PRG00008 lines lost their quantities (`PJO_XFACE_AMT_MISSING`, "You must enter either a cost amount, revenue amount...") and CFIT022 failed with `PJO_XFACE_GENERIC_ERROR`. Adding only the marker to the same DMT-layout file made it behave exactly like the known-good file. This is a code defect. The value is a template-format constant, not a business value.
2. **The regression data cannot succeed.** The GOOD rows use the financial plan type `Approved Cost Budget` on the in-run RT projects, which have the sponsored project type `PRGUS Funded with Burden`. Fusion rejects that with `PJO_FPT_CANT_BUD_SPON_PRJ` ("...because it's either approved or enabled for budgetary control"). I reproduced this outside the tool with the marker fixed (variant D). The rows also leave `RESOURCE_NAME`, `LINE_TYPE` and `PROCESSING_MODE` empty, whereas the template marks Resource Name as required and the known-good file fills in all three.
3. **Reconciliation would not see a GOOD row that mirrors the known-good record.** The recon data model scopes its BASE tier with `pjf_projects_all_b.segment1 LIKE :P_PREFIX || '%'`, so it only finds budgets on projects that DMT created in the same run. The known-good budgets are on existing projects (CFIT022, PRG00008, PRG10008). Neither the source budget line reference nor the plan version name is prefixed, so nothing ties a budget on an existing project to the run.

The ESS parameters are **not** a cause. DMT's load and import submissions are functionally the same as the known-good run's. No business value is passed as an ESS parameter, so ProjectBudgets needs no partitioning.

## Step 1: ESS job chain and parameters

Source: `fusion.ess_request_history` and `fusion.ess_request_property`, read live through `scripts/fusion_bip_query.py --cred fin_impl`. DMT side: `DMT_ESS_JOB_TBL` (local DMT2 DB, read-only) plus the same Fusion property rows for DMT's request ids.

**Job chain.** The two chains have the same shape. The extra children in the known-good run (PjsSumMainJobDefNonBIP, BudgetImportReport) only appear when at least one plan version is created, and they appeared in my standalone runs too.

| Step | Known-good (owner, UI) | DMT run 238 (loadAndImportData) |
|---|---|---|
| Load Interface File for Import (InterfaceLoaderController) | 10071413, `brock.phillips` | 10070679, `FIN_IMPL` |
|  - InterfaceLoaderAsyncJob | 10071414 | 10070682 |
|  - InterfaceLoaderSqlldrImport | 10071415 | 10070686 |
| ImportBudgetsInterfaceData (parent 0) | **10071416** | 10070693 |
| PjsSumMainJobDefNonBIP (summarisation) | 10071417 | not spawned (0 versions created) |
| BudgetImportReport (`/Financials/Budgetary Control/BudgetImport.xdo`, args `PPM,,,,<import id>,SINGLE_PERIOD,PURGE`) | 10071418 | not spawned |
| BudgetsXfaceBIP (`/Projects/Project Budget/ImportBudget.xdo`, arg4 = import id) | 10071419 | 10070698 |

**Load job (InterfaceLoaderController) arguments**

| Pos | Known-good 10071413 | DMT 10070679 | Difference |
|---|---|---|---|
| 1 | `39` (ERP_INTERFACE_OPTIONS_ID, Import Project Budgets) | `39` | none |
| 2 | `7889928` (UCM document id) | `7889392` | per-upload id, expected |
| 3 | `N` | `N` | none |
| 4 | `N` | `N` | none |
| 5 | `PjoBudgetsXface.zip` (UI display attribute) | absent | UI-only display attribute; no effect (standalone runs proved this) |

**Import job (ImportBudgetsInterfaceData) arguments**

| Pos | Known-good 10071416 | DMT 10070693 (ParameterList `#NULL`) | Difference |
|---|---|---|---|
| 1 | empty | empty | none |
| 2-12 | all empty (UI submits 12 empty args) | not sent | none in effect. Every argument is empty either way, and standalone runs A and C used DMT's exact `#NULL` jobList and produced the same base-table result as the known-good run |

**Code that builds the call:** `DMT_LOADER_PKG.RUN_PROJECT_BUDGETS` → `fin_after_generate(..., '#NULL')` → `SUBMIT_LOAD` (loadAndImportData, account `prj/projectControl/import`, interfaceDetails `39`, JobName `/oracle/apps/ess/projects/control/budgetsAndForecasts,ImportBudgetsInterfaceData`). The seed is `DMT_ERP_INTERFACE_OPTIONS_TBL` row 39 (REPORT_JOB_DEF `BudgetsXfaceBIP`). **There are no hardcoded business values in the ParameterList.** Business unit, project, plan type and version all come from the CSV rows, so partitioning is not required.

## Step 2: CSV and column comparison

The template's macro (`GenCSV`, source in `known_good/original/ProjectBudgetsImportTemplate_GenCSV_macro.txt`) copies the data sheet `PJO_BUDGETS_XFACE` into a 63-column CSV `PjoBudgetsXface.csv`. In the table below, "sheet col" is the column on the template's data sheet.

| CSV pos | Field (sheet col) | Known-good value (CFIT022 row) | DMT generator emits | Match? |
|---|---|---|---|---|
| 1 | Award Number (B) | (blank; `EUC0001` on PRG10008) | AWARD_NUMBER | yes |
| 2 | Financial Plan Type (C) | Cost and Revenue Budget | FINANCIAL_PLAN_TYPE | yes |
| 3 | Project Number (D) | CFIT022 | PROJECT_NUMBER | yes |
| 4 | Project Name (E) | blank | PROJECT_NAME | yes |
| 5 | Task Name (G) | blank | TASK_NAME | yes |
| 6 | Task Number (F) | CFIT022 | TASK_NUMBER | yes |
| 7 | Plan Version Name (I) | Version 3 | PLAN_VERSION_NAME | yes |
| 8 | Plan Version Description (J) | blank | PLAN_VERSION_DESCRIPTION | yes |
| 9 | Plan Version Status (K) | Baseline | PLAN_VERSION_STATUS | yes |
| 10 | Resource Name (L) | Financial Resources | RESOURCE_NAME | yes |
| 11 | Period Name (P) | blank (`JAN-26` on PERIODIC rows) | PERIOD_NAME | yes |
| 12 | Planning Currency (S) | USD | PLANNING_CURRENCY | yes |
| 13 | Quantity (T) | blank (`700` on PRG00008) | TOTAL_QUANTITY | yes |
| 14 | Raw Cost (U) | 70000.00000000 | TOTAL_TC_RAW_COST | yes |
| 15 | Revenue (W) | 80000.00000000 | TOTAL_TC_REVENUE | yes |
| 16 | Source Budget Line Reference (AD) | KTM_PRJBUDGET01 | SRC_BUDGET_LINE_REFERENCE | yes |
| 17 | Funding Source Number (M) | blank | FUNDING_SOURCE_NUMBER | yes |
| 18 | Funding Source Name (N) | blank (`European Commission` on PRG10008) | FUNDING_SOURCE_NAME | yes |
| 19 | Raw Cost in Project Currency (X) | blank | PC_RAW_COST | yes |
| 20 | Revenue in Project Currency (Z) | blank | PC_REVENUE | yes |
| 21 | Raw Cost in Project Ledger Currency (AA) | blank | PFC_RAW_COST | yes |
| 22 | Revenue in Project Ledger Currency (AC) | blank | PFC_REVENUE | yes |
| 23 | Burdened Cost (V) | blank | TOTAL_TC_BRDND_COST | yes |
| 24 | Burdened Cost in Project Currency (Y) | blank | PC_BRDND_COST | yes |
| 25 | Burdened Cost in Project Ledger Currency (AB) | blank | PFC_BRDND_COST | yes |
| 26 | Line Type (O) | LINE (`PERIODIC` on the others) | LINE_TYPE | yes |
| 27 | Start Date (Q) | 2026/01/01 | PLANNING_START_DATE `YYYY/MM/DD` | yes |
| 28 | Finish Date (R) | 2028/01/01 | PLANNING_END_DATE | yes |
| **29** | **template marker (macro `tempVersion`)** | **`-1318020000`** (`-1318020001` when any DFF attribute is filled in) | **`""` (comment says "REQUEST_ID auto-populated")** | **NO. This is the defect.** |
| 30-60 | Attribute Category, Attribute1-30 (AE-BI) | blank | ATTRIBUTE_CATEGORY, ATTRIBUTE1-30 | yes |
| 61 | Plan Version Number (H) | blank | PLAN_VERSION_NUMBER | yes |
| 62 | Processing Mode (A) | Create | PROCESSING_MODE | yes |
| 63 | `END` | END | not emitted | harmless (variant C has no END and succeeded) |

Other format differences, all shown to be harmless by variant C: DMT quotes every field, uses LF line endings instead of CRLF, emits 62 columns instead of 63, and names the CSV `PjoPlanVersionsXface.csv` instead of `PjoBudgetsXface.csv`. The loader selects the control file by interface id 39, not by the file name.

**DMT's actual generated file for run 238** is in `known_good/original/dmt_generated_run238_PjoPlanVersionsXface.csv`. Apart from column 29, its data differs from the known-good file in these ways: plan type `Approved Cost Budget` on sponsored RT projects; status `Working`; Resource Name, Line Type, Task and Processing Mode all empty; period `01-25`; raw cost only.

## Step 2: standalone submissions outside DMT

Tool: `known_good/tools/submit_standalone.py`. It makes the same loadAndImportData SOAP call that `DMT_LOADER_PKG.SUBMIT_LOAD` builds (account `prj/projectControl/import`, interfaceDetails 39, ImportBudgetsInterfaceData, ParameterList `#NULL`) as `fin_impl`, with credentials read from `connections.json` through `conn_helper`. It polls the load and the import, then reads the base tables live.

Before submitting, I applied a unique prefix to the plan version name (column 7) and the source budget line reference (column 16). Before use I checked that `pjo_plan_versions_tl.version_name LIKE '9710%'` and `pjf_projects_all_b.segment1 LIKE '9710%'` both returned 0 rows. Each variant also includes one BAD row: the CFIT022 row with project and task number `<prefix>NOPROJ`.

| Variant | Layout | Load / Import / Report request | Import report | Base table `PJO_PLAN_VERSIONS_B` |
|---|---|---|---|---|
| **A** (`97101`) | exact known-good layout (63 cols, `-1318020000`, `END`, CRLF) | 10073546 / **10073550** / 10073554 | SUCCESS 2, FAILURE 2 (identical pattern to known-good) | **3 versions created** (below) |
| **B** (`97102`) | DMT generator layout, column 29 empty | 10073632 / 10073645 / 10073649 | SUCCESS 1, FAILURE 3: `PJO_XFACE_AMT_MISSING` on all 6 PRG00008 lines (quantity not read), `PJO_XFACE_GENERIC_ERROR` "The import process couldn't be completed" on CFIT022, invalid project on the BAD row | only PRG10008 (100002666924309) |
| **C** (`97103`) | DMT generator layout **plus `-1318020000` in column 29** | 10073654 / **10073658** / 10073662 | SUCCESS 2, FAILURE 2 (identical to A) | **3 versions created**: 100002666924447 (CFIT022, B), 100002666924349 (PRG00008, W), 100002666924423 (PRG10008, W) |
| **D** (`97104`) | DMT run-238 data as generated, plus the marker | 10073682 / 10073689 / 10073693 | SUCCESS 0, FAILURE 3: `PJO_FPT_CANT_BUD_SPON_PRJ` on both RT GOOD rows, `PJO_XFACE_INVALID_PROJ_NUM` on NOPROJ999 | none. The data itself is wrong. |

**Variant A base-table evidence (import 10073550):**

| PLAN_VERSION_ID | Project | Plan type | Version name | Status | Raw cost (PC) | Revenue (PC) | PM_BUDGET_REFERENCE | Plan lines (`PJO_PLAN_LINES.PLAN_LINE_ID`) |
|---|---|---|---|---|---|---|---|---|
| 100002666923638 | CFIT022 | Cost and Revenue Budget | 97101 Version 3 | **B** (baselined), current | 70000 | 80000 | 97101_KTM_PRJBUDGET01 | 100002666923643 |
| 100002666923540 | PRG00008 | PRGUS Approved Cost Budget Non-sponsored Projects | 97101 Version 4 | W | 400000 | | 97101_KTM_PRJBUDGET01 | 100002666923549, 100002666923550 |
| 100002666923614 | PRG10008 | PRGUS Approved Cost Budget (award EUC0001) | 97101 Version 6 | W | 10000000 | | 97101_KTM_PRJBUDGET01 | 100002666923623 |

For comparison, known-good 10071416 produced 100002665926092 (CFIT022, B), 100002665925994 (PRG00008, W) and 100002665926068 (PRG10008, W). That is the same outcome. The two PRGUS versions are left Working rather than Baseline in both the known-good run and mine:
- PRG10008: `PJO_GMS_BUD_UPRLMIT_FAIL_FS`. The burdened cost of 10,000,000 exceeds the award funding of 200,000, so Fusion created a working version instead of a baseline.
- PRG00008: a budgetary-control funds check failed (`XCC_BI_BCE_FAILED`).

Of the three groups, only CFIT022 lands fully clean, so the proposed GOOD regression row mirrors it.

**BAD record. The real Fusion error is recorded in the BudgetsXfaceBIP report output.** The interface rows are purged by BudgetImportReport (`PURGE`), so the report is the system of record. In `known_good/fusion_reports/A_BudgetsXfaceBIP_10073554.xml`, LIST_G_12 echoes the rejected CSV row, with column P = `97101_BAD_NOPROJ` and column Y = the message:

> `PJO_XFACE_INVALID_PROJ_NUM`: "The project number 97101NOPROJ doesn't exist in Oracle Fusion Project Portfolio Management. Enter a valid project number."

DMT's results package already harvests this report: it keys LIST_G_12 column P to RECON_KEY.

## Code changes needed (NOT made; for the main session)

1. **`db/packages/dmt_prj_budget_fbdi_gen_pkg.pkb.sql`, `gen_budget_csv`, column 29:** replace `'""'  -- 29 REQUEST_ID (auto-populated)` with the template marker. Emit `"-1318020000"`, or `"-1318020001"` when any row in the file has ATTRIBUTE_CATEGORY or ATTRIBUTE1-30 filled in, following the macro's file-level `CountA` over sheet columns AE:BI. Correct the header comment as well: column 29 is the template-version/DFF marker, not REQUEST_ID. This is a constant format flag, not a business value. Variant B versus variant C proves this single change is decisive. Optionally rename the CSV to `PjoBudgetsXface.csv` and add the 63rd `END` column to match the template exactly; neither is required.
2. **`dmt_prj_budget_transform_pkg.TRANSFORM`:** apply the run prefix to `SRC_BUDGET_LINE_REFERENCE` (and therefore `RECON_KEY`) and to `PLAN_VERSION_NAME`, following the always-use-prefix rule. These are the only per-run unique keys when budgeting against an existing Fusion project. Today both are copied through unchanged, so `RT-PJB-RTPRJ001` / `Version 1` repeat every run. Fusion persists the source budget line reference verbatim as `PJO_PLAN_VERSIONS_B.PM_BUDGET_REFERENCE` (verified: `97101_KTM_PRJBUDGET01`).
3. **`bip/ProjectBudgets/` recon data model (`PRJ_BUDGET_DM.xdm`, mirrored in `query.sql`), BASE and INTERFACE tiers:** scope the run by `v.pm_budget_reference LIKE :P_PREFIX || '%'` (INTERFACE tier: `x.src_budget_line_reference LIKE :P_PREFIX || '%'`), either instead of or OR-ed with `p.segment1 LIKE :P_PREFIX || '%'`. Without this, a budget correctly loaded onto an existing project such as CFIT022 is never matched and ends FAILED or UNACCOUNTED. Deploy as a new BIP version per the never-overwrite rule.
4. *(Conditional, not needed for regression runs, where VALIDATE_UPSTREAM = N on runs 229/236/238)* **`dmt_prj_budget_validator_pkg.VALIDATE_PRE_TRANSFORM`:** with upstream validation on, a budget for any project that DMT did not migrate is rejected with "Project ... is not loaded". The check should apply only to rows whose project matches a DMT-migrated project.

No ESS / ParameterList change is needed.

## Proposed regression rows (for the new combined scenario; do NOT edit existing scenarios)

These rows mirror the known-good CFIT022 record, which loaded clean (status B). They assume changes 1 to 3 are in place. Table: `DMT_PRJ_BUDGET_STG_TBL`. Leave unlisted columns NULL.

| Column | GOOD | BAD |
|---|---|---|
| AWARD_NUMBER | NULL | NULL |
| FINANCIAL_PLAN_TYPE | `Cost and Revenue Budget` | `Cost and Revenue Budget` |
| PROJECT_NUMBER | `CFIT022` (existing Fusion project; no DMT xref match, so it passes through) | `NOPROJ999` |
| PROJECT_NAME | `Data Load 6` (actual name of CFIT022; post-validation requires a value) | `RT NoSuch Project` |
| TASK_NUMBER | `CFIT022` (project-level task element) | `NOPROJ999` |
| TASK_NAME | NULL | NULL |
| PLAN_VERSION_NAME | `RT Budget Version` (prefixed per run once change 2 lands) | `RT Budget Version` |
| PLAN_VERSION_STATUS | `Baseline` | `Baseline` |
| RESOURCE_NAME | `Financial Resources` | `Financial Resources` |
| LINE_TYPE | `LINE` | `LINE` |
| PERIOD_NAME | NULL | NULL |
| PLANNING_START_DATE | DATE '2026-01-01' | DATE '2026-01-01' |
| PLANNING_END_DATE | DATE '2028-01-01' | DATE '2028-01-01' |
| PLANNING_CURRENCY | `USD` | `USD` |
| TOTAL_TC_RAW_COST | 70000 | 70000 |
| TOTAL_TC_REVENUE | 80000 | 80000 |
| SRC_BUDGET_LINE_REFERENCE | `RT-PJB-GOOD1` (prefixed per run once change 2 lands) | `RT-PJB-BAD1` |
| PROCESSING_MODE | `Create` | `Create` |
| PLAN_VERSION_NUMBER | NULL | NULL |

Expected outcome: GOOD gets a new `PJO_PLAN_VERSIONS_B` row (plan status B, PM_BUDGET_REFERENCE = prefixed reference). BAD fails with `PJO_XFACE_INVALID_PROJ_NUM` "The project number NOPROJ999 doesn't exist...", harvested from BudgetsXfaceBIP LIST_G_12.

Notes:
- Each run creates one more baselined version of the Cost and Revenue Budget on CFIT022. Creating a new version is what Fusion does for a `Create` without a Plan Version Number, and the known-good run plus three standalone runs did exactly that without conflict.
- A second GOOD row mirroring PRG00008 (PERIODIC, task 2.1, Labor/Equipment quantities, periods JAN-26..MAR-26) also reaches the base table, but only as a Working version with a budgetary-control funds-check failure in the report. The report counts it as a failure, so it is not recommended as a GOOD regression row.
- Do not reuse the RT projects created in-run with project type `PRGUS Funded with Burden`. That type is sponsored, and Fusion refuses `Approved Cost Budget` for it (`PJO_FPT_CANT_BUD_SPON_PRJ`).
