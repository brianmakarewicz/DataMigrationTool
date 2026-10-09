# Project Budgets

## Status
**WORKING (2026-10-07). GOOD row LOADED in `PJO_PLAN_VERSIONS_B`, BAD row FAILED with the real
Fusion error, 0 UNACCOUNTED.** Proof: local run 244 (prefix 93300), scenario
`RegressionTest2610071114`:

| Row | Outcome | Fusion evidence |
|---|---|---|
| GOOD `93300RT-PJB-GOOD1` (CFIT022, Cost and Revenue Budget, LINE, Baseline) | LOADED | `PJO_PLAN_VERSIONS_B.PLAN_VERSION_ID` 100002666840879, plan status B (baselined, current), `PM_BUDGET_REFERENCE` = `93300RT-PJB-GOOD1` |
| BAD `93300RT-PJB-BAD1` (project NOPROJ999) | FAILED | `[FUSION_ERROR] The project number NOPROJ999 doesn't exist in Oracle Fusion Project Portfolio Management. Enter a valid project number.` (from the BudgetsXfaceBIP import report, LIST_G_12) |

What fixed it (owner-approved, from `docs/findings/known_good_ProjectBudgets.md`):
1. **FBDI column 29 is the template marker**, not REQUEST_ID: `-1318020000`, or `-1318020001`
   when any row in the file carries a flexfield attribute (the template's GenCSV macro does
   exactly this). Without it Fusion drops quantities and fails LINE budgets.
2. **The run prefix goes on `SRC_BUDGET_LINE_REFERENCE` (so `RECON_KEY` and Fusion
   `PM_BUDGET_REFERENCE`) and `PLAN_VERSION_NAME`.** A value that cannot carry the prefix within
   its limit (100 / 240) fails the row with `[TRANSFORM_ERROR]`; it is never truncated.
3. **Recon data model V2** (`DMT_PRJ_BUDGET_RECON_V2_DM` / `_RPT`, deployed alongside the original
   `PRJ_BUDGET_DM`) scopes the run by `PM_BUDGET_REFERENCE LIKE prefix` OR the prefixed project
   number, so a budget on an EXISTING project reconciles. Interface rows are purged by Fusion
   (BudgetImportReport runs with PURGE), so the real per-row error comes from the BudgetsXfaceBIP
   report; the DM returns the Contract v1 `#IMPORT_REPORT#` marker on INTERFACE/ERROR rows.
4. **Regression rows** mirror the owner's known-good CFIT022 record (BAD = NOPROJ999). The old
   `Approved Cost Budget` rows on the in-run sponsored RT projects could never load
   (`PJO_FPT_CANT_BUD_SPON_PRJ`); earlier write-once scenarios keep them untouched.

**Base table / match key (record-accounting rule):** base table `PJO_PLAN_VERSIONS_B` (interface
`PJO_PLAN_VERSIONS_XFACE` is distinct and purged). Match key: `RECON_KEY` =
prefixed `SRC_BUDGET_LINE_REFERENCE` = `PJO_PLAN_VERSIONS_B.PM_BUDGET_REFERENCE`; the Fusion id
stored is `PLAN_VERSION_ID` in `FUSION_BUDGET_VERSION_ID`.

