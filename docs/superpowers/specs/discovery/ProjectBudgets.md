# ProjectBudgets — Three-Source Reconciliation Discovery (RUN_ID 132)

Read-only proof. RUN 132 result: **0 LOADED, 3 FAILED** — so the Fusion success side is
DESIGNED here, not confirmable in this run. No DB objects modified.

## Object / tables / grain
- **Object:** ProjectBudgets (ONE FBDI zip `PjoPlanVersionsXface.csv`, ESS job "Import Budgets Interface Data").
- **TFM table:** `DMT_PRJ_BUDGET_TFM_TBL` (has `RUN_ID`, `RECON_KEY`, `TFM_STATUS`, `FUSION_BUDGET_VERSION_ID`, `ERROR_TEXT`).
- **Fusion base table:** `PJO_PLAN_VERSIONS_B` (+ `PJO_PLAN_VERSIONS_TL` for the version name).
- **Fusion key:** `FUSION_BUDGET_VERSION_ID` = `PLAN_VERSION_ID` (one budget FBDI → one plan version).
- **Grain:** one row per budget/plan version. **Money = budget amount:** `TOTAL_TC_RAW_COST` on TFM.
- **Run prefix:** 93212. **Import ESS job id:** 10023971 (queue_id 850).

## STG total (count + money)
STG has no RUN_ID and holds duplicate seed rows; use the TFM run set as the authoritative record set.
```sql
SELECT COUNT(*) AS stg_total, SUM(total_tc_raw_cost) AS stg_money
FROM   dmt_prj_budget_tfm_tbl
WHERE  run_id = 132;
```
**Result:** stg_total = **3**, stg_money = **125,999.99** (RECON_KEYs: RT-PJB-RTPRJ001, RT-PJB-RTPRJ002, RT-PJB-BAD1).

## TFM errors (count + money + real ERROR_TEXT)
```sql
SELECT recon_key, tfm_status, total_tc_raw_cost, error_text
FROM   dmt_prj_budget_tfm_tbl
WHERE  run_id = 132 AND tfm_status = 'FAILED';
```
**Result:** 3 FAILED, money 125,999.99 (all rows).
- `RT-PJB-BAD1` → `[FUSION_ERROR] The project number NOPROJ999 doesn't exist in Oracle Fusion Project
  Portfolio Management. Enter a valid project number.` (the intended BAD row, correct reject).
- `RT-PJB-RTPRJ001` → `[FUSION_ERROR] You can't create a project budget for the project 93212RT Project
  Good-1 using the financial plan type Approved Cost Budget because it's either approved or enabled for
  budgetary control.`
- `RT-PJB-RTPRJ002` → same error for "93212RT Project Good-2".

All three carry real Fusion rejection messages. The two "GOOD" rows are functionally blocked on this pod
(see README: sponsored projects need an award, or non-sponsored need resource-level budget data).

## Fusion successes — DESIGNED query (0 LOADED, not confirmable in run 132)
No budget row reached `PJO_PLAN_VERSIONS_B` for this run, so there is nothing to confirm. The designed
positive-confirmation query, if a GOOD row ever lands:
```sql
-- via scripts/fusion_bip_query.py --cred fin_impl
SELECT v.plan_version_id AS PLAN_VERSION_ID,
       p.segment1        AS PROJECT_NUMBER,
       vtl.version_name  AS VERSION_NAME,
       v.pm_budget_reference AS PM_BUDGET_REFERENCE
FROM   pjo_plan_versions_b  v,
       pjo_plan_versions_tl vtl,
       pjf_projects_all_b   p
WHERE  vtl.plan_version_id = v.plan_version_id
AND    vtl.language        = 'US'
AND    p.project_id        = v.project_id
AND    p.segment1 LIKE '93212%'
AND    vtl.version_name <> 'Project Plan';   -- exclude the auto-created workplan (see gotcha)
```
**Live result today:** 0 BUDGET plan versions (the query returns only the two auto-created
`'Project Plan'` workplan versions, which are excluded). Confirms 0 LOADED — matches the reconciler.

## Amount column + rationale
`TOTAL_TC_RAW_COST` (transaction-currency raw cost) is the budget amount at the plan-version grain
carried on TFM. Used for STG and TFM-error money. On the base row the reconcilable amount would be the
plan line detail total, but budget lines land in `PJO_PLAN_LINE_DETAILS` which carries no native source
reference, so the reconcilable grain is the plan version (COUNT + submitted money only).

## Balance check
Fusion successes (0, designed) + TFM errors (3, $125,999.99) = 3 rows / $125,999.99 = STG/run total.
**BALANCED on count and money** — every record accounted (all 3 FAILED with real errors). 0 LOADED in
this run, so the success side is designed only.

## Gotchas
- **False-positive trap (found live):** `PJO_PLAN_VERSIONS_B` for prefix 93212 already holds TWO plan
  versions (PLAN_VERSION_ID 100002649024281, 100002649024311) named **"Project Plan"** with a NULL
  `PM_BUDGET_REFERENCE`, created 2026-09-25 17:55 by FIN_IMPL. These are the auto-created project
  workplan/forecast versions Fusion makes when the PROJECT is created (by the Projects import), NOT the
  Approved Cost Budget the ProjectBudgets FBDI tried to load. A naive prefix-only base join would
  false-positive count them as loaded budgets. Filter out `version_name = 'Project Plan'` (or filter to
  the budget plan type / require a non-null `PM_BUDGET_REFERENCE`) — the DMT .xdm keys on
  `PM_BUDGET_REFERENCE` which is NULL on these workplan rows, so the shipped reconciler avoided the trap.
- Interface table `PJO_PLAN_VERSIONS_XFACE` has no error-text column and there is no queryable
  PJO*ERR* table on this pod; the real per-row message comes from the Import Budgets report XML,
  harvested to TFM.ERROR_TEXT.
- STG has no RUN_ID and holds duplicate seed rows — use the TFM run set.
