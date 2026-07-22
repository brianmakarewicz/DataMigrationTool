# Run 235 — Projects bad row (10116RTPRJ-BAD1) left UNACCOUNTED

**Read-only investigation. No code changed, no pipeline run, no reconcile.**
Date: 2026-07-22. Instance: local Docker `dmt2-local` (dmt_owner @ //localhost:1523/FREEPDB1);
live Fusion reads via `scripts/fusion_bip_query.py` (fin_impl) and direct
`downloadESSJobExecutionDetails` SOAP.

## Verdict

**Hypothesis A is correct. Hypothesis B is ruled out.**

The Import Projects Report job **did** spawn in Fusion (request **9774577**, state 12 SUCCEEDED)
and its output XML **does** contain the bad row's rejection. DMT never captured that report job,
so the reconciler had no report to read and left the bad row unaccounted. The CSV / bad-row
design is fine — the bad row was rejected cleanly by Fusion with the good rows accepted.

## What actually happened in run 235

- Run 235, prefix `10116`, object Projects, path = queue pipeline (`DMT_QUEUE_WORKER_PKG.RECONCILE_ONE`).
- Load ESS `9774570` (InterfaceLoaderController) → import ESS `9774576` (`ImportProjectJobDef`).
- Fusion auto-submitted the report job **`9774577` (`ImportProjectReportJob`)**, SUCCEEDED.
- Good rows reached the base table: `10116RTPRJ001` → project_id `300000331575395`,
  `10116RTPRJ002` → `300000331575420`.
- Bad row `10116RTPRJ-BAD1` was rejected by Fusion — real error, in the report XML:
  **"The project status isn't valid. Enter a valid project status, load the data, and resubmit
  the import process."** (its FBDI PROJECT_STATUS was the bogus `ZZ_BOGUS_STATUS`.)
- DMT marked the two good rows LOADED and left `10116RTPRJ-BAD1` at TFM_STATUS = `UNACCOUNTED`.
  The accounting gate then reported `Object Projects FAILED: 2 record(s) unaccounted`.

## Evidence — the report request tree in live Fusion

Query of `fusion.ess_request_history` (fin_impl):

| requestid | parentrequestid | absparentid | definition | state |
|---|---|---|---|---|
| 9774576 | 0 | 9774576 | .../projectDefinition/ImportProjectJobDef | 12 |
| 9774577 | 0 | 9774577 | .../projectDefinition/ImportProjectReportJob | 12 |

The report job **9774577 is NOT a child of 9774576 by any parent field** — Fusion leaves it
orphaned (`parentrequestid = 0`, `absparentid = itself`). Its only relationship to the import
is that its id is `import_id + 1`.

Note: BillingEvents' report job `9774610` is orphaned in Fusion the exact same way
(`parentrequestid = 0`, `absparentid = 9774610`), yet DMT captured it fine. So orphan-linkage
alone is not the blocker — the child-job BIP data model's `requestid > P_LOAD_ESS_ID` fallback
finds it. The real difference is **whether the capture routine runs at all** (below).

## Where the bad-row detail actually lives (import job vs report job output)

`downloadESSJobExecutionDetails` for each request (fin_impl):

- **9774576 (import) output ZIP** contains only `9774576.log`. **No `.xml` file at all.**
- **9774577 (report) output ZIP** contains `9774577.log` **and `ESS_O_9774577_BIP.xml` (14.7 KB)** —
  the per-project accept/reject report. Inside it:
  ```
  <LIST_PROJECT_ERROR><PROJECT_ERROR>
    <ERROR_PROJECT_NUMBER>10116RTPRJ-BAD1</ERROR_PROJECT_NUMBER>
    <PROJECT_ERR_MSG>The project status isn't valid. ...</PROJECT_ERR_MSG>
  </PROJECT_ERROR></LIST_PROJECT_ERROR>
  ```
  (Good rows appear under `LIST_PROJECT_SUCCESS`.)

`DMT_ESS_UTIL_PKG.GET_ESS_OUTPUT_XML` extracts the first `%.xml` entry from a job's output ZIP.
Fed request 9774576 it returns NULL (there is no xml); fed 9774577 it returns the report. This
matches the gold README's statement: *"The authoritative bad-row error message lives ONLY in the
ImportProjectReportJob output, `ESS_O_<reportReqId>_BIP.xml`."*

## Why the interface-table reconcile path also can't see the bad row

Run 235's Projects BIP reconcile ran the correct DM (`/Custom/DMT2/Projects/PROJECT_DM.xdm`)
keyed on `load_request_id = P_LOAD_REQUEST_ID = 9774570`. But live `pjf_projects_all_xface` has
**zero rows** for load_request_id 9774570 / prefix 10116 — Fusion **purges the interface rows
after import completes**. So the interface tier returns nothing; only the base tier returns the
two good rows (→ LOADED). The bad row is recoverable **only** from the report job XML. The gold
fixture avoids this because its harness reads the interface table *immediately* after import,
before the purge; DMT reconciles later, after the purge.

## Root cause (file : line)

Run 235 reconciled Projects through the queue-worker path, whose relevant packages are the
**live deployed** bodies (ahead of some committed files — see "Committed-vs-deployed drift" below).

1. `DMT_QUEUE_WORKER_PKG.RECONCILE_ONE` (live body) — the reconcile entry point for a queued
   object. It calls `DMT_IMPORT_REPORT_PKG.PARSE_AND_LOG_ERRORS(p_request_id => IMPORT_ESS_JOB_ID)`
   (live line ~632, request 9774576 — empty, no xml) and then the registered RECON_PROC
   `DMT_PROJECT_RESULTS_PKG.RECONCILE_BATCH` (live line ~653). **It never calls
   `DMT_ESS_UTIL_PKG.CAPTURE_REPORT_ESS_JOB`** — grep of the whole package body: 0 hits. So the
   report child 9774577 is never inserted into `DMT_ESS_JOB_TBL` on this path.

2. `DMT_PROJECT_RESULTS_PKG` (live body):
   - `apply_import_report` correctly reads the report from the child job via
     `GET_ESS_OUTPUT_XML(l_report_id)` (live line ~220) — this part was already fixed to read
     the report job, not the wrapper.
   - But it obtains `l_report_id` from `resolve_report_ess_id` (live lines 138-164), which only
     **SELECTs** an already-captured child from `DMT_ESS_JOB_TBL`
     (`WHERE PARENT_REQUEST_ID = p_import_ess_id AND job name LIKE '%IMPORTPROJECTREPORTJOB%'`).
     It **does not call `CAPTURE_REPORT_ESS_JOB` first**. With no capture upstream, the SELECT
     finds nothing, returns NULL, and `apply_import_report` logs
     *"No ImportProjectReportJob child captured for import ESS 9774576 … rows left unaccounted"*
     (live line 203) and returns having matched nothing. Bad row stays GENERATED → UNACCOUNTED.

**Why BillingEvents works and Projects doesn't (same `RECONCILE_ONE` path):**
`DMT_BILLING_EVENT_RESULTS_PKG` captures the report child **lazily inside its own reconcile**
(`PARSE_AND_UPDATE` calls `CAPTURE_REPORT_ESS_JOB` for import 9774602, then `find_report_ess_id`
resolves the freshly-captured 9774610 — confirmed in run 235 logs, log_ids 100233796 / 100233805).
The Projects results package has a *read-only* resolver (`resolve_report_ess_id`) with no
capture, so it always gets NULL. This is the exact per-object inconsistency: BillingEvents'
reconciler self-captures; Projects' reconciler assumes something upstream already captured, and
on the queue path nothing does.

## Precise fix

Make the Projects reconciler capture-then-read, mirroring BillingEvents. In
`DMT_PROJECT_RESULTS_PKG` (live body), change `resolve_report_ess_id` (or its single caller
`apply_import_report`, ~line 198) so it **captures before it resolves**:

```plsql
-- Ensure the report child is captured before we try to read it (the queue
-- reconcile path does not capture upstream, unlike DMT_LOADER_PKG).
l_report_id := DMT_ESS_UTIL_PKG.CAPTURE_REPORT_ESS_JOB(
                   p_run_id        => p_run_id,
                   p_import_ess_id => p_import_ess_id,
                   p_cemli_code    => 'Projects');   -- inserts 9774577 as child, returns its id
IF l_report_id IS NULL THEN
    l_report_id := resolve_report_ess_id(p_run_id, p_import_ess_id);  -- fallback if already captured
END IF;
```

`CAPTURE_REPORT_ESS_JOB` is idempotent (DUP_VAL_ON_INDEX → NULL) and already returns the report
request id, so it can replace the read-only resolve. Its live report path is correct
(`/Custom/DMT2/common/DMT_ESS_CHILD_JOB_RPT.xdo`), and its child-job DM (`DMT_ESS_CHILD_JOB_DM.xdm`)
`requestid > P_LOAD_ESS_ID` fallback was verified against live Fusion to return **9774577** for
P_LOAD_ESS_ID = 9774576.

**Equivalent alternative (broader):** add the `CAPTURE_REPORT_ESS_JOB` call once in
`DMT_QUEUE_WORKER_PKG.RECONCILE_ONE`, right after `PARSE_AND_LOG_ERRORS` (~live line 638), guarded
by `IMPORT_ESS_JOB_ID IS NOT NULL`. That captures the report child for every object on the queue
path (generic — returns NULL for objects with no `REPORT_JOB_DEF`), and lets every results
package's resolver find it. This removes the per-object "who captures?" inconsistency entirely
and is the cleaner fix; the Projects-package fix above is the minimal one.

## Hypothesis B — ruled out (CSV / bad-row design is fine)

- Run 235's bad row was rejected cleanly by Import Projects with a real per-project error
  ("The project status isn't valid.") while both good rows were accepted and reached the base
  table. Fusion produced a normal `ESS_O_9774577_BIP.xml` with the good rows under
  `LIST_PROJECT_SUCCESS` and the bad row under `LIST_PROJECT_ERROR`. No all-rows-rejected mode,
  no missing report.
- The bad-row defect differing from gold (invalid PROJECT_STATUS here vs invalid
  SOURCE_TEMPLATE_NUMBER in gold) does not change the outcome: both produce a single-row
  rejection in the same report structure. The failure is purely that DMT never reads that report.
- `DMT_IMPORT_REPORT_PKG.PARSE_ERRORS` already understands this XML shape (it walks any
  `LIST_*_ERROR` group, derives `error_source` from the tag, and reads the identifier +
  `PROJECT_ERR_MSG`). Once the report XML reaches it, `10116RTPRJ-BAD1` will match a
  `DMT_PJF_PROJECTS_TFM_TBL` row on `PROJECT_NUMBER` and flip it to FAILED with the real message.

## Secondary note (not the cause; worth logging)

The Projects reconcile DM `PROJECT_DM.xdm` selects `ERROR_MESSAGE` as a constant NULL from the
interface tier, so even when interface rows *are* present pre-purge, a FAILED row carries only
`Interface status: <status>` and never the Fusion error text. The authoritative message only ever
arrives via the report-job path fixed above. Not blocking, but the FAILED error text stays generic
until the report path is wired in.

## Key request ids / paths (for reference)

- Run 235 Projects: load `9774570`, import `9774576`, **report `9774577`** (state 12), prefix `10116`.
- Report XML: `ESS_O_9774577_BIP.xml` in job 9774577's `downloadESSJobExecutionDetails` output.
- Capture routine: `DMT_ESS_UTIL_PKG.CAPTURE_REPORT_ESS_JOB` (committed
  `db/packages/dmt_ess_util_pkg.pkb.sql` line 1056; report path constant committed line 1062 still
  says `/Custom/DMT/` but the **deployed** body says `/Custom/DMT2/` — a committed-vs-deployed drift).
- Child-job DM: `bip/common/DMT_ESS_CHILD_JOB_DM.xdm` (verified returns 9774577 live).
- Missing-capture site: `DMT_QUEUE_WORKER_PKG.RECONCILE_ONE` (0 capture calls).
- Read-only resolver with no capture: `DMT_PROJECT_RESULTS_PKG.resolve_report_ess_id`
  (deployed lines 138-164) called from `apply_import_report` (deployed line 198).

### Committed-vs-deployed drift (flag for the owner)
The deployed bodies of `DMT_PROJECT_RESULTS_PKG`, `DMT_LOADER_PKG`, and `DMT_ESS_UTIL_PKG` are
AHEAD of the committed files in the repo (e.g. deployed `resolve_report_ess_id` /
`apply_import_report` and the `/Custom/DMT2/` report path do not exist in the committed
`dmt_project_results_pkg.pkb.sql` / `dmt_ess_util_pkg.pkb.sql`). The fix must be written against —
and committed from — the current deployed source, and the git-first rule means the committed files
need reconciling with the deployed bodies as part of landing it.