Each regression run creates one more baselined version of the Cost and Revenue Budget on
CFIT022 (Fusion's behavior for `Create` without a plan version number).

### History of the earlier "blocked" status
The earlier "E2E LOADED 3/3 on 2026-04-01 (prefix 9123)" claim was a reconciliation false
positive. The rows then targeted `Approved Cost Budget` on sponsored projects, which Fusion
refuses (`PJO_FPT_CANT_BUD_SPON_PRJ`), and the generator left the template marker empty. Both
are fixed above; the known-good comparison proved neither the ESS parameters nor budgetary
control was the cause.

## Reconciliation by Fusion job id, one call per work item (2026-10-07)

Owner decision: the reconciliation report finds rows only by the Fusion job ids, never by
searching on the run prefix or the project number. The prefixed source budget line reference
(persisted as PM_BUDGET_REFERENCE) is used only to match a row Fusion returned back to its TFM
row.

- **Report V3** `DMT_PRJ_BUDGET_RECON_V3_DM` / `_RPT` (deployed alongside V1 and V2, which are
  never overwritten): plan versions by `PJO_PLAN_VERSIONS_B.REQUEST_ID = :P_IMPORT_ESS_ID`;
  interface rejections by `PJO_PLAN_VERSIONS_XFACE.LOAD_REQUEST_ID = :P_LOAD_REQUEST_ID`. No
  `LIKE` anywhere. Keyset ordering and comparison pinned to BINARY. Registry repointed by the
  seed and `db/migrations/2026-10-07_project_budgets_recon_v3_registry.sql`.
- **One call per work item.** One load and one Import Budgets job per work item, so
  `RECONCILE_BATCH` passes that item's own load id and import id to `FETCH_ROWS`.
- Verified read-only first: `PJO_PLAN_VERSIONS_B.REQUEST_ID` carries the Import Budgets job id
  (runs 241 and 244 recorded 10073776 and 10073840, the values Fusion stamped). The interface
  is purged after import on this pod (no rows since 2025-11-14), so the interface tier
  normally returns nothing; the real per-row message still comes from the BudgetsXfaceBIP
  report output.

Proof run 275 (prefix 93331, scenario RegressionTest2610071920, STANDALONE:ProjectBudgets):
work item 1642 recorded load 10075774 / import 10075778 (ImportBudgetsInterfaceData; its
BudgetsXfaceBIP report job is 10075782). Plan version 100002667587274 (93331RT-PJB-GOOD1 on
CFIT022) carries REQUEST_ID 10075778. RT-PJB-GOOD1 LOADED; RT-PJB-BAD1 FAILED with its own
Fusion error ("The project number NOPROJ999 doesn't exist ..."); 0 UNACCOUNTED. Dollars tie
out: 70,000 loaded = 70,000 TC raw cost on the Fusion plan lines; 70,000 failed. A
reconcile-only rerun left both TFM rows byte-identical. `dmt_regression_run.py` PASS with one
review item that is not about reconciliation (no REST lookup is configured for Project Budget
Lines); Playwright click-through PASS. (Run 267 showed the same outcomes before this branch was
rebased onto main.)

## Whole plan version rejection (2026-10-08, backlog #172 / #197)

The Fusion document is the plan version (project + financial plan type + plan version name /
number). `DMT_PRJ_BUDGET_RESULTS_PKG.PROPAGATE_DOCUMENT_ERRORS` runs after the Contract v1 apply
and the BudgetsXfaceBIP harvest and before the shared unaccounted sweep. For every line FAILED with
its own `[FUSION_ERROR]`, it appends
`[FUSION_ERROR] Rejected with document: line <reference>: <real message>` to every other line of the
same plan version that Fusion received and that is not LOADED, and sets it FAILED. It never touches
LOADED rows and a second pass adds nothing.

Live proof, run 314 (prefix 93369, scenario `RegressionTest2610081757`, PROJECTS): plan version
`RT XG Budget Version` on CFIT022 with lines RT-PJB-XG-A (valid) and RT-PJB-XG-B (resource that does
not exist). Fusion rejected the whole version and named **both** lines in LIST_G_12 with
"A different source plan line reference is being used on another line in this plan version.", so
each line is FAILED with its own real error plus the quote of its sibling. GOOD1 LOADED, BAD1 FAILED,
0 UNACCOUNTED, `dmt_regression_run.py` PASS.

What the run showed: **the source budget line reference is a plan-version attribute in Fusion**
(it becomes `PJO_PLAN_VERSIONS_B.PM_BUDGET_REFERENCE`), so every line of one version must carry the
same reference. A multi-line version therefore cannot have a distinct `RECON_KEY` per line, and a
version whose lines share a reference is matched as a whole by the harvest. The silent-sibling case
backlog #172 describes cannot arise with today's keying; the propagation is defensive. Line identity
inside a multi-line version is backlog #546.

## Line identity inside one plan version (backlog #546, 2026-10-09)

Fusion's BudgetsXfaceBIP report does tell the lines of one version apart. Every `G_12` row echoes
the line Fusion read from the CSV: `E` = task number, `J` = resource name, `K` = period name,
`AB`/`AC` = planning start/end date (YYYY/MM/DD), `P` = the shared source reference, `Y` = the
message (empty on a line Fusion did not blame). The harvest now matches a `G_12` row to the TFM
line with the same `RECON_KEY` **and** the same task, resource, period and start date (a column the
report leaves empty is not compared), and the propagation quote names the line by them:
`Rejected with document: line <reference> (task <task>, resource <resource>[, period <period>])`.

Live proof, scenario RegressionTest261009013036 (minted with `--keep-pointer`): plan version
`RT ML Budget Version` on CFIT022 with two lines sharing the reference `RT-PJB-ML`, ML-A valid,
ML-B resource `RT No Such Resource`. Run 343 (report 10084503) and run 345 (prefix 93395): Fusion
rejected the whole version (FAILURE_COUNT counts it), listed both lines in `G_12`, and gave the
message only on ML-B ("The resource name RT No Such Resource doesn't exist in the planning resource
breakdown structure PRGUS RBS - Lower Resource Level."). ML-B is FAILED with that error as its own;
ML-A is FAILED with the quote. GOOD1 LOADED, 0 UNACCOUNTED, `dmt_regression_run.py` PASS.

A LOADED version still marks all its lines LOADED with the version's `PLAN_VERSION_ID`: Fusion
accepts or rejects the version as a whole, so the version id is the line's proof.

## Pipeline
- Module: Projects
- FBDI Template: PjoBudgetInterface.xlsm
- Interface Table: PJO_PLAN_VERSIONS_XFACE (template-level name PJO_BUDGET_INTERFACE)
- Base Table: PJO_PLAN_VERSIONS_B
- UCM Account: prj/projectControl/import
- ESS Job: ImportBudgetsInterfaceData
- ParameterList: `#NULL` (no business value is an ESS parameter; verified against owner run 10071416)
- Loader Type: SQLLOADER
- Auth User: fin_impl

## Code References
- STG Table DDL: `schema/tables/160_dmt_prj_budget_stg_tbl.sql`
- TFM Table DDL: `schema/tables/161_dmt_prj_budget_tfm_tbl.sql`
- Validator: `packages/validators/dmt_prj_budget_validator_pkg.*`
- Transformer: `packages/transformers/dmt_prj_budget_transform_pkg.*`
- FBDI Generator: `packages/generators/fbdi/projects/dmt_prj_budget_fbdi_gen_pkg.*`
- Results/Reconciliation: `packages/reconciliation/dmt_prj_budget_results_pkg.*`
- BIP Data Model/Report: `bip/ProjectBudgets/`

## Reference Files
- `../../scripts/query_project_budget_ref.py` -- BIP SOAP query script used to discover these values

## Valid Reference Data

Queried from Fusion demo instance (`fa-esew-dev28-saasfademo1`) on 2026-04-01.
**Primary method: Fusion REST API** (`/fscmRestApi/resources/11.13.18.05/projectBudgets`).
BIP SOAP was also attempted but BI SQL requires SSO auth (returns login redirect with basic auth).

### Query Method (for future sessions)

**Best method: Fusion REST API** with `fin_impl` / basic auth:
- `GET /fscmRestApi/resources/11.13.18.05/projectBudgets?limit=100&fields=FinancialPlanType,PlanVersionName,PlanVersionStatus,ProjectNumber,ProjectName`
- `GET /fscmRestApi/resources/11.13.18.05/projectBudgets/{id}/lov/FinancialPlanTypesLOVVO?limit=50`
- `GET /fscmRestApi/resources/11.13.18.05/projects?limit=25&q=ProjectStatusCode=APPROVED&fields=ProjectName,ProjectNumber,LegalEntityName`

BIP v2 SOAP also works for ad-hoc SQL but requires a pre-deployed data model.
The `analyticsRes/v1/sql` BI SQL endpoint requires SSO and does not work with basic auth.

Note: The `GET_SESSION_TOKEN` function had a whitespace bug in its SOAP envelope
(trailing spaces inside `<v2:userID>` and `<v2:password>` tags). This was fixed in
`dmt_bip_deploy_pkg.pkb` and deployed to ATP on 2026-04-01.

### FINANCIAL_PLAN_TYPE (from FinancialPlanTypesLOVVO -- 32 total)

Use exact name as shown. All are `BUDGET` class (`PlanClassCode=BUDGET`) unless noted.

**Seeded types (recommended for testing -- work across all BUs):**
- `Approved Cost Budget` -- cost only, multi-currency, no BC
- `Cost Only Budget` -- cost only, single currency, no BC
- `Cost and Revenue Budget` -- cost + revenue together, single currency, no BC
- `Cost Plus Burden Budget` -- cost + burden, single currency, no BC
- `Cost Only Budget with Budgetary Control` -- cost only, single currency, BC enabled

**Common custom types (also valid):**
- `Approved Cost and Revenue in same plan version` -- multi-currency, no BC
- `Approved Cost and Revenue in separate plan version` -- multi-currency, no BC
- `Approved Cost and Revenue in same plan version with workflow enabled`
- `Approved Cost and Revenue in same plan version - Role based`
- `Estimate` -- unapproved budget (cost + rev together, no BC)
- `Detailed Budget` -- EPM integration, workflow enabled
- `Strategic Budget` -- EPM integration, no workflow

**BU-specific types (only work for projects in that BU):**
- `PRGUS Approved Cost Budget` (BC enabled)
- `PRGUS Approved Cost Budget Non-sponsored Projects` (BC enabled)
- `PRGUS Approved Cost Budget w/o BC`
- `PRGUS Approved Cost&Rev budget in same version` (BC enabled)
- `HCUS approved cost budget` (BC enabled)
- `HCUS Approved Cost&Rev budget in same version`
- `HCUS Approved Cost Budget Non-sponsored Projects` (BC enabled)
- `HCUS approved cost budget - Workflow enabled`
- `HCUS Approved Cost&Rev budget in same version - Workflow enabled`
- `UNIVUS Approved Cost Budget` (BC enabled)
- `UNIVUS Approved Cost Budget Non-sponsored Projects` (BC enabled)
- `AUCOUNCIL Approved Cost Budget` (BC enabled)
- `AUCOUNCIL Approved Cost Budget Non-sponsored Projects` (BC enabled)
- `AUCOUNCIL Approved Cost Budget w/o BC`
- `AUCOUNCIL Approved Cost&Rev budget in same version` (BC enabled)
- `PRGUK Approved Cost Budget` (BC enabled)
- `PRGUK Approved Cost Budget Non-sponsored Projects` (BC enabled)
- `PRGUK Approved Cost Budget w/o BC`
- `PRGUK Approved Cost&Rev budget in same version` (BC enabled)
- `E&C Approved Cost and Revenue in same plan version`

### PERIOD_NAME

The FBDI template uses project accounting period names. Format observed from
existing PlanningOptions data: `MM-YY` (e.g. `06-13` = June 2013).
CurrentPlanningPeriod from a sample budget: `06-13`.

The previous session's BIP query returned `MM-YY` format (e.g. `01-24`, `02-25`).
The test data used `Jan-26` / `Feb-26` which is `Mon-YY` format -- this is WRONG.

**Use `MM-YY` format: `01-25`, `02-25`, `03-25`, etc.**

Open periods (confirmed from previous BIP query):
- 2024: `01-24` through `12-24` (plus adjustment `13_12-24`)
- 2025: `01-25` through `12-25`
- 2026 periods do not exist on this instance.

### PLAN_VERSION_NAME

Free-text field. Existing budgets in Fusion use:
- `Version 1`, `Version 2`, `Version 3`, `Version 4`

The FBDI import creates a new version with whatever name is supplied.
For testing, `Original Budget` or `Version 1` are fine -- just ensure the name
does not already exist for the given project + plan type combination.

**Plan version STATUS values (from existing Fusion budgets):**
- `Current Working`
- `Working`
- `Current Baseline`
- `Baseline`
- `Original Baseline`
- `Current and Original Baseline`

### PROJECT_NUMBER / PROJECT_NAME (from Fusion REST API)

**APPROVED projects with Legal Entity (use these for test data):**

| Project Number | Project Name | Legal Entity |
|---|---|---|
| 00009805 | Cyber Security Project | Progress US Legal Entity |
| 00009931 | Fire Management Assistance | Progress US Legal Entity |
| 00009948 | Advanced Exploratory Research - II | (not returned) |
| CAP10001 | Annex Building | Progress US Legal Entity |
| EDU50001 | Hidden Valley Elementary School | Progress US Legal Entity |
| EDU50002 | Allenbrook Elementary School | Progress US Legal Entity |
| HC1005 | Clinical Vaccine Trials - Phase I | Healthcare US Legal Entity |
| HC1008 | Executive Department Extention | Healthcare US Legal Entity |
| HC1010 | Skin Cancer Research Study | Healthcare US Legal Entity |
| HC1011 | Allied Hospital Renovation | Healthcare US Legal Entity |
| HC1012 | Fairview Clinic Renovation - II | Healthcare US Legal Entity |
| HC2001 | Asthma and Allergy Research | Healthcare US Legal Entity |
| LS10001 | Clinical Development Dosing Trial | US1 Legal Entity |
| PCS10080 | Business World Database Migration | US1 Legal Entity |
| PI20065 | Oil and Gas Pipeline Project | US1 Legal Entity |
| PRG00006 | Green Energy Engineering | Progress US Legal Entity |
| PRG10001 | Job Opportunities for Low Income Individuals (JOLI) | Progress US Legal Entity |
| PRG10002 | Low Income Home Energy Assistance Program (LIHEAP) | Progress US Legal Entity |
| PRG10008 | 5G Extension | (not returned) |

**Projects with existing budgets in Fusion (confirmed via projectBudgets REST):**

| Project Number | Project Name | FinancialPlanType | PlanVersionName |
|---|---|---|---|
| PCS10001 | Hilman HCM Implementation | Approved Cost and Revenue in same plan version | Version 2 |
| PCS10002 | McNally Business Process Reengineering | Approved Cost and Revenue in same plan version | Version 3 |
| PCS10020 | Stark Technology Upgrade | Approved Cost and Revenue in same plan version | Version 2 |
| PCS10008 | Business World Data Warehouse | Approved Cost and Revenue in same plan version | Version 2/3 |
| PCS10022 | Business World Middleware Upgrade | Approved Cost and Revenue in same plan version | Version 2/3 |
| TIS10001 | US Internal Billable Capital no Burden | Approved Cost and Revenue in separate plan version | Version 1 |

### ATP Pipeline Data (DMT_PRJ_BUDGET_STG_TBL / TFM_TBL)

**The 2026-04-01 rows below were NOT loaded** — they were reported LOADED by the old
"absence = LOADED" recon but never reached `PJO_PLAN_VERSIONS_B` (a reconciliation false positive):

| STG_SEQUENCE_ID | PROJECT_NUMBER | PROJECT_NAME | FINANCIAL_PLAN_TYPE | PERIOD_NAME | PLAN_VERSION_NAME | TOTAL_TC_RAW_COST | REAL OUTCOME |
|---|---|---|---|---|---|---|---|
| 100000007 | HC2001 | Asthma and Allergy Research | Approved Cost Budget | 01-25 | Version 1 | 50000 | never loaded (false positive) |
| 100000008 | PRG10001 | Job Opportunities for Low Income Individuals (JOLI) | Approved Cost Budget | 02-25 | Version 1 | 75000 | never loaded (false positive) |
| 100000009 | EDU50001 | Hidden Valley Elementary School | Approved Cost Budget | 03-25 | Version 1 | 100000 | never loaded (false positive) |

The recon then reported "3 LOADED, 0 FAILED", but that verdict came from the interface table
showing no error, not from a confirmed base-table row.

**Live proof of the current honest accounting (run 121):** the import job
`ImportBudgetsInterfaceData` (request 10015078) spawned the report job `BudgetsXfaceBIP`
(request 10015083), which reported `SUCCESS_COUNT=0, FAILURE_COUNT=3`. After the #79 fix all three
TFM rows end FAILED carrying the real Fusion message:
- `RT-PJB-BAD1` → "The project number NOPROJ999 doesn't exist in Oracle Fusion Project Portfolio Management. Enter a valid project number." (`PJO_XFACE_INVALID_PROJ_NUM`)
- `RT-PJB-RTPRJ001` / `RT-PJB-RTPRJ002` → "You can't create a project budget for the project ... using the financial plan type Approved Cost Budget because it's either approved or enabled for budgetary control."

0 rows remain UNACCOUNTED.

### Test Data Fix Summary (resolved)

Previous test data failed because:
1. `FINANCIAL_PLAN_TYPE = 'Budget'` -- invalid. Fixed to `'Approved Cost Budget'` (exact name from LOV).
2. `PERIOD_NAME = 'Jan-26'` / `'Feb-26'` -- wrong format and nonexistent year. Fixed to `'01-25'` / `'02-25'` / `'03-25'` (MM-YY format, 2025 periods).
3. `PROJECT_NUMBER = '9108RTPRJ001'` -- did not exist in Fusion. Fixed to real APPROVED projects: HC2001, PRG10001, EDU50001.
4. `PROJECT_NAME = 'RT Project Good-1'` -- did not exist. Fixed to matching names from Fusion REST API.

## Known Issues
Live accepted-standard (DMT_DESIGN section 7) violations still present in this object's code,
all pre-existing and not introduced by the 2026-10-07 fix:
- Procedures-only rule: `DMT_PRJ_BUDGET_FBDI_GEN_PKG.gen_budget_csv` (reads a table) and
  `DMT_PRJ_BUDGET_RESULTS_PKG.resolve_report_ess_id` (calls the ESS capture) are private
  functions, not on the permitted-function list.
- Error-code contract: the four packages signal failure by RAISE, not an `x_error_code` OUT
  parameter (codebase-wide retrofit, section 12).
- One BEGIN/END per procedure: `apply_import_report` keeps nested BEGIN/EXCEPTION blocks that log
  a WARN and leave rows for the unaccounted sweep; the transform's WHEN OTHERS handler uses the
  shared backlog #14 nested block that `check_transform_error.py` requires.
- Transform-stage errlog (`LOG ERRORS INTO DMT_TFM_ERRLOG`, PROPOSED) not adopted; the transform
  uses the backlog #14 inline handler.
- Recon report returns nine columns (adds SOURCE_REF / DMT_REFERENCE beyond the seven), which the
  shared `DMT_RECON_CONTRACT_PKG.FETCH_ROWS` reads as its tier-3 business key.
- Run scoping in the recon DM uses the run prefix as a search value (`LIKE :P_PREFIX || '%'`),
  which the Contract v1 P_PREFIX parameter allows but the "prefix is never a search value" rule
  discourages; it was owner-approved for this fix because no request id or work-queue id survives
  onto `PJO_PLAN_VERSIONS_B` for a non-partitioned object.

Other notes:
- BI SQL endpoint (`analyticsRes/v1/sql`) requires SSO auth -- returns login redirect with basic auth. Not usable from scripts.
- GL period names not directly queryable via REST. Period format confirmed as `MM-YY` from PlanningOptions and previous BIP queries.
- No projects currently at STATUS=LOADED in ATP, so ProjectBudgets validation upstream project check is bypassed (only enforced when at least one project is LOADED).
- The `projectBudgets` REST endpoint returns existing budgets (100+ rows, hasMore=true). The `FinancialPlanTypesLOVVO` child LOV returns all 32 configured plan types.
- UPDATE_MASTER_TOTALS logs two WARN entries for DMT_GL_BUDGET_INT_TFM_TBL and DMT_GL_INTERFACE_TFM_TBL (missing STATUS column) -- non-blocking, does not affect ProjectBudgets results.

## History
- FAILED at Fusion import due to invalid reference data in test rows.
- 2026-04-01 (session 1): Queried Fusion demo instance for valid reference data via BIP SOAP. Found valid projects, plan types, and period names. Fixed whitespace bug in DMT_BIP_DEPLOY_PKG.GET_SESSION_TOKEN.
- 2026-04-01 (session 2): Re-queried via Fusion REST API (`projectBudgets`, `projects`, `FinancialPlanTypesLOVVO`). Confirmed 32 financial plan types, 25+ APPROVED projects with legal entities, and existing budget version patterns. Updated reference data with comprehensive findings.
- 2026-04-01 (session 3): Fixed test data with valid Fusion values. Deleted 6 old invalid rows, inserted 3 new rows (HC2001, PRG10001, EDU50001) with correct FINANCIAL_PLAN_TYPE='Approved Cost Budget', PERIOD_NAME in MM-YY format, PLANNING_CURRENCY='USD'. Ran RUN_PROJECT_BUDGETS (integration_id=100000027, prefix=9123). Full E2E pipeline succeeded: validate (0 pre-validation failures) -> transform (3 rows) -> SUBMIT_LOAD (loadAndImportData to prj/projectControl/import, Load ESS 9391781 SUCCEEDED in 60s) -> GET_IMPORT_ESS_ID (found 9391787) -> Import ESS poll (SUCCEEDED) -> BIP reconciliation (3 LOADED, 0 FAILED). All 3 rows at STATUS=LOADED in both STG and TFM.
- 2026-04-02: BIP audit — switched to two-tier reconciliation.
  - Tier 1: PJO_PLAN_VERSIONS_XFACE (interface table errors/status)
  - Tier 2: PJO_PLAN_VERSIONS_B (base table, positive confirmation)
  - Added P_IMPORT_ESS_ID parameter to BIP data model
  - Eliminated absence=LOADED fallback. Unmatched GENERATED rows now FAILED with RECONCILE_ERROR.
- 2026-09-24 (#79): confirmed the 2026-04-01 "3/3 LOADED" was a false positive (nothing in
  PJO_PLAN_VERSIONS_B). Added the import-report harvest: RECONCILE_BATCH now reads the
  BudgetsXfaceBIP report (child of ImportBudgetsInterfaceData) and marks each row Fusion
  rejects FAILED with its real message. Seeded REPORT_JOB_DEF='BudgetsXfaceBIP' so the shared
  CAPTURE_REPORT_ESS_JOB can resolve the report. This was the ONLY results package that did not
  read its import report; all siblings already did. Replayed against run 121: three UNACCOUNTED
  rows flipped to FAILED with real errors, 0 UNACCOUNTED. GOOD load is functionally blocked
  (award provisioning or resource-level budget data — functional owner).
- 2026-10-07 (known-good fix): column-29 template marker, run prefix on the budget reference
  and plan version name, recon DM V2 scoped by `PM_BUDGET_REFERENCE`, legacy `P_BATCH_ID` recon
  path removed, regression rows mirror the known-good CFIT022 record. Local run 244 (prefix
  93300): GOOD LOADED (plan version 100002666840879, status B), BAD FAILED with
  `PJO_XFACE_INVALID_PROJ_NUM`, 0 UNACCOUNTED.

## Lessons Learned
- **Never assume absence=LOADED without positive verification.** Two-tier BIP pattern queries both interface AND base tables. If neither has the row, it's FAILED, not silently LOADED.

## Table-name vs FBDI-tab audit (backlog #90, 2026-10-01)

Backlog #90 asks whether every STG/TFM table name mirrors the FBDI CSV tab
(record type) it loads. The object-model rule is "one object = one FBDI zip = one
tab per record type". Project Budgets is ONE zip with a single CSV / one interface
table; DMT models it with one STG + one TFM table.

**The mapping (from the generator `DMT_PRJ_BUDGET_FBDI_GEN_PKG` `REGISTER_CSV`
call and the `FROM` table):**

| FBDI tab / CSV | Interface table | Source STG table | Source TFM table | Verdict |
|---|---|---|---|---|
| PjoPlanVersionsXface.csv | PJO_PLAN_VERSIONS_XFACE | DMT_PRJ_BUDGET_STG_TBL | DMT_PRJ_BUDGET_TFM_TBL | NAME-SHORTENED (PRJ_BUDGET for Project Budget / PjoPlanVersions), model correct |

**Why it reads NAME-SHORTENED but the model is correct:** the single Fusion tab
`PjoPlanVersions` carries project *plan versions* = the budget plan. DMT names the
table `PRJ_BUDGET` (a shortening of "Project Budget", the object name and FBDI
template `PjoBudgetInterface.xlsm`). Same record type; the DMT name follows the
budget concept rather than the Oracle plan-version staging label. One tab, one
table -- no fan-out.

**Findings (what was fixed vs deferred):**
1. **NO spec-header fix needed.** The generator spec-header already names the real
   CSV tab `PjoPlanVersionsXface.csv`, matching the `REGISTER_CSV` call. Accurate.
2. **DEFERRED (physical rename, high ripple -- DO NOT do under this item):** renaming
   `DMT_PRJ_BUDGET_*` to `*_PJO_PLAN_VERSIONS_*` would ripple across the validator,
   transformer, generator, results package, catalog, pipeline and BIP for no
   correctness gain -- the name is a sensible shortening, not a wrong record type.
   Recorded as a finding only.
3. **No NOT-MODELED gaps.** The one CSV in the zip has a STG and a TFM table and a
   generator branch.

**Registry note (not a misalignment):** the Pipeline section's "Interface Table:
PJO_BUDGET_INTERFACE" is the FBDI *template*-level name; the actual load/interface
table the CSV lands in is `PJO_PLAN_VERSIONS_XFACE` (see the detailed recon notes
below). The table above uses the real interface-table name.

## Reconciliation report pages by header (2026-10-09, backlog #691)

The registered report is now `bip/ProjectBudgets/DMT_PRJ_BUDGET_RECON_V4_DM.xdm`, deployed alongside `DMT_PRJ_BUDGET_RECON_V3_DM` (never overwritten).
It pages on header boundaries (owner decision 2026-10-09, design section 5, "Reconciliation
fetches page on header boundaries"): a page is the next BIP_CHUNK_SIZE headers, keyed by project plus plan version,
plus every base and interface row that belongs to them, and each row carries that header key in
the tenth column `PAGE_KEY`. `DMT_RECON_CONTRACT_PKG.FETCH_ROWS` counts headers, sends the last
header key back as `P_AFTER_KEY`, has no page cap, and fails the fetch with an error if a page
does not advance. Row selection (job ids only), RECORD_KEYs, FUSION_IDs and error text are the
same as in `DMT_PRJ_BUDGET_RECON_V3_DM`.
