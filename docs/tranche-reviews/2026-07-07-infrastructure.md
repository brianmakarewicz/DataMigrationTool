# Blind Tranche Review — Schema Infrastructure (2026-07-07)

Reviewer: blind subagent. Scope: inline indexes, synonyms/, grants/, seed/, jobs/,
procedures/, install enrollment + ordering.
**Verdict: FAIL.** Mechanics competent (guards, masked credentials, heartbeat matches design,
mostly sound ordering) but four HIGH substance failures: query contracts have no index
support; decided config keys never seeded; retired objects enrolled; all 12 standalone
procedures shipped including the 5 the spec names as dead.

Proposed rules: 8, added to DMT_DESIGN.html section 7 in RED.

## Fixed now (2026-07-07)
| # | Finding | Fix |
|---|---------|-----|
| 11 | ESS_POLL_TIMEOUT_MINUTES / BIP_CHUNK_SIZE / RETENTION_DAYS missing from config seed | Seeded with decided defaults (30 / 5000 / 90). |
| 19 | Poller job DDL carried snapshot start_date + NLS_ENV dump, enabled at create | Rewritten greenfield: systimestamp start, no NLS_ENV, created DISABLED. |
| 24 | Job enabled mid-install before grants/seeds/recompile | install.sql reordered: job creation + enable moved to final step after recompile. |

## Deferred with tracking
| # | Sev | Finding | Disposition |
|---|-----|---------|-------------|
| 1-3,5 | HIGH/MED | Contract indexes missing: no TFM RUN_ID index anywhere (0/97), log RUN_ID unindexed, STG STATUS 40/121, SCENARIO_ID nowhere, queue NEXT_POLL_AFTER unindexed | **DEFER to a dedicated index-conformance commit** once the contract-index red rule is accepted — one guarded index file pass, testable in Docker. High-value, low-risk; schedule immediately after rule review. |
| 4 | MED | Four index-naming conventions | Covered by accepted-pending constraint-naming red rule; naming sweep. |
| 6,9 | MED/LOW | DMT_LOOKUP has whole-table SELECT on credential-bearing DMT_CONFIG_TBL; direct log-table INSERT bypasses DMT_UTIL_PKG.LOG | **DEFER to Stage B** (util/credential layer port) — replace with definer-rights API + credential-free view per red rule. |
| 7 | MED | DMT_LOOKUP two-schema split has no design-doc contract | **USER DECISION** — spec section 4 places lookup/COA packages inside DMT_OWNER; either amend spec to codify the second schema + interface, or fold lookup into DMT_OWNER. Flag with red-rule review. |
| 8 | LOW | Missing synonym for DMT_LKP_REFRESH_PKG | Fix with #6 in Stage B. |
| 10 | LOW | INHERIT PRIVILEGES grant noise; `whenever sqlerror continue` in grants_made.sql | **DEFER to grants cleanup** with #6 (same file). |
| 12 | MED | Config seed duplicates per-object registry facts (import jobs, UCM accounts, BIP paths) | **DEFER to Stage B/C registry work** — facts move to their assigned tables when the catalog/registry refactor lands (one-fact-one-home red rule). |
| 13,16 | MED/LOW | BIP registry seed carries decided-retired rows (ItemCategories, PlanningBudgets, GLBudgetBalances, versioned AP_V4, COMMON_LOOKUPS-as-CEMLI); REST lookup ditto | **DEFER to BIP registry Contract v1 rework (Stage B)** — rows and columns change together. |
| 14 | MED | ERP options: 156/180 rows NULL CEMLI_CODE; stray retired rows; case-inconsistent usernames | **DEFER to Stage B ERP-options triage** (spec already orders NULL-row investigation). |
| 15 | MED | No seed for DMT_UPLOAD_OBJECT_TBL / DMT_UPLOAD_DICT_TBL | **DEFER to Stage F APEX port** (upload routing is UI-facing); note in APEX-port checklist. |
| 17 | LOW | Insert-and-skip seeds never converge corrected values | Covered by registry-MERGE red rule; apply during Stage B registry rework. |
| 20 | MED | Decided retention purge job not written, tracked nowhere | **NEW BACKLOG ITEM** — build with Stage C queue work (it purges queue/log/CLOB state). Now tracked here. |
| 21,22 | HIGH/MED | All 12 standalone procedures shipped; 5 are the spec's explicit drop list; live 7 are APEX-support in engine tree; INTEGRATION_ID references; hardcoded '0000' prefix | **DEFER split:** the 5 dead ones — delete after a reference check (quick, next session); the 7 live ones — fold into DMT_APEX_PAGE_PKG at Stage F APEX port. |
| 23 | HIGH | install.sql enrolls decided-retired objects (prefix seq/master, RCV, plan-budget, conversion-master archive, migration log, apex_export_tmp, 36 deleted views, a view named *_TBL) | Views handled in views-tranche log (36 deleted now); remaining objects tracked in sequences/tables logs — drop with their callers. |
| 25 | MED | Cross-schema install order undocumented; owner-then-lookup first run leaves invalids until re-run | **FIX with Stage A close-out** — add prerequisite headers to both installs + document the build_local_db.sh sequencing as the driver contract (red rule pending). |
| 18 | — | Poller job conforms to heartbeat design | No action. |
