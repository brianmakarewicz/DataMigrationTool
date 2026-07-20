# ProjectBudgets — v2 seeded gold fixture

Converted from the frozen v1 fixture (`../../objects/ProjectBudgets/`). Same 2 good
+ 1 bad project budget plan versions, loaded via the single FBDI path
(`loadAndImportData` into `PJO_PLAN_VERSIONS_XFACE`, whose chained import job Fusion
runs and then auto-spawns the Import Project Budgets child), with read-only BIP
verification against the budget base tables and (documented) the interface table. No
DMT database and no DMT pipeline code are in the load path.

The one difference from v1: the project, financial plan type, task, resource, period,
currency, award, and funding source are **hard-coded to standard seeded values** that
ship on the demo pod, instead of discovered at load time. The v1 `PRJ_BUDGET_REF`
discovery block is deleted.

## The hard-coded seeds (what v1 discovered → now literals)

v1 discovered "the top accepted budget tuple on an approved, non-template project"
from the pod's own `PJO_PLAN_VERSIONS_XFACE` SUCCESS history. On this demo pod that
resolved to the values below. Every one is **standard seeded demo data we never
loaded** — none carries an `RT`/prefix (the project is a seeded sponsored project,
`Research Innovation Center Upgrade - Equipment Procurement`). Confirmed present and
prefix-free via read-only BIP before writing (project APPROVED + non-template, and the
full eight-value tuple present together in the pod's own accepted history):

| Reference | Literal value |
|---|---|
| Project number | `DON003-1` |
| Project name | `Research Innovation Center Upgrade - Equipment Procurement` |
| Financial plan type | `UNIVUS Approved Cost Budget` |
| Task number | `1.0` |
| Resource name | `Major Equipment` |
| Period name | `Period 1` |
| Planning currency | `USD` |
| Award number (sponsored project) | `DON003` |
| Funding source name | `Alumni Donor` |

These are written as literals directly into `artifact/PjoPlanVersionsXface.csv` and
into the verify base read in `recipe.json` (`pe.segment1 = 'DON003-1'`).

`${PREFIX}` stays exactly as in v1 on the three plan version names
(`${PREFIX}RT-PBUD-G1`, `${PREFIX}RT-PBUD-G2`, `${PREFIX}RT-PBUD-B`), their
`SRC_BUDGET_LINE_REFERENCE`s, and inside the bad row's invalid financial plan type
`ZZ-INVALID-PLAN-TYPE-${PREFIX}`, so the fixture reloads on a fresh prefix without
colliding.

## Sponsored-project requirements (kept from v1)

`DON003-1` is an award-backed (sponsored) project, so each budget line must carry two
extra references or Import Project Budgets rejects it:
1. **AWARD_NUMBER** (CSV column 1) = `DON003` — missing it gives
   `PJO_BOI_AWARD_NUM_NOT_PROVD`.
2. **FUNDING_SOURCE_NAME** (CSV column 18) = `Alumni Donor` — missing it gives
   "The funding source name or the funding source number must be provided...".

Both are now hard-coded literals in the CSV.

## The ESS orchestration (unchanged from v1)

`loadAndImportData` (endpoint `{FUSION_URL}/fscmService/ErpIntegrationService`, UCM
account `prj/projectControl/import`, `interfaceDetails` 39, ParameterList `#NULL`)
loads the CSV into `PJO_PLAN_VERSIONS_XFACE` and chains its interface loader. Fusion
then **auto-spawns the Import Project Budgets job**
(`ImportBudgetsInterfaceData`) as a separate top-level request that picks up the
just-loaded interface rows. **Do NOT submit a standalone `ImportBudgetsInterfaceData`
with `#NULL`** — an independently submitted one selects by from/to-project criteria and
with `#NULL` matches 0 projects. The recipe carries no `downstream_jobs`; the harness
just polls the load and reads the base/interface tables by prefix. The auto-spawned
import creates the base plan versions and emits its Import Budget Report
(`BudgetsXfaceBIP` / `ImportBudget.xdo`) with the per-row outcome.

## Verification (read-only, via the BIP relay)

- **Good → base tables `PJO_PLAN_VERSIONS_B` / `PJO_PLAN_VERSIONS_TL` (2/2).** The
  plan version name lives in `PJO_PLAN_VERSIONS_TL.VERSION_NAME`; read back by prefix,
  joined to the base version and the seeded project `DON003-1`. Both
  `${PREFIX}RT-PBUD-G1/G2` present with a real `PLAN_VERSION_ID` and
  `PLAN_CLASS_CODE = BUDGET` = pass.
- **Bad → rejected, absent from base.** The bad row carries an invalid
  `FINANCIAL_PLAN_TYPE` (`ZZ-INVALID-PLAN-TYPE-${PREFIX}`); Import Project Budgets
  rejects it (`PJO_XFACE_INVALID_FPT`) so it never reaches base.

### Bad-row proof: absence from base (`bad_proof_is_absence`)

This object's recipe sets `bad_proof_is_absence: true`. The BIP read-only replica for
the interface table `PJO_PLAN_VERSIONS_XFACE` lags **far** behind on this pod (v1 noted
up to months behind; for this run's prefix the interface replica returned **zero** rows
minutes after the load even though the good rows had already reached the base tables).
So the standard `interface_read` cannot surface the rejected row's ERROR at verify time.
The authoritative, replica-independent BAD proof is therefore **absence from base while
the good rows from the same load reached base**. The human-readable rejection text
(`PJO_XFACE_INVALID_FPT`) lives in the auto-spawned import's Import Budget Report XML —
v1 captured it live (see v1 GOLD_README, prefix 95661). The `interface_read` block is
retained in the recipe so the interface-ERROR read is used automatically once/if the
replica catches up.

## How to run it

```bash
cd gold_regression
GOLD_OBJECTS_SUBDIR=objects_seeded python harness/run_object.py ProjectBudgets
```

## Live evidence (v2, via `GOLD_OBJECTS_SUBDIR=objects_seeded`)

**2026-07-20 — LIVE-PROVEN. PASS.**

Standalone load path only (no DMT database / code in the load path); verification via
the read-only BIP relay only.

| Field | Value |
|---|---|
| Date | 2026-07-20 |
| Prefix (kept in the gold zip) | `96447` |
| Load ESS request id (`loadAndImportData`) | `9766255` |
| Load terminal status | `SUCCEEDED` |
| Auto-spawned Import Project Budgets child | `9766265` → SUCCEEDED |
| Import Budget Report job (`BudgetsXfaceBIP`) | `9766295` → SUCCEEDED |
| Seeded project | `DON003-1` (`Research Innovation Center Upgrade - Equipment Procurement`) |
| Seeded plan type / task / resource / period / currency | `UNIVUS Approved Cost Budget` / `1.0` / `Major Equipment` / `Period 1` / `USD` |
| Seeded award / funding source | `DON003` / `Alumni Donor` |

**Good rows → base `PJO_PLAN_VERSIONS_B` / `_TL` (2/2)** — both present with a real
`PLAN_VERSION_ID` and `PLAN_CLASS_CODE = BUDGET`:

| VERSION_NAME | PLAN_VERSION_ID | PLAN_CLASS_CODE |
|---|---|---|
| `96447RT-PBUD-G1` | `100002547480378` | BUDGET |
| `96447RT-PBUD-G2` | `100002547480410` | BUDGET |

**Bad row → rejected, absent from base (1/1):**

| VERSION_NAME | Proof / error |
|---|---|
| `96447RT-PBUD-B` | Absent from base (`absent_from_base`) while both good rows from the same load reached base. Carries invalid `FINANCIAL_PLAN_TYPE = ZZ-INVALID-PLAN-TYPE-96447`; rejected by Import Project Budgets with `PJO_XFACE_INVALID_FPT` ("The financial plan type ... doesn't exist in Oracle Fusion Project Control"). Interface xface replica returned 0 rows at verify time (documented replica lag), so the ERROR is proven by absence + the import report. |

## Files
- `recipe.json` — no discovery; seeded literals; good/bad rows; ESS job; verify reads (`bad_proof_is_absence`)
- `artifact/PjoPlanVersionsXface.csv` — templated 3-row CSV (2 good + 1 bad), seeded literals
- `ProjectBudgets_gold.zip` — last assembled ready-to-load artifact
