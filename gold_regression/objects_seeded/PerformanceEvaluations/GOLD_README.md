# PerformanceEvaluations — v2 seeded gold fixture (HDL, GoalPlan)

Converted from the frozen v1 fixture (`../../objects/PerformanceEvaluations/`). Same two
good + one bad **GoalPlan** records, loaded via HCM Data Loader (upload →
createFileDataSet → poll), verified read-only against base table `HRG_GOAL_PLANS_B`
(name in `HRG_GOAL_PLANS_TL`, language `US`). No DMT tool code and no DMT database are in
the load path. The difference from v1: the review period, its dates, and the request
submitter person are **hard-coded to standard seeded values**, not discovered.

## What v1 discovered → now hard-coded literals

v1's discovery block ran one read-only BIP query and resolved:

- an active review period spanning today (excluding `Default%`),
- that period's start/end dates (used as the plan's StartDate/EndDate),
- the lowest-`person_id` active numeric person number as request submitter,
- today's date for RequestSubmissionDate.

v2 removes the discovery block entirely. The resolved values were confirmed live on the
pod (BIP, role `hcm_impl`, 2026-07-20) and written as literals in `GoalPlan.dat`:

| Reference | Literal value | Why it is safe seeded data |
|---|---|---|
| Review period name | `2026 Annual Cycle` | seeded performance review cycle; not one we loaded |
| Plan StartDate / EndDate | `2026/01/01` / `2026/12/31` | the seeded period's own open date range (spans today) |
| Request submitter (ReqSubmittedByPersonNumber) | `21356` | seeded demo employee (Rodriguez, effective since 2000/05/01) — we never loaded it |

`RequestSubmissionDate` uses the harness-derived token `${GL_DATE_SLASH}` (today,
`YYYY/MM/DD`) so no discovery and no stale hard-coded date — today's date always lands
inside the open period. All other attributes are unchanged from v1
(`GoalPlanTypeCode=ORA_HRG_WORKER`, `GoalAccessLevelCode=ALL`, `IncludeInPerfdocFlag=N`).

## Re-run safety (why this object is NOT the stateful case)

Each good row creates a **brand-new goal plan** whose name and external id carry
`${PREFIX}`. A fresh prefix each run yields distinct plan names/external ids, so a second
consecutive run inserts new goal plans and never collides with the first — no
date-effective trick needed (unlike Salaries). `${PREFIX}` stays on the goal-plan name and
external id exactly as in v1.

## The DAT (`GoalPlan.dat`, pipe-delimited HDL, discriminator `GoalPlan`)

```
METADATA|GoalPlan|GoalPlanExternalId|GoalPlanName|GoalPlanTypeCode|GoalPlanActiveFlag|EnableWeightingFlag|StartDate|EndDate|EnforceGoalWeightFlag|GoalAccessLevelCode|IncludeInPerfdocFlag|ReqSubmittedByPersonNumber|RequestSubmissionDate|ReviewPeriodName
MERGE|GoalPlan|GP_${PREFIX}_1|${PREFIX} DMT Goal Plan A|ORA_HRG_WORKER|A|Y|2026/01/01|2026/12/31|N|ALL|N|21356|${GL_DATE_SLASH}|2026 Annual Cycle
MERGE|GoalPlan|GP_${PREFIX}_2|${PREFIX} DMT Goal Plan B|ORA_HRG_WORKER|A|Y|2026/01/01|2026/12/31|N|ALL|N|21356|${GL_DATE_SLASH}|2026 Annual Cycle
MERGE|GoalPlan|GP_${PREFIX}_3|${PREFIX} DMT Goal Plan BAD|DMT_INVALID_TYPE|A|Y|2026/01/01|2026/12/31|N|ALL|N|21356|${GL_DATE_SLASH}|2026 Annual Cycle
```

