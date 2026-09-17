# DMT2 Backlog — ROI ranking (value ÷ effort)

Generated 2026-09-17. Open items only (STILL OPEN + PARTIAL); RESOLVED/STALE excluded.

**Formula:** value = P1:5 / P2:3 / P3:1 · effort = cost + risk · ROI = value ÷ effort.
Ties broken by lower effort, then lower item number. This is the suggested implementation order for the CI/CD loop.

| Rank | # | Item | Pri | Cost | Risk | ROI | State |
|---:|---:|---|:--:|---:|---:|---:|:--|
| 1 | 7 | Reconcile registered in two places / fail-open | P1 | 4 | 5 | 0.556 | PARTIAL |
| 2 | 27 | Centralize [RECONCILE_ERROR] unmatched-row sweep | P2 | 3 | 3 | 0.5 | PARTIAL |
| 3 | 28 | Shared DMT_IMPORT_REPORT_PKG.APPLY_ERRORS | P2 | 3 | 3 | 0.5 | STILL OPEN |
| 4 | 29 | Implement outcome-based tile palette | P2 | 4 | 2 | 0.5 | STILL OPEN |
| 5 | 31 | 73 invalid views bound to dropped columns | P2 | 3 | 3 | 0.5 | PARTIAL |
| 6 | 26 | Rename work status VALIDATING → PROCESSING | P2 | 3 | 4 | 0.429 | STILL OPEN |
| 7 | 9 | Full-fidelity scenario upload (multi-CSV zip) | P1 | 8 | 5 | 0.385 | STILL OPEN |
| 8 | 10 | Funnel metrics view + Object Detail redesign | P2 | 5 | 3 | 0.375 | PARTIAL |
| 9 | 13 | ALL-mode transform bypasses pre-validation | P2 | 3 | 5 | 0.375 | STILL OPEN |
| 10 | 25 | Naming conformance sweep | P2 | 5 | 3 | 0.375 | STILL OPEN |
| 11 | 45 | Document prefixed business key(s) per object | P3 | 2 | 1 | 0.333 | STILL OPEN |
| 12 | 49 | Verify Run Pipeline screen against spec | P3 | 2 | 1 | 0.333 | STILL OPEN |
| 13 | 57 | Browser-verify Page 82 tile grid | P3 | 2 | 1 | 0.333 | STILL OPEN |
| 14 | 11 | Reconcilers reach LOADED without capturing Fusion id | P2 | 5 | 4 | 0.333 | STILL OPEN |
| 15 | 14 | Build the stage→transform error table | P2 | 5 | 4 | 0.333 | PARTIAL |
| 16 | 19 | Convert cross-object key refs to DMT_XREF_PKG | P2 | 5 | 4 | 0.333 | PARTIAL |
| 17 | 20 | Fold FETCH_BIP_RESULTS into RUN_BIP_REPORT | P2 | 5 | 4 | 0.333 | STILL OPEN |
| 18 | 30 | Log attribution + Activity Log browser | P2 | 6 | 3 | 0.333 | STILL OPEN |
| 19 | 36 | Config holds instance IDs by number not name | P2 | 5 | 5 | 0.3 | STILL OPEN |
| 20 | 8 | Move per-object logic out of run_one_object_type | P1 | 9 | 8 | 0.294 | STILL OPEN |
| 21 | 22 | Contract v1 reports for 14 HDL objects | P2 | 7 | 4 | 0.273 | STILL OPEN |
| 22 | 23 | Add BASE tiers to 15 interface-only recon reports | P2 | 6 | 5 | 0.273 | PARTIAL |
| 23 | 51 | CSV upload E2E verification (Pages 2–12) | P3 | 3 | 1 | 0.25 | STILL OPEN |
| 24 | 52 | Delete superseded APEX pages | P3 | 2 | 2 | 0.25 | STILL OPEN |
| 25 | 15 | Fold config objects into queue + retire runners/ | P2 | 6 | 6 | 0.25 | STILL OPEN |
| 26 | 21 | Conform 25 recon reports to Contract v1 | P2 | 7 | 5 | 0.25 | STILL OPEN |
| 27 | 12 | Every object inject a run-scoped batch id | P2 | 7 | 6 | 0.231 | STILL OPEN |
| 28 | 16 | Catalog-driven queue dispatch | P2 | 7 | 7 | 0.214 | STILL OPEN |
| 29 | 47 | Replace LIKE-matching with equality | P3 | 2 | 3 | 0.2 | STILL OPEN |
| 30 | 54 | Remove files table from ESS Job Detail | P3 | 3 | 2 | 0.2 | STILL OPEN |
| 31 | 56 | Retire superseded docs | P3 | 4 | 1 | 0.2 | STILL OPEN |
| 32 | 58 | Retire PayrollRelationships drill view + APEX region | P3 | 3 | 2 | 0.2 | STILL OPEN |
| 33 | 48 | Complete validator tag adoption | P3 | 4 | 2 | 0.167 | STILL OPEN |
| 34 | 50 | Dashboard redesign | P3 | 4 | 2 | 0.167 | STILL OPEN |
| 35 | 53 | Rename APEX *_INTEGRATION_ID → *_RUN_ID | P3 | 3 | 3 | 0.167 | STILL OPEN |
| 36 | 38 | Remove cancellation (CANCEL_RUN) | P3 | 3 | 4 | 0.143 | STILL OPEN |
| 37 | 42 | Standardize validator entry points | P3 | 4 | 4 | 0.125 | STILL OPEN |
| 38 | 39 | Banks to REST | P3 | 6 | 3 | 0.111 | STILL OPEN |
| 39 | 41 | Eliminate standalone procedures | P3 | 5 | 5 | 0.1 | PARTIAL |
| 40 | 43 | Split supplier transform/reconciler pkgs per object | P3 | 5 | 5 | 0.1 | STILL OPEN |
| 41 | 46 | Eliminate runtime EXECUTE IMMEDIATE | P3 | 5 | 6 | 0.091 | STILL OPEN |
| 42 | 44 | Mode-driven selection predicates; retire RETRY | P3 | 6 | 6 | 0.083 | STILL OPEN |

## Caveat — re-triage needed

This ranking is computed from `docs/backlog.html` (triaged 2026-09-16), which
predates the HCM Worker-merge work (PRs #276–#280). Several items may already be
resolved or changed by that work (e.g. #13 ALL-mode pre-validation was
regression-proven for the HCM objects; the retired-object view cleanup #58 is
partly done). Re-triage the backlog against `main` before starting the
implementation loop so the ROI order reflects what is actually still open.

## How this feeds the CI/CD loop

Work the list top-down. For each item: branch → implement → `python
scripts/ci_promote.py test-local` (deterministic gate) → on green, merge → `... 
deploy-prod --yes` → `... test-prod --yes`. See `docs/cicd.md`.
