# Project Budgets

## Status
**E2E LOADED** -- 3/3 rows loaded to Fusion on 2026-04-01 (integration_id=100000027, prefix=9123)

## Pipeline
- Module: Projects
- FBDI Template: PjoBudgetInterface.xlsm
- Interface Table: PJO_BUDGET_INTERFACE
- UCM Account: prj/projectControl/import
- ESS Job: ImportBudgetsInterfaceData
- ParameterList: UNKNOWN -- needs discovery
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

**Current test data (LOADED 2026-04-01, integration_id=100000027, prefix=9123):**

| STG_SEQUENCE_ID | PROJECT_NUMBER | PROJECT_NAME | FINANCIAL_PLAN_TYPE | PERIOD_NAME | PLAN_VERSION_NAME | TOTAL_TC_RAW_COST | STATUS |
|---|---|---|---|---|---|---|---|
| 100000007 | HC2001 | Asthma and Allergy Research | Approved Cost Budget | 01-25 | Version 1 | 50000 | LOADED |
| 100000008 | PRG10001 | Job Opportunities for Low Income Individuals (JOLI) | Approved Cost Budget | 02-25 | Version 1 | 75000 | LOADED |
| 100000009 | EDU50001 | Hidden Valley Elementary School | Approved Cost Budget | 03-25 | Version 1 | 100000 | LOADED |

ESS Load job: 9391781 (SUCCEEDED). Import job: 9391787 (SUCCEEDED). BIP reconciliation: 3 LOADED, 0 FAILED.

### Test Data Fix Summary (resolved)

Previous test data failed because:
1. `FINANCIAL_PLAN_TYPE = 'Budget'` -- invalid. Fixed to `'Approved Cost Budget'` (exact name from LOV).
2. `PERIOD_NAME = 'Jan-26'` / `'Feb-26'` -- wrong format and nonexistent year. Fixed to `'01-25'` / `'02-25'` / `'03-25'` (MM-YY format, 2025 periods).
3. `PROJECT_NUMBER = '9108RTPRJ001'` -- did not exist in Fusion. Fixed to real APPROVED projects: HC2001, PRG10001, EDU50001.
4. `PROJECT_NAME = 'RT Project Good-1'` -- did not exist. Fixed to matching names from Fusion REST API.

## Known Issues
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

## Lessons Learned
- **Never assume absence=LOADED without positive verification.** Two-tier BIP pattern queries both interface AND base tables. If neither has the row, it's FAILED, not silently LOADED.
