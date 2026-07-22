# Run 234 (prefix 10115) — Projects: real Fusion outcome for the 2 UNACCOUNTED records

**Investigation type:** read-only. No code changed, no pipeline re-run, no reconciliation re-run.
**Date:** 2026-07-21
**Work queue:** `run_id=234`, `cemli_code='Projects'`, `work_status=FAILED` —
"2 record(s) unaccounted (8 loaded, 0 errored)."
**Load ESS job:** 9773544 · **Import ESS job:** 9773553 · **Import report job:** 9773554 (the real per-row report).

## Summary counts

| Outcome | Count | Records |
|---|---|---|
| LOADED (in Fusion base table) | 0 (of the 2 in question) | — |
| FAILED with a real Fusion message | 1 | 10115RT Project Bad-1 |
| Genuinely absent from Fusion (silently dropped, no error surfaced) | 1 | Orphan Task |

The owner's claim ("none should be genuinely nowhere") is **half right**. One record has a real,
reportable Fusion rejection that DMT simply failed to read. The other is genuinely nowhere in
Fusion — Fusion accepted the file, silently dropped the task, and never emitted an error for it.

## Root cause of the "unaccounted" status — DMT read the wrong ESS job

Fusion's **Import Projects** job (9773553) is only an async submit wrapper. It spawns a **separate
report job (9773554 = `ImportProjectReportJob`)** that holds the actual per-row accept/reject
report. DMT's reconciliation downloaded the report from the wrapper job 9773553, which returns an
essentially empty XML (4 bytes). The real report — with the Bad-1 rejection message plainly in it —
lives in 9773554. Because DMT read the empty wrapper, it found "0 errored" and could not account
for either row. This is a reconciliation wiring gap, not a data problem for Bad-1.

Evidence: `GET_ESS_OUTPUT_XML(9773553)` returns length 4; `GET_ESS_OUTPUT_XML(9773554)` returns a
14,718-byte Projects import report. The wrapper's own log (job 9773553 text output) prints:
`Import Projects Report Submitted Request. requestId = 9773554`.

---

## Per-record findings

### 1. "10115RT Project Bad-1" (project header, TFM seq 363, number `10115RTPRJ-BAD1`)

`10115RT Project Bad-1 | OUTCOME: FAILED — real Fusion message: "The project status isn't valid. Enter a valid project status, load the data, and resubmit the import process." (source: Import Projects report, ESS job 9773554, LIST_PROJECT_ERROR/PROJECT_ERR_MSG, PROJECT_ERROR_LINE 1)`

- Injected defect: `PROJECT_STATUS_NAME = ZZ_BOGUS_STATUS` (a non-existent project status). The TFM
  row's own DESCRIPTION says "BAD: invalid project status (Fusion rejects the lookup)".
- Fusion report summary: `PROJECT_ACCEPTED=2, PROJECT_REJECTED=1, PROJECT_ERROR_FOUND=Y`. The one
  rejected project is Bad-1, keyed by `ERROR_PROJECT_NUMBER=10115RTPRJ-BAD1`.
- Base-table check (read-only BIP, fin_impl): `PJF_PROJECTS_ALL_VL` where segment1/name LIKE
  '10115RT%' returns ONLY the two good projects (`10115RTPRJ001` id 300000331575180,
  `10115RTPRJ002` id 300000331575205). No `10115RTPRJ-BAD1` row — correct, it was rejected.
- **This record is a clean, correctly-rejected bad row.** The only failure is that DMT never
  surfaced the message, because it read the wrong ESS job (see root cause above).

### 2. "Orphan Task" (project task, TFM seq 363, number `NOPROJ999.1`, parent project `10115NOPROJ999`)

`Orphan Task | OUTCOME: GENUINELY-ABSENT — not in the Fusion base table (PJF_PROJ_ELEMENTS_B) and not in the Fusion import report at all: not as a success, not as an error. Fusion silently dropped it because its parent project 10115NOPROJ999 does not exist in the load. No Fusion error message was ever produced for this row.`

