# PerformanceEvaluations — gold regression fixture (HDL, GoalPlan)

A standalone, reloadable **HDL** fixture (2 good rows + 1 bad row) that creates
new performance **goal plans** through the HCM Data Loader REST service (upload →
createFileDataSet → poll), verified read-only via BIP against the base table
`HRG_GOAL_PLANS_B`. No DMT tool code and no DMT database are in the load path.

## What "PerformanceEvaluations" means for a portable gold fixture

The loadable, data-carrying top-level record in the performance-goals area is the
**GoalPlan** — the HDL business object whose file name must be `GoalPlan.dat`
(the object matrix's old `PerformanceDocument.dat` is rejected by Fusion). Loading
a `GoalPlan` MERGE line creates a brand-new goal plan header row in
`HRG_GOAL_PLANS_B` (name in `HRG_GOAL_PLANS_TL`).

Each good row creates a NEW goal plan, stamped with a fresh `${PREFIX}` so re-runs
never collide, and references two things that already ship on any pod:

- an **existing review period** (by `ReviewPeriodName`), and
- an **existing person** as the request submitter (by `ReqSubmittedByPersonNumber`).

Nothing is created upstream. There is **no dependency on our earlier Workers,
Salaries, or PayrollRelationships loads** — the review period and the submitter
person both already exist on the demo pod and are discovered at load time.

> Note on the DMT generator: `dmt_perf_eval_hdl_gen_pkg` emits
> `ReqSubmittedByPersonId(SourceSystemId)` using the Worker's own source-system id,
> which only resolves if that worker was HDL-loaded in the same run — an upstream
> dependency. This gold fixture deliberately uses `ReqSubmittedByPersonNumber` (the
> existing-record user key) instead, so it is portable and self-sufficient.

## Why this fixture is portable (no upstream dependency)

At load time it runs one read-only BIP query against the target pod and discovers,
in a single row:

- an **active review period** whose date range spans today
  (e.g. `2026 Annual Cycle`, 2026/01/01–2026/12/31; the fixed
  `Default Review Period …` is excluded so we bind a normal annual cycle), and
- an **existing active person number** to be the request submitter
  (lowest `person_id`, numeric person number — an established seeded employee), and
- **today's date** (`RUN_DATE`) for `RequestSubmissionDate`.

The goal plan's `StartDate`/`EndDate` are set to the discovered review period's own
start/end so the plan always sits inside a valid, open review period on any pod.

## The DAT (`GoalPlan.dat`, pipe-delimited HDL, V1 discriminator `GoalPlan`)

One `GoalPlan.dat` inside `PerformanceEvaluations_gold.zip`. One `GoalPlan` section,
three MERGE lines:

```
METADATA|GoalPlan|GoalPlanExternalId|GoalPlanName|GoalPlanTypeCode|GoalPlanActiveFlag|EnableWeightingFlag|StartDate|EndDate|EnforceGoalWeightFlag|GoalAccessLevelCode|IncludeInPerfdocFlag|ReqSubmittedByPersonNumber|RequestSubmissionDate|ReviewPeriodName
MERGE|GoalPlan|GP_${PREFIX}_1|${PREFIX} DMT Goal Plan A|ORA_HRG_WORKER|A|Y|${RP_START}|${RP_END}|N|ALL|N|${SUBMITTER_PN}|${RUN_DATE}|${REVIEW_PERIOD}
MERGE|GoalPlan|GP_${PREFIX}_2|${PREFIX} DMT Goal Plan B|ORA_HRG_WORKER|A|Y|${RP_START}|${RP_END}|N|ALL|N|${SUBMITTER_PN}|${RUN_DATE}|${REVIEW_PERIOD}
MERGE|GoalPlan|GP_${PREFIX}_3|${PREFIX} DMT Goal Plan BAD|DMT_INVALID_TYPE|A|Y|${RP_START}|${RP_END}|N|ALL|N|${SUBMITTER_PN}|${RUN_DATE}|${REVIEW_PERIOD}
```

| Row | GoalPlanName | GoalPlanTypeCode | Purpose |
|---|---|---|---|
| GOOD-1 | `${PREFIX} DMT Goal Plan A` | `ORA_HRG_WORKER` | valid → `HRG_GOAL_PLANS_B` |
| GOOD-2 | `${PREFIX} DMT Goal Plan B` | `ORA_HRG_WORKER` | valid → `HRG_GOAL_PLANS_B` |
| BAD-1  | `${PREFIX} DMT Goal Plan BAD` | `DMT_INVALID_TYPE` | HDL error, no goal plan |

**Attribute values (all confirmed valid by reading existing plans on the pod):**

- `GoalPlanTypeCode = ORA_HRG_WORKER` — the only worker goal-plan type in the
  `ORA_HRG_GOAL_PLAN_TYPE` LOV. Every existing plan on the pod uses it.
- `GoalAccessLevelCode = ALL` — matches existing plans.
- `GoalPlanActiveFlag = A`, `EnableWeightingFlag = Y`, `EnforceGoalWeightFlag = N`.
- **`IncludeInPerfdocFlag = N` (important).** With `Y`, Fusion requires a
  `GoalPlanDocTypes` child that names a performance-document type, and without it the
  loader rejects every line with *"You can't continue because you haven't selected a
  document type for this goal plan."* Setting it to `N` keeps the fixture
  self-sufficient (no perf-doc-type dependency) and still creates the base row.

**Tokens stamped**

- `${PREFIX}` — run tag; makes each goal plan name/external id unique so re-runs never
  collide.
- `${REVIEW_PERIOD}` — discovered active review period name (e.g. `2026 Annual Cycle`).
- `${RP_START}`, `${RP_END}` — that review period's own start/end dates (`YYYY/MM/DD`),
  used as the plan's StartDate/EndDate so it sits inside an open period.
- `${SUBMITTER_PN}` — discovered existing person number (request submitter).
- `${RUN_DATE}` — today (`YYYY/MM/DD`), the RequestSubmissionDate.

**Bad-row design.** The bad row uses `GoalPlanTypeCode = DMT_INVALID_TYPE`, which is
not in the `ORA_HRG_GOAL_PLAN_TYPE` LOV. HDL rejects it deterministically at the load
phase and creates no goal plan. The two good rows still load (partial success:
load 2 ok / 1 err → terminal status `ORA_IN_ERROR`, which is the expected terminal
here). The bad row's error message carries a NULL `SourceSystemId` and identifies the
line by `FileLine`, so the recipe's `verify` block sets `bad_error_contains`
(`DMT_INVALID_TYPE`) — the harness then matches the SourceSystemId-less error message
by that snippet, and separately confirms the bad goal-plan name is absent from base.

## The exact call (HCM Data Loader REST, credential role `hcm_impl`)

| Step | Method + URL | Body / key |
|---|---|---|
| Upload | `POST {FUSION_URL}/hcmRestApi/resources/11.13.18.05/dataLoadDataSets/action/uploadFile` | `{content:<b64 zip>, fileName}` → `ContentId` |
| Submit | `POST .../dataLoadDataSets/action/createFileDataSet` | `{contentId, fileAction:"IMPORT_AND_LOAD"}` → `RequestId` |
| Poll | `GET .../dataLoadDataSets/{RequestId}` every 30s | `DataSetStatusCode` until terminal |
| Errors | `GET .../dataLoadDataSets/{RequestId}/child/messages?onlyData=true` | per-line `DatFileName` + `FileLine` + `MessageText` |

- **REST resource is `dataLoadDataSets`** (not `hcmDataLoader`, which 404s).
- Terminal statuses: `ORA_COMPLETED` / `ORA_SUCCESS` / `ORA_IN_ERROR` / `ORA_STOPPED`.
  **`ORA_IN_ERROR` is the EXPECTED terminal here** — the one bad row errors on purpose.
- Immediately after `createFileDataSet` the data set is not yet queryable, so the
  first GET may 404; the poller treats that as not-ready and retries.
- The import phase converts the file to stage rows (import counts climb to 3 ok),
  then the load phase applies them (load 2 ok / 1 err). A full pass takes ~2.5 minutes.

## Discovery (run before build, read-only BIP, role `hcm_impl`)

One query returns a single row with the review period name + its dates, one existing
person number, and today's date. HCM tables are reached through the
`ApplicationDB_FSCM` BIP relay with `hcm_impl` credentials (no separate HCM data
source needed).

```sql
SELECT rp.review_period_name AS REVIEW_PERIOD,
       TO_CHAR(rp.start_date,'YYYY/MM/DD') AS RP_START,
       TO_CHAR(rp.end_date,'YYYY/MM/DD')   AS RP_END,
       sub.person_number AS SUBMITTER_PN,
       TO_CHAR(SYSDATE,'YYYY/MM/DD') AS RUN_DATE
FROM (
  SELECT review_period_name, start_date, end_date
  FROM   hrt_review_periods_vl
  WHERE  status_code = 'A'
    AND  SYSDATE BETWEEN start_date AND end_date
    AND  review_period_name NOT LIKE 'Default%'
  ORDER BY start_date DESC FETCH FIRST 1 ROW ONLY
) rp
CROSS JOIN (
  SELECT p.person_number
  FROM   per_all_people_f p
  WHERE  SYSDATE BETWEEN p.effective_start_date AND p.effective_end_date
    AND  REGEXP_LIKE(p.person_number, '^[0-9]+$')
  ORDER BY p.person_id ASC FETCH FIRST 1 ROW ONLY
) sub
```

→ e.g. `${REVIEW_PERIOD}='2026 Annual Cycle'`, `${RP_START}='2026/01/01'`,
`${RP_END}='2026/12/31'`, `${SUBMITTER_PN}='21356'`, `${RUN_DATE}='2026/07/20'`.

Notes on the HCM tables:

- Goal plan base table is **`HRG_GOAL_PLANS_B`** (id `GOAL_PLAN_ID`, external key
  `GOAL_PLAN_EXT_ID`, type `GOAL_PLAN_TYPE_CODE`); the plan name lives in
  **`HRG_GOAL_PLANS_TL`** column `GOAL_PLAN_NAME` (language `US`). (The name tables
  `HRA_GOAL_PLANS_*` do NOT exist on this pod — that name SOAP-faults.)
- Review periods are in **`HRT_REVIEW_PERIODS_VL`** (`REVIEW_PERIOD_NAME`,
  `STATUS_CODE`, `START_DATE`, `END_DATE`); no `LANGUAGE` column on the VL.

## Verification (read-only, direct single-table read)

- **Good → base.** Direct read of `HRG_GOAL_PLANS_B` joined to `HRG_GOAL_PLANS_TL`
  (US) by prefix on the goal plan name. No existing plan name starts with a numeric
  run prefix, so a row returned for `'${PREFIX} DMT Goal Plan A'` / `'B'` with a real
  `GOAL_PLAN_ID` is unambiguously this run's. A `GOAL_PLAN_ID` present for each good
  name = pass.

```sql
SELECT tl.goal_plan_name AS GP_NAME,
       gp.goal_plan_id    AS GOAL_PLAN_ID,
       gp.goal_plan_type_code AS TYP
FROM hrg_goal_plans_b gp
JOIN hrg_goal_plans_tl tl
  ON tl.goal_plan_id = gp.goal_plan_id AND tl.language = 'US'
WHERE tl.goal_plan_name LIKE '<prefix>%'
```

- **Bad → HDL error, absent from base.** The bad evidence is the load-time HDL message
  list keyed by file line (`GET .../{RequestId}/child/messages`); the recipe's
  `bad_error_contains: "DMT_INVALID_TYPE"` matches it despite the NULL SourceSystemId.
  The base read above returns no row for `'${PREFIX} DMT Goal Plan BAD'`, confirming
  absence.

## How to run it

```bash
cd gold_regression/harness
python run_object.py PerformanceEvaluations   # discover -> build -> upload/submit/poll -> verify
```

`run_object.py` passes the discovered tokens into build and the prefix into verify, so
the base read is scoped to exactly the goal plans it just created.

## Live evidence

**2026-07-19 — LIVE-PROVEN. PASS.**

Standalone load path only; verification via the read-only BIP relay only.

| Field | Value |
|---|---|
| Date | 2026-07-19 |
| Prefix | `43426` |
| HDL data set RequestId | `9764288` |
| Terminal DataSetStatusCode | `ORA_IN_ERROR` (expected: 2 good loaded, 1 bad errored) |
| Import / Load counts | import 3 ok / 0 err; load **2 ok / 1 err** |
| Discovered review period | `2026 Annual Cycle` (2026/01/01–2026/12/31) |
| Discovered submitter | person number `43426`-run submitter (lowest active numeric person) |

**Good rows → base table `HRG_GOAL_PLANS_B` (2/2):**

| GoalPlanName | GOAL_PLAN_ID | GoalPlanTypeCode |
|---|---|---|
| `43426 DMT Goal Plan A` | `300000331553042` | `ORA_HRG_WORKER` |
| `43426 DMT Goal Plan B` | `300000331553046` | `ORA_HRG_WORKER` |

**Bad row → HDL error, no goal plan created (1/1):**

| GoalPlanName (file line 4) | HDL error |
|---|---|
| `43426 DMT Goal Plan BAD` | `The DMT_INVALID_TYPE value for the GoalPlanTypeCode attribute is invalid and doesn't exist in the ORA_HRG_GOAL_PLAN_TYPE list of values.` |

The two good goal plans reached `HRG_GOAL_PLANS_B` with real `GOAL_PLAN_ID`s,
referencing only the discovered existing review period and existing submitter person;
the bad row errored in the loader (file line 4) and created no goal plan (absent from
the base read). Gold zip `PerformanceEvaluations_gold.zip` (last built at prefix
43426) kept here.

**Earlier-attempt note (fixed, same load session):** first load with
`IncludeInPerfdocFlag = Y` rejected both good rows with *"you haven't selected a
document type for this goal plan"* — with `Y` the loader needs a `GoalPlanDocTypes`
child naming a perf-document type. Fixed by setting `IncludeInPerfdocFlag = N`, which
keeps the fixture dependency-free and still creates the base row.

## Harness note

No harness code change was needed. The recipe uses the existing generic HDL path
(`run_object.py` → `discover` → `build_artifact` → `load_hdl` → `verify`). The only
object-specific pieces are `recipe.json` (discovery + verify SQL, `bad_error_contains`
for the NULL-SourceSystemId HDL error) and the `GoalPlan.dat` template. The
`bad_error_contains` matcher already existed in `verify.py` for update-by-user-key HDL
loads that return a NULL SourceSystemId.
