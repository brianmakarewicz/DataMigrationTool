# Blind Tranche Review — Engine (2026-07-08)

Reviewer: blind subagent. Scope: queue/worker/scheduler/init/loader/mock packages,
control tables + seeds, poller job, engine test suites.
**Verdict: FAIL** — architecture endorsed (dispatch scoping honored exactly, seed
integrity clean, ESS-ERROR-routes-to-reconcile correct, mock isolation well-designed),
but decided section-2/5 behaviors are missing or inverted at the heart of the
accounting rule. Fix and re-review before Stage D.

Proposed rules: 6, added to the canonical doc's red block (one-writer-per-status,
config-key-shadowing ban, single accounting gate, spec-cited assertions,
no-vocabulary-extension-by-fixtures, serialization for uniqueness rules).

## Correctness cluster — FIX NOW (Stage C task 4, agent dispatched)
| # | Finding | Fix direction |
|---|---------|---------------|
| A1/A2/A12 | Run-status rollup inverts COMPLETED_ERRORS/FAILED; never produces NO_ROWS_PROCESSED; reads only work statuses; test 20 pins the inversion; three RUN_STATUS writers | Rewrite rollup per the spec status table (FAILED item → run FAILED; all-DONE + FAILED rows → COMPLETED_ERRORS; zero rows → NO_ROWS_PROCESSED); single writer; fix test 20 with spec citation. |
| A3 | Timeout = hard FAIL from hardcoded constant; ESS_POLL_TIMEOUT_MINUTES seeded but never read | Read config key; on timeout mark GENERATED rows FAILED [LOAD_ERROR] and route to RECONCILING (timeout is a trigger, never a verdict). |
| A4 | DONE reachable with zero accounting check (SYNC/HDL/no-ESS-id path) | Single accounting gate: every DONE routes through the unaccounted-rows check. |
| A5 | Transient SOAP fault → job ERROR → premature reconcile | Retry-next-tick per section 2; only definitive terminal states advance. |
| A6 | [LOAD_ERROR] row-marking absent everywhere | Implement: load ESS ERROR/timeout marks GENERATED rows FAILED with tagged text before reconcile. |
| B1 | RECONCILE_ONE accounting reads the hardcoded legacy DMT_OBJECT_DETAIL_V (FORCE, 85 branches, not partition-aware; unregistered objects trivially pass) | Drive accounting from DMT_CEMLI_CATALOG_TBL (TFM table/status column per record type); partition-aware where PARTITION_KEY set. |
| C6 | create_run_and_queue ignores USE_PREFIX (cutover switch dead on the primary path) | Honor USE_PREFIX like INIT_RUN. |
| A9a | One-active-run check is read-then-insert (TOCTOU) | Serialize (DBMS_LOCK request or SELECT FOR UPDATE convention). |
| A7b | EXECUTE_ONE flips to LOADING before validate/transform/generate | Hold the processing status until load submission actually starts. |
| A8 | CANCEL_RUN + CANCELLED + RETRY reset_scenario_status + include_untagged all shipped | Remove: procedure, statuses from CKs, the reset path, and the p_include_untagged threading (signature ripple through RUN_* + mock + dispatch shapes). |
| E1 | Mock seeds ship in production install; invented tags | Move mock seed out of db/install into test setup; align tags to section-5 vocabulary ([TRANSFORM_ERROR]/[RECONCILE_ERROR] etc.); TEST pipeline code documented or replaced. |

