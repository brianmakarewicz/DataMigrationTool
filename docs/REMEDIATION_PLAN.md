# DMT2 Remediation Plan (2026-07-19, doc-corrected)

Grounded in DMT_DESIGN.html. Correction vs the first draft: the doc's accounting rule
governs status, so there is **no new "all-failed ⇒ RED status" rule** — the status logic
is already correct. The real defects are COUNTING (pre-validation failures aren't counted),
TILE COLOR (outcome palette not implemented — already §12 P2), ALL-mode pre-validation
bypass (already §12 P2), and ERROR HONESTY.

## Authoritative rules from the doc (do not reinvent)
- **Accounting rule (§ status):** a work item is DONE iff every record is accounted for —
  LOADED (in Fusion base tables, id captured) or FAILED with a real reportable error. It is
  FAILED only if a record is UNACCOUNTED. Row failures alone never fail the work item;
  unexplained rows do.
- **Zero-row item:** DONE with zero counts = grey tile (correct, not a failure).
- **Run rollup:** COMPLETED (all accounted, no failures) / COMPLETED_ERRORS (some rows
  FAILED with errors) / FAILED (any unaccounted) / NO_ROWS_PROCESSED.
- **Tile palette (§9, decided; hex finals):** worst-child-wins ranked unaccounted > failed >
  loaded. all-loaded green `#5fbf4f`; some-failed-all-accounted lime `#c2e58f`;
  unaccounted light-red/red; zero grey; in-progress blue. NOT YET IMPLEMENTED — §12 P2.
- **STG is the denominator:** every count = TFM rows this run + pre-transform failures this
  run (DMT_STG_TFM_ERROR_TBL). Reporting derives success from TFM and pre-TFM errors from the
  error table — never from STG_STATUS/STG ERROR_TEXT.

## PHASE 0 — Measurement (counts + palette + honesty). MUST come first.
- **0A. Accounting gate counts pre-transform failures.** `dmt_queue_worker_pkg.pkb.sql`
  ACCOUNT_ROWS/apply_accounting_gate count TFM only. Add the DMT_STG_TFM_ERROR_TBL count
  (RUN_ID+CEMLI_CODE+SUB_OBJECT) so `total = TFM + error rows` and failed includes pre-validation
  failures. **Status semantics unchanged** — all-accounted stays DONE, any-unaccounted is
  FAILED, per the doc. This just makes the totals honest (Customers: 28 failed, not 0) and lets
  a truly-unaccounted object (Expenditures after 2A) correctly go FAILED.
- **0B. `DMT_RECORD_DETAIL_V` includes pre-validation failures.** Today TFM-only (~97 UNION),
  never reads the error table — so the scorecard shows 0 for an all-pre-validation-failed
  object. Add the error-table lane (anti-joined vs reached-TFM, reuse `DMT_OBJECT_FUNNEL_V`'s
  proven CTE) so they surface as FAILED-with-error. Then record view and funnel agree.
- **0C. Runner totals off STG.** `dmt_regression_run.py`: after 0B it reads correct counts;
  add a per-object assertion that records-seen == STG inventory for the scenario (the
  denominator check). Do NOT make DONE-with-zero a hard failure — the doc says grey/DONE is
  correct for genuinely-empty objects; the real signal is the STG-denominator mismatch.
- **0D. Finish validator error-table wiring** for the regression objects (prereq for 0A/0B to
  have rows). Pattern: `dmt_cust_validator_pkg`.
- **0E. Implement the §9 outcome tile palette** (already §12 P2) in `DMT_RUN_DETAIL_TILES` /
  `DMT_V_CEMLI_STATUS`, driven by loaded / failed-with-error / unaccounted counts. This is the
  surface that makes an all-failed object read RED even though its work-item status is DONE.
- **0F. Self-guard PreToolUse hook** — before any scenario run, query STG counts per object in
  the pipelines; block if an expected object is empty. Allowlist the intentionally-empty HCM
  extras. Register next to `dmt_stg_guard.py`.

## PHASE 1 — Seed / input
- **1A.** Fix `SCENARIO_ID = 0` → `IS NULL` in `rebuild_regressiontest_scenario.sql` (458-476)
  and `seed_regressiontest2_scenario.sql` (470-485) + the Python SQL-export path. (rt3 done;
  live generator already correct.)
- **1B.** Billing Events: PCS10001/PCS10013 are **intentional pre-existing Fusion projects**
  (valid contract-line link, live accepted events). Seed them as pre-existing LOADED project
  references (the Allied pattern) so dependency pre-validation passes. Not a mistake.
- **1C.** AR Invoices: cascade of Customers; no change, re-verify after 1A.

## PHASE 2 — Real per-object load fixes
- **2A.** Expenditures: remove the fabricated "all-or-nothing rollback" text; with no direct
  interface/base signal the rows are UNACCOUNTED → the accounting rule flips the work item to
  FAILED (RED) honestly. Produces the real ESS load error → unblocks #189.
- **2B.** HDL/HCM cluster: RECONCILE_HDL SourceSystemId→row matching; replace per-record REST
  LOOKUP_FUSION_IDS with bulk BIP (needs run-scoped batch id); prefix assignment numbers.
- **2C.** Items lot/serial, Requisitions REQ-002, Project Budgets — diagnose each vs the real
  Fusion interface error. Grants — document as not-configured.

## PHASE 3 — PRs
- **3A. #192** — scope async-wait to genuinely-async objects (positive flag, not "has
  REPORT_JOB_DEF"); fix `/Custom/DMT/` → `/Custom/DMT2/`.
- **3B. #189** — hold for 2A's real load error, then decide NLR columns + README.

## PHASE 4 — Housekeeping
- Close stale ACTIVE runs (#171 locks Customers).
- ALL-mode pre-validation bypass — already §12 P2 PROPOSED; implement the written fix
  (exclude rows with a `[PRE_VALIDATION]` error for the run from ALL/FAILED transform predicate).
- Commit the untracked seed SQL scripts.

## Owner items (accept the already-PROPOSED §12 red rules; no new decisions)
- §12 P2 · outcome tile palette — accept/implement (0E).
- §12 P2 · ALL-mode pre-validation bypass fix — accept/implement (Phase 4).
- Everything else is specified or determinable; no open design decisions.

## First action + validation
Start with **0B + 0A** (record view + accounting gate) so pre-validation failures are counted
and visible. Then:
```
python scripts/insert_regression_test_data.py --scenario RegressionTest    # or re-seed RegressionTest3
python scripts/dmt_regression_run.py --scenario RegressionTest3 --run-mode NEW --json out.json
python scripts/dmt_regression_run.py --status-only 174 --json run174_relensed.json
```
Pass signals (Rule #1): Customers/AR/Billing show their real failure counts (not 0); the run
rolls up COMPLETED_ERRORS; record view and funnel agree; every object's records-seen == its STG
inventory; no fabricated errors remain.
