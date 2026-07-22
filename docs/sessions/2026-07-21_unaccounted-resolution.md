# Session log — 2026-07-21/22 — Resolve run-234 UNACCOUNTED honestly

## Goal
Take the first honest scorecard (run 234, RegressionTest6) — 61 LOADED, 49 FAILED with real
`[FUSION_ERROR]`, **23 UNACCOUNTED** — and drive UNACCOUNTED down by FINDING each record's real
Fusion outcome, never by inventing one. Mission reaffirmed mid-session and written into the
project CLAUDE.md: the tool RUNS the processes and REPORTS row-level success/failure; it does
not "fix" bad rows.

## What we found (all 23 records located in Fusion — read-only investigation)
Seven per-object hunts (fusion_bip_query + ESS log/report downloads) found a real outcome for
every record. Findings under `docs/findings/run234_*`. Summary:

| Object | Real Fusion outcome | Why DMT said UNACCOUNTED |
|---|---|---|
| ARInvoices (3) | AutoInvoice import **ERRORed** twice (req 9773727/9773803) — consolidated-billing + reference-set | reconciler never read the errored import job's log |
| Expenditures (6) | Costing job `ImportAndProcessTxnsJob` **ERRORed** (ORA-01008, job level) | BIP report returned 0 rows; job-ERROR never gated |
| Requisitions (5) | All 5 rejected in `POR_REQ_IMPORT_ERRORS` (real messages) | error text written but status never flipped to FAILED; no child→header cascade |
| Grants (3) | All 3 in the **Award Batch Import Report** (real messages) | reads purged interface tables, not the surviving report |
| Projects (2) | 1 rejected (real message); 1 orphan task (parent never loaded) | read the empty async wrapper job, not the child report job |
| Customers (4) | **2 LOADED** to base, 1 real reject, 1 held for dup review | orig-system key written NULL → base match couldn't resolve |
| HCM (7) | All 7 rejected by HDL (real messages) | file-level errors carry null key → nothing matched; + a fabricated LOADED |

**Key correction (user-driven):** a nonexistent project reference only rejects a ROW; it does
NOT crash a job. AR and Expenditures are TRUE job-level crashes — no per-row verdict exists,
so those records are honestly UNACCOUNTED (dark-red tile), not fabricated failures.

## PRs merged this session (all reviewed + merged to main)
- **#222** Reconcilers: never mark LOADED without positive load evidence (killed two fabricated
  LOADEDs — plan_budget "absence = loaded"; HDL zero-load partial-success).
- **#223** Requisitions: a row with a real Fusion error must be FAILED, not left GENERATED.
- **#224** Projects: reconcile from the child `ImportProjectReportJob`, not the empty wrapper.
  *(reader only — did not work end-to-end; completed by #229.)*
- **#225** Grants: read the Award Batch Import Report for per-award errors.
  *(same capture gap as #224 — being completed on a follow-up branch.)*
- **#226** HCM/HDL: attribute file/dataset-level Fusion errors to rows as FAILED.
- **#227** Customers: reconcile Party Site Uses via interim parent-ref key + error tier.
  **Needs a versioned BIP redeploy of `DMT_CUST_RECON_DM.xdm` to `/Custom/DMT2/Customers/`
  (HUMAN step) before its reconciler change fully resolves the records.**
- **#228** Expenditures: resolve PROJECT_NUMBER/TASK_NUMBER via `DMT_XREF_PKG` (not blind prefix).
- **#229** Projects: **capture** the report child during reconcile (not just read it) + fix
  `PARSE_ERRORS` ORA-30625 on empty XML tags + composite name/number id match.
  **Validated end-to-end (run 238):** `RTPRJ-BAD1` → FAILED with "The project status isn't
  valid"; good projects → base; zero unaccounted.
- **#230** Expenditures: revert the dead GL_DATE default (run 236 proved it didn't fix the
  costing crash; and it was a data patch we don't want).
- **#231** Funnel: add `ALL_UNACCOUNTED` object-level flag so the UI colors a whole
  job-crashed object dark red vs a partial-unaccounted object lighter red.

## The accounting model (settled)
- **LOADED** = real base-table row. **FAILED** = real Fusion error string (`[FUSION_ERROR]` /
  `[IMPORT_REPORT]`). Otherwise **UNACCOUNTED** = OUR code hasn't found the outcome yet.
- **Two failure shapes:** (1) job succeeded, per-row rejects → capture the report/log and mark
  each rejected row FAILED; (2) job crashed at job level → no per-row verdict → leave all
  UNACCOUNTED + dark-red tile; do NOT patch data to force a "success".
- **The report-capture pattern:** the reconcile path (`RECONCILE_ONE`) does NOT pre-capture the
  child report job. A reconciler that only READS an already-captured child (Projects #224,
  Grants #225) always gets NULL and leaves rejections unaccounted. It must CALL
  `DMT_ESS_UTIL_PKG.CAPTURE_REPORT_ESS_JOB` lazily, like BillingEvents does.

## Open items / next steps
1. **Grants report-capture** — finish the #224/#229-style capture-then-read fix (a follow-up
   branch was in progress; the funnel `ALL_UNACCOUNTED=Y` on Grants in run 238 flagged it).
2. **Full regression run** (all pipelines, ALL mode) to validate every merged reconciler
   end-to-end and produce the complete honest scorecard. **Blocked on host DB port** (see below).
3. **Customers BIP redeploy** — versioned `.xdm` deploy to Fusion (human).
4. **Dark-red tile UI** — wire the APEX funnel tile to `ALL_UNACCOUNTED`.
5. **Expenditures / AR job-level crashes** — accounted honestly (dark red). Getting those jobs
   to actually run (the Expenditures ORA-01008 cause is still unpinned; remaining gold CSV
   divergence is `UNIT_OF_MEASURE_NAME`) is a SEPARATE, later task — only if the user asks.
6. Minor: unescape `&apos;` in import-report messages.

## Environment note at session close
`dmt2-local` DB is healthy (answers via `docker exec`, internal port 1521) and ORDS/APEX work
(host 8182). But the **host DB port 1523 forwarding is wedged** (Docker networking layer) — a
`docker restart dmt2-local` did NOT clear it; `rt-oracle-free`'s 1521 is affected too. The
Python deploy script and regression harness need host 1523, so the full-regression validation
is deferred until the port is cleared (likely `wsl --shutdown` + relaunch Docker Desktop).
There is a stale **run 154 QUEUED** to clear when connectivity returns.

## Working location
Fix work done in the `DMT2-fixes` worktree (the main `DMT2` working dir sits on a stale
pre-framework branch `revert/hdl-197-assignment-number` with uncommitted drift — separate
triage; do not `reset --hard` it blindly).