## Deferred with tracking
| # | Finding | Disposition |
|---|---------|-------------|
| A9b/c | QUEUED-forever runs never reach terminal; ALL-mode scenario not validated | Fix with the run-lifecycle pass alongside A1 (same rollup work) — in task-4 scope if cheap, else next. |
| A10 | Partition model contradicts decided plan-computes-partitions design; split_multi_fbdi dead code (with banned dynamic SQL — C2a) | **Stage C task 5** — partition support is its own work item (touches PLAN_RUN preview + work-item grain + tiles). The dead dynamic-SQL split code is deleted in task 4 (it is unreachable and non-conformant). |
| A11 | PLAN_RUN invented vocabulary; OTC alias | Fix with A10 planning work. |
| C2b | dmt_loader_pkg dynamic SQL (update_master_totals per-TFM counts; retired reset) | reset_scenario_status deleted in task 4 (retired); update_master_totals superseded by the new rollup — delete or make static with it. |
| C4 | Assets/Items hardcoded worker branches | Documented exceptions for now; fold at those objects' Stage D/E ports. |
| C5 | POSTRUN_JOB seeded on pipeline-def but worker reads ERP options | Task 4: read from pipeline-def (one fact, one home) or un-seed the column — pick one, document. |
| A13 | Hourly-not-100-ticks comment; permissive absent-dependency; no DEPENDS_ON validation | Task 4 quick fixes (validate DEPENDS_ON tokens against registry at seed/submit). |
| D1-D7 | Positional LOG calls, error-code posture, nested blocks, headers, 1099 LIKE re-seeded, mojibake in specs, _IX index | Rolling cleanup + the 1099 discriminator question folds into the existing spec-self-contradiction user item. |
| F1 | Untested decided behaviors list | Task 4 adds tests for what it fixes (timeout, rollup cases, accounting gate); POLL_ONE live-path tests need Fusion (password). |

## Confirmed conformant
Registry dispatch exactly per the proposed exception scoping (bind-only, validated,
one named site); seed integrity clean on sample (no orphan EXEC/RECON procs); ESS
ERROR routes to reconcile; zero-BIP-rows → FAILED (absence ≠ LOADED holds).

## Task 4 executed (2026-07-08) — correctness cluster CLOSED
All FIX NOW items implemented and spec-cited: single-writer rollup per the Overview status
table (only 2 SET RUN_STATUS sites = the rollup's two arms), configurable timeout as
trigger-never-verdict, single accounting gate (sole writer of DONE; one spec-cited Assets
exemption), transient-fault retry-next-tick, [LOAD_ERROR] marking (9 loader sites also
retagged from the wrong [FUSION_ERROR]), catalog-driven ACCOUNT_ROWS replacing the legacy
view, USE_PREFIX honored + doubles as the submission mutex (FOR UPDATE — closes TOCTOU),
ALL-requires-scenario, DEPENDS_ON validation, CANCEL_RUN/CANCELLED/reset_scenario_status/
update_master_totals/INCLUDE_UNTAGGED fully removed (grep-proven), mock seeds moved out of
the production install, invented tags fixed. Queue-engine suite 25 -> 39 assertions, all
status assertions spec-cited. 6/6 suites + golden green; invalid = 46.
Remaining (documented): per-object p_include_untagged/'RETRY' literals fold at Stage D/E
ports; legacy sync orchestrators flagged for retirement; work-queue CK vocabulary + rename
still P2; dynamic-SQL exception ruling now covers 3 named sites (dispatch + accounting).
RE-REVIEW: dispatched per the FAIL verdict.

## RE-REVIEW verdict (2026-07-08): PASS-WITH-FINDINGS
Every fix-now finding confirmed genuinely fixed against the spec sentences cited, verified
in both git and the live Docker DB. Three bounded items keep it short of a clean pass, all
being closed now:
1. DMT_SUBMIT_RUN_V2 (the old APEX submission procedure) bypasses all new submission
   guards — being rewritten to delegate to the scheduler; the 3 dead submit procedures
   are being dropped.
2. The catalog's ROW_FILTER predicate is concatenated into accounting SQL unvalidated —
   now named explicitly in the pending dynamic-SQL exception ruling (user decides).
3. The TEST pipeline / mock fixtures had no spec entry — a red proposed entry now names
   them in the canonical doc.
Small items also being fixed: config-typo-becomes-verdict on the timeout key, no wait
limit on the submission lock, two stale comments. Known residues documented: accounting
counts TFM rows only (pre-transform failures wait on the stage-to-transform error table —
tied to that existing backlog item); Assets whole-object accounting until partition work
(Stage C task 5); the archived APEX export calls retired signatures (rework at the Stage F
APEX port). Deferred-table corrections: A9b/c, C2b, C5, A13 are done.
