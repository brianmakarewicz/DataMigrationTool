# Run 238 — Projects report-capture fix — end-to-end validation evidence

Recorded from the live DB query observed during the session (2026-07-22). This is the
end-to-end proof for PR #229 (Projects: capture the report child during reconcile + fix
report-parse ORA-30625 + composite-id match). It supersedes the earlier "validation in
progress" note on the PR (which was at run 237 / prefix 10118).

## Setup
- Scenario RegressionTest6, PROJECTS pipeline, ALL mode. Run **238**, prefix **10119**.
- The three fixes from PR #229 were deployed to dmt2-local before the run:
  1. `resolve_report_ess_id` now CALLS `DMT_ESS_UTIL_PKG.CAPTURE_REPORT_ESS_JOB` when the
     child report is not already captured (was read-only).
  2. `DMT_IMPORT_REPORT_PKG.PARSE_ERRORS` null-guards empty XML elements (was ORA-30625).
  3. `apply_import_report` matches the composite `name/number` identifier via a
     `/`-delimited token.

## Observed result (query on DMT_PJF_PROJECTS_TFM_TBL, run_id 238)

```
10119RTPRJ-BAD1  → FAILED  :: [IMPORT_REPORT] The project status isn't valid. Enter a valid project status, load the data, and resubmit...
10119RTPRJ001    → LOADED
10119RTPRJ002    → LOADED
```

## Interpretation
- The intended BAD project (`10119RTPRJ-BAD1`, injected invalid `PROJECT_STATUS_NAME`)
  reaches **FAILED with its real Fusion error**, sourced from the child
  `ImportProjectReportJob` report — no longer left `[UNACCOUNTED]`.
- The two GOOD projects reach the base table (**LOADED**).
- **Zero unaccounted** for Projects. Good → base, bad → failed-with-real-error: the mission
  satisfied for this object.

## Corroborating earlier evidence (committed)
- Run 237 proved the capture step alone: log line
  `CAPTURE_REPORT_ESS_JOB complete. Report ESS: 9774810 captured as child of import ESS 9774809`.
- Unit test on the real report XML 9774810: `PARSE OK, count=1 | id=.../10118RTPRJ-BAD1/ |
  msg=The project status isn't valid...` (previously threw ORA-30625).
- Root-cause analysis: `run235_projects_report_capture.md`.

## Caveat
The run-238 rows were observed live in the DB during the session; this file is the recorded
transcript of that observation. It was not independently re-queried after the DB host-port
forwarding wedged at session end (see status.md blocker). Re-confirm on the next full
regression run once host connectivity is restored.
