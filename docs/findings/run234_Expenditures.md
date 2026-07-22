# Run 234 (prefix 10115) — Expenditures — READ-ONLY Fusion Investigation

Investigation date: 2026-07-21. No code changed, no pipeline/reconcile re-run.
Object: `Expenditures` (pipeline PROJECTS, queue_id 1426), DEPENDS_ON `Projects`.

## Summary counts

- **Definitively found in Fusion: 6 of 6.** All six records are physically present in the
  Fusion PJC interface/staging table `PJC_TXN_XFACE_STAGE_ALL` with
  `TRANSACTION_STATUS_CODE = 'P'` (Pending — staged, NOT costed), keyed by
  `LOAD_REQUEST_ID = 9773838` (the InterfaceLoaderController request DMT recorded for
  Expenditures this run).
- **Reached base table (`PJC_EXP_ITEMS_ALL`, real success): 0 of 6.** Live query on
  `ORIG_TRANSACTION_REFERENCE LIKE '10115RT-EXP%'` returns zero rows.
- **Genuinely nowhere: 0 of 6.** The owner's claim holds — none are absent from Fusion.
- **Real per-row Fusion error already materialized (a rejected/error status row): 0 of 6.**
  The costing job that produces per-row rejects (`ImportAndProcessTxnsJob`, ESS
  request 9773867 / ess_job_id 8114) **ended in ERROR at the job level** before writing
  per-row rejection codes, so all six rows are frozen at status `'P'` Pending. There is a
  clear *intended* per-row reason for the two BAD rows (invalid expenditure type — see below),
  but Fusion never stamped it onto the staging rows because the costing job aborted.

Net: the records are in Fusion (interface tier), not yet posted, and not yet individually
rejected. DMT marked them UNACCOUNTED because the reconciler's BIP report returned them to
zero rows (see root cause) and the import-report fallback found nothing parseable.

## Why DMT shows UNACCOUNTED (reconciler-side gap, NOT a Fusion mystery)

Local DB evidence (`dmt_owner@localhost:1523/FREEPDB1`, read-only):

1. `dmt_work_queue_tbl` run 234 `Expenditures`: WORK_STATUS FAILED, **all three ESS job-id
   columns NULL**, error "6 record(s) unaccounted ... (0 loaded, 0 errored)". The NULL job
   ids are misleading — the real ids live in `dmt_ess_job_tbl`.
2. `dmt_ess_job_tbl` run 234 `Expenditures` shows the pipeline **did fully run**:
   - InterfaceLoaderController req **9773838** → SUCCEEDED (staged the 6 rows)
   - InterfaceLoaderAsyncJob 9773841 / InterfaceLoaderSqlldrImport 9773843 → SUCCEEDED
   - **ImportAndProcessTxnsJob req 9773867 (ess_job_id 8114) → ERROR** (the onestop costing
     job; STATE 10 / ERROR; only a `9773867.log` file exists in `dmt_ess_job_file_tbl`, no
     Import-Cost report XML).
3. `dmt_log_tbl` run 234 (package DMT_EXPENDITURE_RESULTS_PKG) — two reconcile passes:
   - Pass 1 @22:05:42 with the CORRECT ids (`load_ess_id: 9773838 | import_ess_id: 9773867`).
     `FETCH_BIP_RESULTS` ran report `/Custom/DMT2/Expenditures/EXPENDITURE_RPT.xdo`, got
     "Response bytes: 3445", but `PARSE_AND_UPDATE` then logged **"6 rows still GENERATED
     after BIP"** — i.e. the BIP XML yielded **0 rows** to the XMLTABLE loop even though the
     tier-1 SQL (`WHERE load_request_id = :P_BATCH_ID`) matches all 6 live. The Import-Report
     fallback then called `GET_ESS_OUTPUT_XML(9773867)` and matched 0 (job 8114 has only a
     LOG, and `DMT_IMPORT_REPORT_PKG.PARSE_ERRORS` has no PJC/Expenditure tag handling — it
     only knows LIST_PROJECT_ERROR / AP / PO shapes). Result: LOADED 0, FAILED 0.
   - Pass 2 @22:10:07 (dispatch_reconcile path) ran again with **`load_ess_id:` blank /
     `import_ess_id: NULL`** — lost the ids entirely, fetched 941 bytes (0 rows), did nothing.

   Note the results package's INTERFACE branch *would* have marked all 6 FAILED
   ("In interface but not created in base (status P) — import did not post it") **if** the BIP
   XML had returned the tier-1 rows. It didn't, so nothing was marked. That is the whole bug.

I independently reran the reconciler's tier-1 SQL live against Fusion — it returns all 6 rows
for `load_request_id = 9773838`. So the raw data is reconcilable; the deployed
`EXPENDITURE_RPT.xdo` did not surface it to DMT this run (either `:P_BATCH_ID` was not bound
with 9773838 at report time, or the deployed report's data model / element tags diverge from
`bip/Expenditures/query.sql`).

## Data-quality context (independent of the reconcile bug)

All six TFM rows (`dmt_pjc_expenditures_tfm_tbl`, run 234) have `PROJECT_ID`, `TASK_ID` and
`EXPENDITURE_TYPE_ID` = NULL, and reference `PROJECT_NUMBER = 10115PCS10037`, `TASK_NUMBER 5.2`.
The projects that actually LOADED this run are `10115RTPRJ001` (fusion id 300000331575180) and
`10115RTPRJ002` (300000331575205) — a **different project number** than the expenditures point
at. Live Fusion confirms `Airfare` is a valid expenditure type and `ZZ-BAD-EXPTYPE-99` does
not exist. So even after the reconcile bug is fixed, these rows would ultimately fail costing
on project/task resolution and (for the two BAD rows) invalid expenditure type — but that is a
*post-costing* verdict Fusion has not yet issued, because the costing job errored out.

