# ProjectBudgets — gold regression object notes

Import Project Budgets (project plan versions) via FBDI. Full call library, discovery,
and verification live in `GOLD_README.md` next to this file. This file is the durable
per-object memory (same role as every other `objects/{Name}/README.md`).

## The object in one line
One FBDI zip, one CSV `PjoPlanVersionsXface.csv` (62 columns, no header), loaded to the
interface table `PJO_PLAN_VERSIONS_XFACE`, then imported to the base plan tables
(`PJO_PLAN_VERSIONS_B` + the free-text name in `PJO_PLAN_VERSIONS_TL.VERSION_NAME`).

## Confirmed facts (live, 2026-07-19)

- **Interface options row id 39** (`DMT_ERP_INTERFACE_OPTIONS_TBL`): ERP family `PRJ`,
  UCM account `prj/projectControl/import`, load/import job
  `/oracle/apps/ess/projects/control/budgetsAndForecasts;ImportBudgetsInterfaceData`,
  loader type `SQLLOADER`.
- **ParameterList is `#NULL`.** Import Project Budgets takes no positional ESS args; all
  processing instructions live in the CSV (column 62 `PROCESSING_MODE = 'Create'`).
- **Two-step ESS orchestration.** `loadAndImportData` runs ONLY the interface loader
  (its ESS log shows just the async file transfer + `InterfaceLoaderSqlldrImport`
  SQL*Loader children — it does NOT chain the budget import). A SECOND ESS job,
  `ImportBudgetsInterfaceData` submitted via `submitESSJobRequest`, moves the rows from
  `PJO_PLAN_VERSIONS_XFACE` into the base plan tables. The recipe declares it as a
  `downstream_jobs` step.
- **Accepted budget-line shape** (reverse-engineered from the pod's own successful
  `PJO_PLAN_VERSIONS_XFACE` history): `PROCESSING_MODE = 'Create'`,
  `LINE_TYPE = 'PERIODIC'`, `PLAN_VERSION_STATUS = 'Working'`, one task number, one
  resource name, one project accounting period name (e.g. `Period 1` — a PA period, not
  a GL `MM-YY` period), a planning currency, and a raw cost.
- **Base name storage:** `PJO_PLAN_VERSIONS_B` keeps only a numeric `VERSION_NUMBER`;
  the free-text FBDI `PLAN_VERSION_NAME` lands in `PJO_PLAN_VERSIONS_TL.VERSION_NAME`.
  Verify good rows by that name (prefix-stamped) or by
  `PJO_PLAN_VERSIONS_B.REQUEST_ID = <import ESS request id>`.

## Data-quality gotchas (learned the hard way)

- **Numeric columns must not be empty-quoted.** The FBDI CTL types column 61
  `PLAN_VERSION_NUMBER` (and the quantity/cost columns) as NUMBER. An empty *enclosed*
  value `""` fails SQL*Loader with `ORA-01722: invalid number` and the row is rejected.
  Emit numeric empties as bare fields (`,,`), not `"",""`. The first live attempt
  (load 9763700) rejected all 3 rows on exactly this; the fix (bare numeric empties)
  loaded 3/3 rows cleanly (load 9763857, 9763995).
  **Latent bug in the DMT generator:** `DMT_PRJ_BUDGET_FBDI_GEN_PKG.gen_budget_csv`
  emits `qn(NULL) = '""'` for NULL numeric columns, which will hit this same ORA-01722
  on `PLAN_VERSION_NUMBER`. Documented here for a future port fix (not edited — gold
  regression touches no tool code).
- **`DeleteOnLoadFailure = Y`.** If the SQL*Loader step rejects ANY record, the loader
  marks the job ERROR and DELETES every row it loaded for that `LOAD_REQUEST_ID`. So the
  BAD row must be structurally valid to SQL*Loader (a plain string in
  `FINANCIAL_PLAN_TYPE`) and only fail later at the Fusion *import* validation — never a
  malformed CSV row, which would wipe the good rows too.

## Sponsored-project references (award + funding source)
The demo pod's budget-capable projects are sponsored (award-backed), so a budget line
needs two extra references beyond project/plan-type/task/resource/period/currency:
- **AWARD_NUMBER** (CSV column 1) — else `PJO_BOI_AWARD_NUM_NOT_PROVD`.
- **FUNDING_SOURCE_NAME** (CSV column 18) — else "The funding source name or the funding
  source number must be provided for all resources assigned to a task."
Both are discovered from the pod's own successful `PJO_PLAN_VERSIONS_XFACE` history.

## Portability
Discovery reuses a project + plan type + task + resource + period + award + funding
source the target pod has already accepted (an existing `SUCCESS` / `Create` row in
`PJO_PLAN_VERSIONS_XFACE` on an APPROVED, non-template project). Nothing is hardcoded; no
id is stamped. On this pod the discovered tuple is project `DON003-1`, plan type
`UNIVUS Approved Cost Budget`, task `1.0`, resource `Major Equipment`, period `Period 1`,
currency `USD`, award `DON003`, funding source `Alumni Donor`.

## BIP replica caveat (important)
The read-only BIP replica used for verification lags badly for these tables on this pod:
`PJO_PLAN_VERSIONS_B` stayed frozen at `2026-07-19 23:26` through 12 minutes of polling
(never captured loads submitted at 23:47+), and `PJO_PLAN_VERSIONS_XFACE` replicated only
through `2025-11-14`. Base-table confirmation therefore has to come from the Import
Project Budgets ESS job output (which reports created plan-version ids live) or a later
direct read once the replica refreshes — not from an immediate post-load BIP read.

## Live evidence
**LIVE-PROVEN 2026-07-20, prefix 95661.** Load ESS 9764471 → auto-import 9764476 →
Import Budget Report 9764483 (SUCCESS 2 / FAILURE 1 / TOTAL 3). Good rows
`95661RT-PBUD-G1` / `G2` reached `PJO_PLAN_VERSIONS_B` (ids 100002547416587 /
100002547416619, class BUDGET); bad row `95661RT-PBUD-B` rejected with invalid
financial plan type (`PJO_XFACE_INVALID_FPT`) and absent from base. Full detail,
request ids, and the getting-there iterations are in `GOLD_README.md`.
