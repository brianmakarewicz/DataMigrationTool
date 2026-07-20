# Projects — Gold Regression Fixture (Import Projects)

**Status: LIVE-PROVEN 2026-07-19** — prefix `92666`, load request `9763523`, report request `9763532`.
2/2 good projects reached the base table `PJF_PROJECTS_ALL_VL`
(`92666RT-PRJ-G1` → project_id `300000331530301`, `92666RT-PRJ-G2` → project_id
`300000331530326`); 1 bad project (`92666RT-PRJ-BAD1`, invalid source template)
was rejected by Import Projects with a real error and is absent from the base table.

This fixture loads standalone against any Oracle Fusion demo pod: no DMT database, no
DMT pipeline code in the load path. Every reference (project template, carrying-out
organization, currency, and the two project managers) is discovered live at load time —
nothing is hardcoded and nothing depends on a record we loaded earlier.

## Object shape

Projects is ONE object: a single FBDI zip carrying multiple record-type CSVs, loaded by
one ESS import job. This fixture ships three of the four record types:

| Record type | FBDI CSV member | Columns |
|---|---|---|
| Projects | `PjfProjectsAllXface.csv` | 157 |
| Tasks | `PjfProjElementsXface.csv` | 122 |
| Team Members | `PjfProjectPartiesInt.csv` | 15 |

(The fourth record type, Transaction Controls / `PjcTxnControlsStage.csv`, is intentionally
omitted — it needs an expenditure type and is not required to prove good→base / bad→rejection.)

## ESS orchestration (what actually runs)

The single SOAP call `loadAndImportData` on the ERP Integration service does three things
and returns the **load** request id:

1. Base64-uploads the zip to UCM under the document account `prj/projectFoundation/import`.
2. Runs "Load Interface File for Import" (SQL*Loader) to unpack each CSV into its interface
   table — `PJF_PROJECTS_ALL_XFACE`, `PJF_PROJ_ELEMENTS_XFACE`, `PJF_PROJECT_PARTIES_INT`.
3. Chains the import job **`ImportProjectJobDef`** with the ParameterList below.

`ImportProjectJobDef` then internally submits a further child (`ProjectInterfaceLoadDataService`)
and, on completion, auto-submits **`ImportProjectReportJob`** (the "Import Projects Report").
That report job is the ONLY place the accept/reject detail and per-project error message lives.

Job chain observed on the live proven run (prefix 92666):

```
loadAndImportData  → load request 9763523  (SUCCEEDED)
   └─ ImportProjectJobDef (import)  request 9763529   (per run 3)
        └─ ImportProjectReportJob   request 9763532   ← accept/reject + error text
```

The harness polls the returned **load** request id with `getESSJobStatus` every 60s until a
terminal status. `SUCCEEDED` on the load job means the CSVs loaded and the chained import ran —
it does NOT by itself mean the projects passed Import Projects validation. Positive proof comes
from the base table read (good) and the report XML (bad).

### Web-service call

| Field | Value |
|---|---|
| Endpoint | `<fusion_url>/fscmService/ErpIntegrationService` |
| Operation | `loadAndImportData` |
| Auth user | `fin_impl` (NOT `calvin.roth` — that user gets a 401/role-lack and the import ESS sits in WAIT then expires) |
| DocumentAccount | `prj/projectFoundation/import` |
| JobName | `/oracle/apps/ess/projects/foundation/projectDefinition,ImportProjectJobDef` |
| interfaceDetails | `46` |
| **ParameterList** | `,,Y` |

**ParameterList spelled out — `ImportProjectJobDef` takes 3 positional arguments:**

| Pos | Argument | Value | Meaning |
|---|---|---|---|
| 1 | fromProject | *(empty)* | lower project-number bound — empty = all |
| 2 | toProject | *(empty)* | upper project-number bound — empty = all |
| 3 | reportSuccess | `Y` | include successful projects in the Import Projects Report |

(Confirmed in the report-job log: `Executing import projects job with params fromProject:null,
toProject:null, reportSuccess:Y`. Source of the value: the proven frozen-stack loader,
MCCS RICE_006.)

### Downstream waits

No separate downstream `submitESSJobRequest` is needed. `ImportProjectReportJob` is
auto-submitted by `ImportProjectJobDef`; the good projects are already committed to the base
table by the time the load request reaches `SUCCEEDED`. The base-table read is the pass bar.

## Discovery (portability — nothing hardcoded)

Run at load time via the read-only BIP relay against the TARGET pod (`fin_impl`,
`ApplicationDB_FSCM`). See `recipe.json` for the exact SQL.

| Step | Finds | Tokens stamped | Proven value on demo pod |
|---|---|---|---|
| `PRJ_TEMPLATE` | An existing project **template** whose carrying-out org name and currency are usable. Prefers a template with a short human template number (excludes 8+ digit synthetic ids and "DO NOT USE"); prefers `PRGUS Sponsored`. | `${TEMPLATE_NUM}`, `${ORG_NAME}`, `${CURRENCY}`, `${PROJECT_TYPE}` | `PRGUS Sponsored` / `Maintenance Prg US` / `USD` / `PRGUS Funded with Burden` |
| `PRJ_MANAGER_1` | An existing worker (lowest person number) with an ASCII display name + work email. | `${PM1_NAME}`, `${PM1_EMAIL}` | `Mandy Steward` |
| `PRJ_MANAGER_2` | The second such worker. | `${PM2_NAME}`, `${PM2_EMAIL}` | `Brian LineManager` |

