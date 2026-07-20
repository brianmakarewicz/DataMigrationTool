# ProjectBudgets — Gold Regression Fixture

Import Project Budgets (project plan versions) via FBDI. Standalone load path
(no DMT database, no DMT pipeline code). Verification is read-only through the
BIP relay with direct single-table reads.

## What this fixture loads

One FBDI zip (`ProjectBudgets_gold.zip`) containing a single CSV
`PjoPlanVersionsXface.csv` (62 columns, no header, position-based). It creates
**three project budget plan versions** on one existing, already-approved project:

- 2 GOOD versions: `${PREFIX}RT-PBUD-G1`, `${PREFIX}RT-PBUD-G2` — valid financial
  plan type, task, resource, period and currency. They must reach the base tables.
- 1 BAD version: `${PREFIX}RT-PBUD-B` — identical except the FINANCIAL_PLAN_TYPE is
  the deterministically-invalid literal `ZZ-INVALID-PLAN-TYPE-${PREFIX}`. Import
  Project Budgets cannot resolve that plan type, so the row stays in the interface
  table `PJO_PLAN_VERSIONS_XFACE` with `LOAD_STATUS = 'ERROR'` and never reaches base.

`${PREFIX}` is a fresh numeric prefix stamped at load time so the fixture reloads
without colliding with earlier runs.

## Portability — no upstream dependency

A project budget attaches to an EXISTING project and an EXISTING financial plan
type. This fixture creates neither. At load time it runs one read-only BIP
discovery query that finds a project the target pod already has, which has
previously accepted a budget import for some plan type, and reuses that exact
proven tuple (project number, project name, financial plan type, task number,
resource name, project accounting period, currency). Nothing is hardcoded; no id
is stamped; the good rows only create NEW plan versions (prefix-stamped names).

### Discovery query (read-only, fin_impl, run against the TARGET pod)

Returns the top project + plan-type + task + resource + period that Fusion has
already accepted (`PJO_PLAN_VERSIONS_XFACE.LOAD_STATUS = 'SUCCESS'`,
`PROCESSING_MODE = 'Create'`, `LINE_TYPE = 'PERIODIC'`) for an approved,
non-template project. Because that exact tuple already loaded once, it will load
again, which is what makes the fixture portable.

```sql
SELECT * FROM (
  SELECT x.project_number PNUM, x.project_name PNAME, x.financial_plan_type FPT,
         x.task_number TASKNUM, x.resource_name RES, x.period_name PERNAME,
         x.planning_currency CUR
  FROM pjo_plan_versions_xface x
  JOIN pjf_projects_all_vl pe  ON pe.segment1  = x.project_number
  JOIN pjf_projects_all_b  pab ON pab.project_id = pe.project_id
  WHERE x.processing_mode = 'Create'
    AND x.line_type       = 'PERIODIC'
    AND x.load_status     = 'SUCCESS'
    AND x.task_number     IS NOT NULL
    AND x.resource_name   IS NOT NULL
    AND x.period_name     IS NOT NULL
    AND x.planning_currency IS NOT NULL
    AND pab.project_status_code = 'APPROVED'
    AND NVL(pab.template_flag,'N') = 'N'
  ORDER BY x.project_number, x.resource_name
) WHERE ROWNUM = 1;
```

Discovered tokens stamped into the CSV: `${PROJECT_NUMBER}`, `${PROJECT_NAME}`,
`${FIN_PLAN_TYPE}`, `${TASK_NUMBER}`, `${RESOURCE_NAME}`, `${PERIOD_NAME}`,
`${CURRENCY}`.

## The exact web-service call (ESS orchestration)

**Endpoint:** `<fusion_url>/fscmService/ErpIntegrationService`
**Operation:** `loadAndImportData` (HTTP Basic auth as `fin_impl`)
**Auth user:** `fin_impl`

`loadAndImportData` is one call that (1) base64-uploads the zip to UCM under the
Document Account, (2) runs "Load File to Interface Tables" to unpack the CSV into
`PJO_PLAN_VERSIONS_XFACE`, and (3) chains the import job named in `<JobName>`.