What was checked:
- **FBDI generation:** the orphan task WAS generated and sent — `PjfProjElementsXface.csv` for run
  234 contains `NOPROJ999`. So this is not a generation gap; Fusion did receive the row.
- **Fusion import report (job 9773554):** `TASK_ACCEPTED=2, TASK_REJECTED=0, TASK_ERROR_FOUND=N`.
  The report's task successes are only `RTPRJ001.1` / `RTPRJ002.1`. The strings `NOPROJ999` and
  `Orphan` appear **0 times** anywhere in the report XML. Fusion neither accepted nor rejected it —
  it dropped it without comment.
- **Base table (read-only BIP, fin_impl):** `PJF_PROJ_ELEMENTS_B` for the two run-234 projects
  (300000331575180 / 300000331575205) shows each project's own root element plus one task
  (`RTPRJ001.1` eid 100002550114375, `RTPRJ002.1` eid 100002550114415). A scan for
  `element_number LIKE 'NOPROJ999%'` returns nothing. The orphan is truly not in Fusion.
- Why: an FBDI task line whose parent project isn't part of the projects file has no header to
  attach to. Import Projects processes tasks per accepted project; a task pointing at a
  non-loaded/non-existent project (`10115NOPROJ999`) is never processed and never reported.

**Note on task IDs:** even the two GOOD tasks show `fusion_task_id = NULL` in
`DMT_PJF_TASKS_TFM_TBL` for run 234, though they are confirmed loaded in `PJF_PROJ_ELEMENTS_B`.
DMT is not capturing element IDs back for tasks. Separate from the unaccounted issue, but worth
noting for task-level reconciliation.

---

## Fix roadmap (no code changed here — recommendations only)

1. **Read the report job, not the wrapper (highest priority).** Projects reconciliation must resolve
   the child `ImportProjectReportJob` request id (printed in the wrapper's log as
   "Import Projects Report Submitted Request. requestId = N", or discoverable as the ESS child of
   9773553) and download the report XML from THAT job. Reading 9773553 will always yield an empty
   report and therefore always leave every row unaccounted. This single fix turns Bad-1 from
   UNACCOUNTED into a properly reported FAILED with the real "project status isn't valid" message.

2. **Account for silently-dropped tasks.** A task whose parent project is not in the accepted set
   will never appear in the Fusion report at all. Reconciliation should treat "task generated and
   loaded, but neither in task-success nor task-error, and its parent project is absent/rejected"
   as a DMT-derived FAILED with an explicit message such as: "Task NOPROJ999.1 references project
   10115NOPROJ999, which was not loaded (parent project not found); Fusion dropped the task without
   a report row." That message is inferred by DMT from the report + FBDI, since Fusion itself gives
   no per-row error for orphaned tasks.

3. **Capture task element IDs on success** (secondary). Good tasks load but `fusion_task_id` stays
   NULL; the element ids exist in `PJF_PROJ_ELEMENTS_B` (e.g. 100002550114375). Reconcile task
   successes back by element_number under the loaded project_id.

## Exact locations of the evidence

- Work queue row: `DMT_WORK_QUEUE_TBL` run_id=234 cemli_code='Projects' (load 9773544, import 9773553).
- Bad-1 TFM row: `DMT_PJF_PROJECTS_TFM_TBL` tfm_sequence_id=363, status ZZ_BOGUS_STATUS.
- Orphan TFM row: `DMT_PJF_TASKS_TFM_TBL` tfm_sequence_id=363, task_number NOPROJ999.1, project_number 10115NOPROJ999.
- Real report: ESS job 9773554, `DMT_ESS_UTIL_PKG.GET_ESS_OUTPUT_XML(9773554)` — Projects import
  report, `LIST_PROJECT_ERROR/PROJECT_ERR_MSG` carries the Bad-1 message.
- Base tables (read-only BIP via `scripts/fusion_bip_query.py --cred fin_impl`):
  `PJF_PROJECTS_ALL_VL` (segment1/name), `PJF_PROJ_ELEMENTS_B` (element_number, project_id, proj_element_id).