The template's **project type** comes from the template itself (there is no PROJECT_TYPE
column on the FBDI — the type is inherited from the source template). The **organization
name** stamped into the FBDI must equal the template's carrying-out organization, so it is
discovered from the same row.

## Good / bad rows

Both good projects use the discovered template, org, and currency, with a `${PREFIX}`-stamped
project number and name, one task each (dates inside the project dates), and one team member
(a discovered worker as Project Manager).

| Key | Kind | What makes it good/bad |
|---|---|---|
| `${PREFIX}RT-PRJ-G1` | GOOD | Valid discovered template + org + currency; project dates 2025/01/01–2025/12/31; one task, one team member. |
| `${PREFIX}RT-PRJ-G2` | GOOD | Same, second discovered manager. |
| `${PREFIX}RT-PRJ-BAD1` | BAD | `SOURCE_TEMPLATE_NUMBER = ZZ-NO-SUCH-TEMPLATE`. Import Projects rejects it deterministically: **"The source template number isn't valid."** |

**Data-quality lesson (why the first two attempts failed):**
- Attempt 1 (prefix 10947): discovery ordered templates by `segment1` and picked one whose
  template number was a 15-digit synthetic id — Import Projects rejected ALL three rows with
  "source template number isn't valid." Fix: discover a template with a real short template
  number (exclude 8+ digit numeric `segment1`), prefer `PRGUS Sponsored`.
- Attempt 2 (prefix 55958): good projects had NO project start/finish dates but their tasks
  DID have planning dates → tasks rejected → "The project isn't imported because errors exist
  for the project tasks." Fix: stamp `PROJECT_START_DATE` (col 12) and `PROJECT_FINISH_DATE`
  (col 13) on every project row so the task planning dates fall inside the project window.
- Attempt 3 (prefix 92666): PASS — 2 accepted, 1 rejected.

## Verification (read-only, direct single-table reads)

Both directions are proven with independent single-table reads through the BIP relay — never
a multi-table join.

**GOOD → base table.** `PJF_PROJECTS_ALL_VL` filtered by the run prefix on the natural key:

```sql
SELECT segment1 AS PROJECT_NUMBER, project_id AS PROJECT_ID, name AS PROJECT_NAME
FROM   pjf_projects_all_vl
WHERE  segment1 LIKE :PREFIX || 'RT-PRJ-%';
```

A row present with a real `PROJECT_ID` = pass.

**BAD → interface + absent from base.** The interface table `PJF_PROJECTS_ALL_XFACE` has no
error-message column (only `IMPORT_STATUS` / `LOAD_STATUS`) and its rows are purged after the
import completes, so the harness's interface read reports the rejected row's status while it is
still present:

```sql
SELECT project_number AS PROJECT_NUMBER,
       'IMPORT_STATUS=' || NVL(import_status,'(null)') ||
       ' LOAD_STATUS='  || NVL(load_status,'(null)')  AS ERROR_MESSAGE
FROM   pjf_projects_all_xface
WHERE  load_request_id = :LRID;
```

Rejected row → `IMPORT_STATUS=FAILURE LOAD_STATUS=COMPLETE`, and absent from
`PJF_PROJECTS_ALL_VL`.

**The authoritative bad-row error message** ("The source template number isn't valid.") lives
ONLY in the ImportProjectReportJob output, `ESS_O_<reportReqId>_BIP.xml`, downloadable via the
`downloadESSJobExecutionDetails` SOAP operation (returns an MTOM multipart carrying a zip with
`<reportReqId>.log` + `ESS_O_<reportReqId>_BIP.xml`). Parse `<PROJECT_ERROR>` /
`<PROJECT_ERR_MSG>` for errors and `<PROJECT_SUCCESS>` / `<SUCCESS_PROJECT_NUMBER>` for
accepts. This is documented here for evidence; the pass/fail decision uses the base-table read.

## Live-proven evidence (2026-07-19)

- Prefix: **92666**
- Load request id: **9763523** (terminal `SUCCEEDED`)
- Import Projects Report request id: **9763532**
- Report tallies: `PROJECT_ACCEPTED = 2`, `PROJECT_REJECTED = 1`, `TASK_ACCEPTED = 2`, `TASK_REJECTED = 0`
- Good in base (`PJF_PROJECTS_ALL_VL`):
  - `92666RT-PRJ-G1` → project_id `300000331530301`
  - `92666RT-PRJ-G2` → project_id `300000331530326`
- Bad rejected (report XML): `92666RT-PRJ-BAD1` :: "The source template number isn't valid."
- Bad absent from base: confirmed.

## How to re-run

```bash
cd gold_regression/harness
python run_object.py Projects            # fresh random prefix, full discover→build→load→verify
python run_object.py Projects --prefix 92670
```

Exit code 0 and `"pass": true` when 2 good projects reach `PJF_PROJECTS_ALL_VL` and the bad
row is rejected + absent.