| Field | Value |
|---|---|
| DocumentAccount | `prj/projectControl/import` |
| JobName | `/oracle/apps/ess/projects/control/budgetsAndForecasts,ImportBudgetsInterfaceData` |
| ParameterList | `#NULL` |
| interfaceDetails | `39` |
| notificationCode | `10` |

**ParameterList is `#NULL` (spelled out): the Import Project Budgets job takes no
positional ESS arguments.** All processing instructions travel in the CSV itself —
column 62 `PROCESSING_MODE = 'Create'` tells the import to create new plan
versions. This mirrors the DMT loader, which sets the ProjectBudgets ParameterList
to `#NULL` (see `DMT_LOADER_PKG`, ProjectBudgets branch) and matches interface
option row id 39 (`DMT_ERP_INTERFACE_OPTIONS_TBL`: ERP_FAMILY `PRJ`, UCM
`prj/projectControl/import`, LOADER_TYPE `SQLLOADER`).

The `<result>` of `loadAndImportData` is the LOAD ESS request id. We poll it with
`getESSJobStatus` every 60s until a terminal status (SUCCEEDED / WARNING / FAILED /
ERROR / EXPIRED).

**Orchestration (verified live 2026-07-19/20).** `loadAndImportData` submits the
UCM upload + "Load Interface File for Import" (its own ESS log shows only the two
interface-loader children: async file transfer + `InterfaceLoaderSqlldrImport`
SQL*Loader). Fusion then **auto-spawns the Import Project Budgets job**
(`ImportBudgetsInterfaceData`) as a separate top-level ESS request that picks up the
just-loaded interface rows by project name and process code `IMPORT_BUDGET`. Do NOT
submit a standalone `ImportBudgetsInterfaceData` with `#NULL` — an independently
submitted one selects rows by from/to-project criteria and, with `#NULL`, matches
0 projects. The correct move is to LET the auto-spawned child run and find it.

**Finding the import child** (mirrors the DMT loader's `GET_IMPORT_ESS_ID`, which
reads `/Custom/DMT/common/DMT_ESS_CHILD_JOB_RPT`): query the ESS request history for
the first `ImportBudgetsInterfaceData` request submitted after the load id.

```sql
SELECT r.requestid
FROM   fusion.ess_request_history r
WHERE  r.definition LIKE '%ImportBudgetsInterfaceData%'
  AND  r.requestid > :LOAD_ESS_ID
ORDER BY r.requestid ASC
FETCH FIRST 1 ROW ONLY;
```

That import (a) stamps the interface rows with its request id, (b) calls the
`processBudgetsXfaceDataAsync` web service to create the base plan versions, and
(c) spawns a reporting job `BudgetsXfaceBIP` (report `ImportBudget.xdo`) whose id is
printed in the import log as `Reporting job requestId = <id>`. That report is the
authoritative, replica-independent per-row outcome (see Verification).

**Sponsored-project requirements (learned live 2026-07-20).** The demo pod's
budget-capable projects are sponsored (award-backed). A budget line on such a project
must carry TWO extra references or it is rejected:
1. **AWARD_NUMBER** (CSV column 1) — missing it gives `PJO_BOI_AWARD_NUM_NOT_PROVD`
   ("...is a sponsored project, however an award number wasn't entered").
2. **FUNDING_SOURCE_NAME** (CSV column 18) — missing it gives "The funding source name
   or the funding source number must be provided for all resources assigned to a task."
Discovery pulls both from the pod's own successful history
(`PJO_PLAN_VERSIONS_XFACE.AWARD_NUMBER` and `.FUNDING_SOURCE_NAME`) and stamps them in.
On this pod: award `DON003`, funding source name `Alumni Donor`.

## CSV layout (PjoPlanVersionsXface.csv — 62 columns, no header)

Position → column (values actually populated by the fixture in **bold**):

