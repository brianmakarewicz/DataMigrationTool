# DMT2 Backlog - ROI ranking (value / effort)

Regenerated 2026-09-17 after re-triage against the recent merges (#276-281 + the HDL
recon-report thread). Open items only (STILL OPEN + PARTIAL).

**Formula:** value = P1:5 / P2:3 / P3:1 . effort = cost + risk . ROI = value / effort.
Ties broken by lower effort, then lower item number. Suggested order for the CI/CD loop.

| Rank | # | Item | Pri | Cost | Risk | ROI | State |
|---:|---:|---|:--:|---:|---:|---:|:--|
| 1 | 59 | Fix BenParticipant ORA-06502 in RECONCILE_BATCH | P2 | 2 | 2 | 0.75 | STILL OPEN |
| 2 | 70 | Partitioned-object run-detail tiles misreport load/import IDs + parent placeholder | P1 | 4 | 3 | 0.714 | STILL OPEN |
| 3 | 60 | W2Balances + WorkSchedules Contract v1 recon SOAP 500 | P2 | 3 | 2 | 0.6 | STILL OPEN |
| 4 | 7 | Reconcile registered in two places / fail-open | P1 | 4 | 5 | 0.556 | PARTIAL |
| 5 | 27 | Centralize [RECONCILE_ERROR] unmatched-row sweep | P2 | 3 | 3 | 0.5 | PARTIAL |
| 6 | 28 | Shared DMT_IMPORT_REPORT_PKG.APPLY_ERRORS | P2 | 3 | 3 | 0.5 | STILL OPEN |
| 7 | 29 | Implement outcome-based tile palette | P2 | 4 | 2 | 0.5 | STILL OPEN |
| 8 | 31 | 73 invalid views bound to dropped columns | P2 | 3 | 3 | 0.5 | PARTIAL |
| 9 | 26 | Rename work status VALIDATING -> PROCESSING | P2 | 3 | 4 | 0.429 | STILL OPEN |
| 10 | 9 | Full-fidelity scenario upload (multi-CSV zip) | P1 | 8 | 5 | 0.385 | STILL OPEN |
| 11 | 10 | Funnel metrics view + Object Detail redesign | P2 | 5 | 3 | 0.375 | PARTIAL |
| 12 | 25 | Naming conformance sweep | P2 | 5 | 3 | 0.375 | STILL OPEN |
| 13 | 45 | Document prefixed business key(s) per object | P3 | 2 | 1 | 0.333 | STILL OPEN |
| 14 | 49 | Verify Run Pipeline screen against spec | P3 | 2 | 1 | 0.333 | STILL OPEN |
| 15 | 57 | Browser-verify Page 82 tile grid | P3 | 2 | 1 | 0.333 | STILL OPEN |
| 16 | 61 | Dedupe local regression STG seed (HCM) | P3 | 2 | 1 | 0.333 | STILL OPEN |
| 17 | 11 | Reconcilers reach LOADED without capturing Fusion id | P2 | 5 | 4 | 0.333 | STILL OPEN |
| 18 | 14 | Build the stage->transform error table | P2 | 5 | 4 | 0.333 | PARTIAL |
| 19 | 19 | Convert cross-object key refs to DMT_XREF_PKG | P2 | 5 | 4 | 0.333 | PARTIAL |
| 20 | 20 | Fold FETCH_BIP_RESULTS into RUN_BIP_REPORT | P2 | 5 | 4 | 0.333 | STILL OPEN |
| 21 | 30 | Log attribution + Activity Log browser | P2 | 6 | 3 | 0.333 | STILL OPEN |
| 22 | 36 | Config holds instance IDs by number not name | P2 | 5 | 5 | 0.3 | STILL OPEN |
| 23 | 8 | Move per-object logic out of run_one_object_type | P1 | 9 | 8 | 0.294 | STILL OPEN |
| 24 | 23 | Add BASE tiers to 15 interface-only recon reports | P2 | 6 | 5 | 0.273 | PARTIAL |
| 25 | 51 | CSV upload E2E verification (Pages 2–12) | P3 | 3 | 1 | 0.25 | STILL OPEN |
| 26 | 52 | Delete superseded APEX pages | P3 | 2 | 2 | 0.25 | STILL OPEN |
| 27 | 15 | Fold config objects into queue + retire runners/ | P2 | 6 | 6 | 0.25 | STILL OPEN |
| 28 | 21 | Conform 25 recon reports to Contract v1 | P2 | 7 | 5 | 0.25 | STILL OPEN |
| 29 | 12 | Every object inject a run-scoped batch id | P2 | 7 | 6 | 0.231 | STILL OPEN |
| 30 | 16 | Catalog-driven queue dispatch | P2 | 7 | 7 | 0.214 | STILL OPEN |
| 31 | 47 | Replace LIKE-matching with equality | P3 | 2 | 3 | 0.2 | STILL OPEN |
| 32 | 54 | Remove files table from ESS Job Detail | P3 | 3 | 2 | 0.2 | STILL OPEN |
| 33 | 56 | Retire superseded docs | P3 | 4 | 1 | 0.2 | STILL OPEN |
| 34 | 58 | Retire PayrollRelationships drill view + APEX region | P3 | 3 | 2 | 0.2 | STILL OPEN |
| 35 | 48 | Complete validator tag adoption | P3 | 4 | 2 | 0.167 | STILL OPEN |
| 36 | 50 | Dashboard redesign | P3 | 4 | 2 | 0.167 | STILL OPEN |
| 37 | 53 | Rename APEX *_INTEGRATION_ID -> *_RUN_ID | P3 | 3 | 3 | 0.167 | STILL OPEN |
| 38 | 38 | Remove cancellation (CANCEL_RUN) | P3 | 3 | 4 | 0.143 | STILL OPEN |
| 39 | 62 | CI/CD phase 2: self-hosted runner + Playwright + APEX-to-local | P3 | 5 | 2 | 0.143 | STILL OPEN |
| 40 | 42 | Standardize validator entry points | P3 | 4 | 4 | 0.125 | STILL OPEN |
| 41 | 39 | Banks to REST | P3 | 6 | 3 | 0.111 | STILL OPEN |
| 42 | 41 | Eliminate standalone procedures | P3 | 5 | 5 | 0.1 | PARTIAL |
| 43 | 43 | Split supplier transform/reconciler pkgs per object | P3 | 5 | 5 | 0.1 | STILL OPEN |
| 44 | 46 | Eliminate runtime EXECUTE IMMEDIATE | P3 | 5 | 6 | 0.091 | STILL OPEN |
| 45 | 44 | Mode-driven selection predicates; retire RETRY | P3 | 6 | 6 | 0.083 | STILL OPEN |

## What changed in this re-triage

- **#22** (Contract v1 reports for 14 HDL objects) -> RESOLVED (built/deployed this session).
- **#13** (ALL-mode pre-validation) -> RESOLVED per PR #249 (re-verify on HCM).
- **New:** #59 BenParticipant ORA-06502, #60 W2Balances/WorkSchedules recon 500s,
  #61 dedupe local STG seed, #62 CI/CD phase 2. #59-#61 are the local-green blockers.

## How this feeds the CI/CD loop

Top-down: branch -> implement -> `python scripts/ci_promote.py test-local` (gate) -> merge
(waits for pr-review.yml) -> `deploy-prod --yes` -> `test-prod --yes`. See `docs/cicd.md`.