## Per-record outcomes

- `10115RT-EXP-BAD1` | OUTCOME: **STAGED-NOT-COSTED** in `PJC_TXN_XFACE_STAGE_ALL`
  (TRANSACTION_STATUS_CODE='P', LOAD_REQUEST_ID=9773838). NOT in `PJC_EXP_ITEMS_ALL`.
  Intended reject: invalid expenditure type `ZZ-BAD-EXPTYPE-99` (confirmed non-existent in
  `PJF_EXP_TYPES_TL`). Fusion has not stamped a per-row error — costing job 9773867 ERRORed.
- `10115RT-EXP-LAB-BAD1` | OUTCOME: **STAGED-NOT-COSTED** (status 'P', LOAD_REQUEST_ID=9773838).
  Not in base. Same intended reject: expenditure type `ZZ-BAD-EXPTYPE-99` invalid.
- `10115RT-EXP-LAB-RTPRJ001` | OUTCOME: **STAGED-NOT-COSTED** (status 'P', LOAD_REQUEST_ID=9773838).
  Not in base. Type `Airfare` (valid); would still fail on unresolved project 10115PCS10037.
- `10115RT-EXP-LAB-RTPRJ002` | OUTCOME: **STAGED-NOT-COSTED** (status 'P', LOAD_REQUEST_ID=9773838).
  Not in base. Type `Airfare` (valid); unresolved project 10115PCS10037.
- `10115RT-EXP-RTPRJ001` | OUTCOME: **STAGED-NOT-COSTED** (status 'P', LOAD_REQUEST_ID=9773838).
  Not in base. Type `Airfare` (valid); unresolved project 10115PCS10037.
- `10115RT-EXP-RTPRJ002` | OUTCOME: **STAGED-NOT-COSTED** (status 'P', LOAD_REQUEST_ID=9773838).
  Not in base. Type `Airfare` (valid); unresolved project 10115PCS10037.

(None are LOADED; none are GENUINELY-ABSENT. What I checked for each: base table
`PJC_EXP_ITEMS_ALL` by ORIG_TRANSACTION_REFERENCE = 0 rows; staging `PJC_TXN_XFACE_STAGE_ALL`
by ORIG_TRANSACTION_REFERENCE and by LOAD_REQUEST_ID = 9773838 = present, status 'P'.)

## Fix roadmap — where the reconciler should look to surface these

1. **Trust the interface tier (primary fix).** The tier-1 join is correct:
   `PJC_TXN_XFACE_STAGE_ALL.LOAD_REQUEST_ID = <load ess request>` (9773838 here),
   join key back to DMT on `ORIG_TRANSACTION_REFERENCE`. A row present in staging and absent
   from `PJC_EXP_ITEMS_ALL` with status `'P'` after a **failed/ERROR costing job** is a real
   Fusion FAILED — the results package already contains exactly this logic
   (`DMT_EXPENDITURE_RESULTS_PKG.PARSE_AND_UPDATE`, INTERFACE branch). The break is that the
   deployed `EXPENDITURE_RPT.xdo` returned 0 rows to XMLTABLE; fix the BIP report so tier-1
   actually delivers the staged rows (verify the `:P_BATCH_ID` bind = load ess request id and
   that the report's output element tags match the XMLTABLE PATHs in the results package).
   IMPORTANT: the report SQL comment currently claims `'P' = Processed (success)` — that is
   **wrong**; `'P'` in `PJC_TXN_XFACE_STAGE_ALL` is Pending/uncosted. Only a `PJC_EXP_ITEMS_ALL`
   row (tier 2, join `REQUEST_ID = <import ess request>`) proves success.

2. **Gate on the costing job state.** `ImportAndProcessTxnsJob` (import_ess request 9773867,
   ess_job_id 8114) is in ERROR in `dmt_ess_job_tbl` (STATE 10). When the onestop costing job
   is ERROR/WARNING, every staged-'P' row for that batch is a FAILED, and its ESS log/output
   (request 9773867) is the reportable Fusion message. Surface the job-level ERROR as the
   per-row error when no finer per-row reject exists.

3. **Per-row reject detail, when costing DOES run.** For invalid-expenditure-type rows the
   real Fusion message is the PJC import-cost rejection (invalid expenditure type, class
   `PJC_EXP_TYPE_INVALID`). That detail comes from the ImportAndProcessTxnsJob output report;
   `DMT_IMPORT_REPORT_PKG.PARSE_ERRORS` has **no PJC/Expenditure XML shape** today (only
   Project/AP/PO), so even a downloaded report would parse to 0 — add a PJC expenditure error
   shape. Download path is `DMT_ESS_UTIL_PKG.GET_ESS_OUTPUT_XML(<import request>)` →
   `downloadESSJobExecutionDetails`.

4. **Fix the second reconcile pass losing the ids.** The dispatch_reconcile pass ran with
   `import_ess_id NULL` / blank load id and clobbered nothing but proves the id-handoff is
   fragile. The import/load ess ids must be persisted (they exist in `dmt_ess_job_tbl` keyed by
   `RUN_ID + CEMLI_CODE + JOB_SHORT_NAME`) and passed to every reconcile pass; the
   `dmt_work_queue_tbl.load_ess_job_id / import_ess_job_id` columns are NULL for this row and
   should be populated so the fallback (`GET_ESS_OUTPUT_XML(import_ess_id)`) can run.