**1 AWARD_NUMBER** (sponsored projects) · **2 FINANCIAL_PLAN_TYPE** ·
**3 PROJECT_NUMBER** · **4 PROJECT_NAME** · 5 TASK_NAME · **6 TASK_NUMBER** ·
**7 PLAN_VERSION_NAME** · **8 PLAN_VERSION_DESCRIPTION** ·
**9 PLAN_VERSION_STATUS** (`Working`) · **10 RESOURCE_NAME** · **11 PERIOD_NAME** ·
**12 PLANNING_CURRENCY** · 13 TOTAL_QUANTITY · **14 TOTAL_TC_RAW_COST** (`1000`) ·
15 TOTAL_TC_REVENUE · **16 SRC_BUDGET_LINE_REFERENCE** · 17 FUNDING_SOURCE_NUMBER ·
**18 FUNDING_SOURCE_NAME** (required on award projects) · 19–25 cost columns ·
**26 LINE_TYPE** (`PERIODIC`) · 27–28 planning dates · 29 REQUEST_ID (blank) ·
30 ATTRIBUTE_CATEGORY · 31–60 ATTRIBUTE1–30 · 61 PLAN_VERSION_NUMBER (bare-empty —
NOT `""`, or SQL*Loader ORA-01722) · **62 PROCESSING_MODE** (`Create`).

The accepted-line shape (mode `Create`, line type `PERIODIC`, status `Working`,
one task + one resource + one period + a raw cost) was reverse-engineered from the
pod's own successful `PJO_PLAN_VERSIONS_XFACE` history, so it matches exactly what
Import Project Budgets has already accepted.

## Verification

### Primary — the Import Budget Report (replica-independent, authoritative)
The auto-spawned import's reporting job (`BudgetsXfaceBIP`, report `ImportBudget.xdo`)
emits `ESS_O_<reportId>_BIP.xml` with, per row, `DATA_REF_COL4` = plan version name,
`DATA_REF_COL3` = financial plan type, `MESSAGE_TEXT` = the rejection reason (empty =
created), and a summary `<SUCCESS_COUNT>/<FAILURE_COUNT>/<TOTAL_COUNT>`. Fetch it with
`downloadESSJobExecutionDetails` for the report request id. This reads live Fusion, so
it does not wait on the BIP base-table replica.

- GOOD pass: the two `<PREFIX>RT-PBUD-G1/G2` rows appear with **no** `MESSAGE_TEXT`
  (created), contributing to `SUCCESS_COUNT`.
- BAD pass: `<PREFIX>RT-PBUD-B` appears with `MESSAGE_TEXT` =
  *"The financial plan type ZZ-INVALID-PLAN-TYPE-<PREFIX> ... doesn't exist in Oracle
  Fusion Project Control. Enter a valid financial plan type."* (message
  `PJO_XFACE_INVALID_FPT`).

### Secondary — direct base read (once the replica catches up)
`PJO_PLAN_VERSIONS_TL.VERSION_NAME` stores the free-text plan version name (the
base table `PJO_PLAN_VERSIONS_B` only keeps a `VERSION_NUMBER`). We read the name
back by prefix, joined to the base version and its project:

```sql
SELECT tl.version_name AS VERSION_NAME,
       TO_CHAR(pv.plan_version_id) AS PLAN_VERSION_ID,
       pv.plan_class_code AS PLAN_CLASS_CODE
FROM pjo_plan_versions_tl tl
JOIN pjo_plan_versions_b pv ON pv.plan_version_id = tl.plan_version_id
JOIN pjf_projects_all_vl pe ON pe.project_id = pv.project_id
WHERE tl.language = 'US'
  AND pe.segment1 = '<discovered PROJECT_NUMBER>'
  AND tl.version_name LIKE '<PREFIX>RT-PBUD-%';
```

Both `<PREFIX>RT-PBUD-G1` and `<PREFIX>RT-PBUD-G2` present with a real
`PLAN_VERSION_ID` == good pass.