| Row | GoalPlanName | GoalPlanTypeCode | Outcome |
|---|---|---|---|
| GOOD-1 | `${PREFIX} DMT Goal Plan A` | `ORA_HRG_WORKER` | valid → `HRG_GOAL_PLANS_B` |
| GOOD-2 | `${PREFIX} DMT Goal Plan B` | `ORA_HRG_WORKER` | valid → `HRG_GOAL_PLANS_B` |
| BAD-1  | `${PREFIX} DMT Goal Plan BAD` | `DMT_INVALID_TYPE` | HDL load error, no goal plan |

**Bad-row design.** `DMT_INVALID_TYPE` is not in the `ORA_HRG_GOAL_PLAN_TYPE` LOV, so HDL
rejects that one line deterministically (terminal `ORA_IN_ERROR`: load 2 ok / 1 err) and
creates no goal plan. Its HDL error carries a NULL SourceSystemId, so `verify` matches it
via `bad_error_contains: "DMT_INVALID_TYPE"` and separately confirms the bad name is absent
from base.

## Verification (read-only, role `hcm_impl`)

Direct base read of `HRG_GOAL_PLANS_B` joined to `HRG_GOAL_PLANS_TL` (US) filtered by
`goal_plan_name LIKE '${PREFIX}%'`. A `GOAL_PLAN_ID` returned for each good name = pass; the
bad name returns no row.

## Live evidence (v2, via `GOLD_OBJECTS_SUBDIR=objects_seeded`)

**2026-07-20 — LIVE-PROVEN. PASS. Two consecutive runs both passed (re-run safe).**

Standalone HDL load path only; verification via the read-only BIP relay only.

### Run 1

| Field | Value |
|---|---|
| Prefix | `29379` |
| HDL data set RequestId | `9766647` |
| Terminal DataSetStatusCode | `ORA_IN_ERROR` (expected: 2 good loaded, 1 bad errored) |
| Import / Load counts | import 3 ok / 0 err; load **2 ok / 1 err** |

Good → base `HRG_GOAL_PLANS_B` (2/2):

| GoalPlanName | GOAL_PLAN_ID | TYP |
|---|---|---|
| `29379 DMT Goal Plan A` | `300000331573915` | `ORA_HRG_WORKER` |
| `29379 DMT Goal Plan B` | `300000331573918` | `ORA_HRG_WORKER` |

Bad → HDL error, no goal plan (absent from base): `29379 DMT Goal Plan BAD` →
`The DMT_INVALID_TYPE value for the GoalPlanTypeCode attribute is invalid and doesn't exist in the ORA_HRG_GOAL_PLAN_TYPE list of values.`

### Run 2 (immediately after run 1 — proves re-runs don't collide)

| Field | Value |
|---|---|
| Prefix | `42443` |
| HDL data set RequestId | `9766728` |
| Terminal DataSetStatusCode | `ORA_IN_ERROR` (expected) |

Good → base `HRG_GOAL_PLANS_B` (2/2): new goal plans at a fresh prefix —
`42443 DMT Goal Plan A` → `300000331574194`, `42443 DMT Goal Plan B` → `300000331574191`.
Bad row `42443 DMT Goal Plan BAD` errored the same way and created no goal plan (absent from
base). Distinct prefix → distinct plan names/ids, so the second run never collided with the
first. **Re-runs work.**

## How to run

```bash
cd gold_regression/harness
GOLD_OBJECTS_SUBDIR=objects_seeded python run_object.py PerformanceEvaluations
# run it again immediately — a fresh prefix gives fresh goal-plan names, so it passes again
```

## Harness note

No harness code change was needed. This v2 fixture reuses the existing generic HDL path
(`run_object.py` → build → `load_hdl` → `verify`) and the pre-existing derived token
`${GL_DATE_SLASH}` (today) for RequestSubmissionDate. The only object-specific pieces are
`recipe.json` (no discovery block; verify SQL + `bad_error_contains`) and the seeded
`GoalPlan.dat` template.