### BAD → interface error, absent from base
```sql
SELECT x.plan_version_name AS VERSION_NAME,
       TO_CHAR(x.plan_version_xface_id) AS XFACE_ID,
       x.financial_plan_type AS FIN_PLAN_TYPE,
       (x.load_status || DECODE(x.process_code, NULL, '', ' / process_code=' || x.process_code))
         AS ERROR_MESSAGE
FROM pjo_plan_versions_xface x
WHERE x.load_request_id = <LOAD ESS request id>
  AND x.plan_version_name LIKE '<PREFIX>RT-PBUD-%'
  AND x.load_status = 'ERROR';
```

`<PREFIX>RT-PBUD-B` present with `LOAD_STATUS = 'ERROR'` and carrying the invalid
`FINANCIAL_PLAN_TYPE`, and absent from the base read above == bad pass.

Note on error text: this base-table replica exposes no per-row free-text error
column on `PJO_PLAN_VERSIONS_XFACE` — the deterministic machine signal is
`LOAD_STATUS = 'ERROR'` (contrast the good rows' `SUCCESS`). The human-readable
"invalid financial plan type" reason lives in the Import Project Budgets ESS
output/log.

## Live-proven evidence

**LIVE-PROVEN 2026-07-19/20, prefix 95661.**
- Load ESS request id **9764471** (`loadAndImportData`) → SUCCEEDED; SQL*Loader loaded
  3/3 rows into `PJO_PLAN_VERSIONS_XFACE` (0 rejected).
- Auto-spawned Import Project Budgets child **9764476** → SUCCEEDED; its Import Budget
  Report **9764483** reported **SUCCESS_COUNT=2, FAILURE_COUNT=1, TOTAL_COUNT=3**.
- GOOD → base: `95661RT-PBUD-G1` = `PJO_PLAN_VERSIONS_B.PLAN_VERSION_ID`
  **100002547416587**, `95661RT-PBUD-G2` = **100002547416619** (both PLAN_CLASS_CODE
  `BUDGET`, project DON003-1; names in `PJO_PLAN_VERSIONS_TL.VERSION_NAME`).
- BAD → rejected + absent from base: `95661RT-PBUD-B` carried
  `FINANCIAL_PLAN_TYPE = ZZ-INVALID-PLAN-TYPE-95661` and was rejected with
  *"The financial plan type ZZ-INVALID-PLAN-TYPE-95661 entered for the project doesn't
  exist in Oracle Fusion Project Control. Enter a valid financial plan type."*
  (message `PJO_XFACE_INVALID_FPT`); a direct base read for that name returns 0 rows.
- Discovered references (portable, from the pod's own accepted history): project
  `DON003-1`, plan type `UNIVUS Approved Cost Budget`, task `1.0`, resource
  `Major Equipment`, period `Period 1`, currency `USD`, award `DON003`, funding source
  `Alumni Donor`.

Note on the getting-there iterations: prefix 14925 (load 9763700) rejected all rows at
SQL*Loader with `ORA-01722` on the empty-quoted numeric `PLAN_VERSION_NUMBER` (fixed:
bare numeric empties). Prefix 91777 rejected the good rows with
`PJO_BOI_AWARD_NUM_NOT_PROVD` (fixed: stamp AWARD_NUMBER). Prefix 94550 rejected them
with the funding-source message (fixed: stamp FUNDING_SOURCE_NAME). Prefix 95661 is the
clean 2-good / 1-bad pass.

## BIP replica-lag caveat
The read-only BIP replica for these Project tables lags on this pod (observed:
`PJO_PLAN_VERSIONS_B` frozen ~20 min behind loads; `PJO_PLAN_VERSIONS_XFACE` up to
months behind). So the immediate base read right after a load can return 0 even on a
good load. The authoritative, replica-independent proof is the Import Budget Report
above; the direct base read is a confirming secondary that succeeds once the replica
refreshes (it did for prefix 95661: ids 100002547416587 / 100002547416619).

## Files
- `recipe.json` — discovery, CSV member, good/bad rows, ESS job, verify reads
- `artifact/PjoPlanVersionsXface.csv` — templated 3-row CSV (2 good + 1 bad)
- `ProjectBudgets_gold.zip` — last assembled ready-to-load artifact
