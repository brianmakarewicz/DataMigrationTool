# Blind Tranche Review — Conformance tranche (2026-07-09)

Reviewer: blind subagent (spec read in full; committed files and deployed Docker DB
state reviewed against DMT_DESIGN.html section 7 accepted rules).
**Verdict: FAIL** — the conformance tranche's mechanical sweeps landed most of the
STG/TFM dictionary rename, but the review found one runtime-breaking seed defect
(the split registry still names the retired STATUS column the sweep itself renamed),
plus checker under-coverage, compatibility aliases the accepted no-aliases rule bans,
FORCE retained across every view file, and duplicate index numbering on the supplier
family.

## Findings — dispositions (remediated in this PR unless marked TRACKED)

| # | Finding | Disposition |
|---|---------|-------------|
| F1 | **Runtime-breaking:** `db/seed/dmt_cemli_split_cfg.sql` carried six rows with `STATUS_COLUMN = 'STATUS'` — the retired column name the same tranche renamed to TFM_STATUS. The engine reads this value to build its split SQL, so every split object (1099Invoices, APInvoices, ARInvoices, BlanketPOs, Contracts, PurchaseOrders) would fail at the split step. Worse, the seed was insert-and-skip, so the registry-converge rule (accepted 2026-07-08, which names split config explicitly) could never propagate a fix. | **FIXED NOW**: seed rewritten as MERGE on the business key (CEMLI_CODE, the table's PK); all seven rows uniformly TFM_STATUS; the table file's `DEFAULT 'STATUS'` also corrected to `'TFM_STATUS'` (CREATE + guarded convergence ALTER). Deployed and verified on the local DB: 7/7 rows TFM_STATUS. |
| F2 | `db/tools/check_column_dictionary.sql` asserted only column presence and STG/TFM contract indexes — not the full accepted dictionaries (status NOT NULL/DEFAULT, the DMT_LOG_TBL / DMT_WORK_QUEUE_TBL contract indexes, named FKs, identity PKs). A checker that silently checks less than the rule it enforces is how drift re-enters. | **FIXED NOW**: checker extended — (a) infra contract indexes DMT_LOG_TBL (RUN_ID, QUEUE_ID) and DMT_WORK_QUEUE_TBL (RUN_ID, WORK_STATUS, NEXT_POLL_AFTER); (b) STG_STATUS/TFM_STATUS VARCHAR2(30) DEFAULT 'NEW'/'STAGED' NOT NULL; (c) named-FK presence tally (SCENARIO_ID / RUN_ID / STG_SEQUENCE_ID / FBDI_CSV_ID); (d) identity-PK check with explicit SANCTIONED-DEFERRAL lines (the accepted identity rule schedules per-object conversion during stage ports). Everything the dictionary states that the script deliberately does not check now prints an explicit `NOT CHECKED: <item>` line with the reason. What the extended checker found was then fixed where the accepted rules demand and it is mechanically safe: DMT_LOG_TBL gained the decided QUEUE_ID column (section 5, nullable, no FK by design) plus DMT_LOG_N1 (RUN_ID) / DMT_LOG_N2 (QUEUE_ID); DMT_WORK_QUEUE_TBL gained DMT_WORK_QUEUE_N1 (NEXT_POLL_AFTER); 97 STG files and 25 TFM files gained NOT NULL on their status columns (CREATE updated + guarded ALTER; NULL-status backfill included in the guard — the local DB had **0 NULL status rows** in all 195 tables, so nothing was backfilled). Named FKs were **not** added/renamed here: SYS_C names are environment-generated so committed files cannot reference them, and the fix spans ~140 table files — reported by the checker as `NOT CHECKED -> TRACKED: F5`. |
| F3 | 79 `dmt_v_*_detail` views carried the compatibility alias `RUN_ID AS INTEGRATION_ID` — banned outright by the accepted no-compatibility-aliases rule (owner ruling 2026-07-08 explicitly rejected view-only aliases). | **FIXED NOW**: alias removed from all 79 detail views (select list + column header + stale mojibake'd comments). The only consumers are the archived APEX export — **the Stage F APEX port must bind its interactive reports to RUN_ID**. Non-detail views (DMT_RECORD_DETAIL_V, DMT_PIPELINE_SUMMARY_V, DMT_ESS_JOB_DETAIL_V, DMT_V_CEMLI_STATUS, DMT_CONVERSION_MASTER_TBL) still carry the alias and are the Stage F / legacy-surface sweep — out of this finding's scope, listed here so it is not lost. |
| F4 | All 112 view files used `CREATE OR REPLACE FORCE` — the accepted no-FORCE rule (2026-07-08) bans it because FORCE converts hard failures into silently-invalid objects. | **FIXED NOW**: FORCE removed from 97 view files. The 15 exceptions are the tracked-broken INTEGRATION_ID-drifted summary views that cannot compile until their Stage F repair (docs/tranche-reviews/2026-07-07-views.md finding F1(rest)): DMT_CFG_GL_CALENDAR_V, DMT_CFG_PAY_TERMS_V, DMT_CFG_PAY_TERM_LINES_V, DMT_CFG_TAX_RATES_V, DMT_CFG_TAX_REGIMES_V, DMT_CFG_UOM_V, DMT_CFG_VALUE_SETS_V, DMT_CFG_VS_VALUES_V, DMT_GL_BUDGET_V, DMT_GRANTS_V, DMT_MST_BANKS_V, DMT_MST_BANK_ACCTS_V, DMT_MST_BANK_BRANCHES_V, DMT_MST_ITEMS_V, DMT_MST_ITEM_CATS_V. Each carries an inline comment naming the tracked item. Install verified to complete with the invalid-object baseline unchanged. |
| F5 | ~78 SYS_C-named scenario FKs and 202 missing scenario/lineage FKs across STG/TFM tables (accepted explicit-naming rule + dictionary named-FK requirement). | **TRACKED — F5 unnamed-FK sweep**: its own work item (the naming-conformance sweep of the accepted constraints/indexes rule). Needs dictionary-driven guarded blocks (find-by-columns, rename/add) across ~140 table files; the extended checker reports the tally on every run so it cannot be forgotten. The leftover legacy index names outside the supplier family (DMT_LOG_TBL_N2/N3, DMT_WQ_*_IX) ride with the same sweep. |
| F6 | Mojibake (`â€`, `Ã`) persists in COMMENT literals in table files (accepted no-mojibake rule includes a pre-commit check that does not exist yet). | **TRACKED — F6 mojibake sweep + pre-commit check**: existing work item from the tables-tranche review. Five mojibake'd comment lines in the supplier detail views were incidentally deleted by F3. |
| F7 | Supplier BIP artifacts are not yet Contract v1 (names, four standard parameters, seven-column response). | **TRACKED — "Suppliers Contract v1 report rework"** (suppliers-review H6/H7): scheduled before Wave-1 reconciliation reuse. |
| F8 | The error-code contract (procedures-only rule) has no documented carve-out for the ported utility/object packages that predate it. | **TRACKED — exception-contract carve-out documentation**: the open owner decision from Stage B (utility layer) and suppliers review H10. Needs an owner ruling recorded in the design doc, then either retrofit or a listed exception. |
| F9 | The upload package's ingestion entry points still violate the structural scenario guard (accepted 2026-07-08: scenario bound in the creating INSERT, never key-range-stamped afterwards). | **TRACKED — upload-package scenario guard**: existing work item from the common-utility review; the checker prints it as a NOT CHECKED code-path line. |
| F10 | Retired objects still present on converged databases (retired prefix objects, retired submit procs, retired supplier sequences, unreferenced summary views). | **TRACKED — retired-object drops**: the committed `db/tools/drop_retired_*.sql` / `drop_unreferenced_summary_views.sql` scripts are the work item; execution is scheduled with the Stage F usage check for the view family. |
| F11 | The ten supplier table files carried two index-numbering schemes in flight ({stem}_TBL_N* from the snapshot and {stem}_N* from the conformance tranche), colliding at N1 with different columns (e.g. DMT_POZ_SUPPLIERS_STG_TBL_N1 on STG_STATUS vs DMT_POZ_SUPPLIERS_STG_N1 on SCENARIO_ID). | **FIXED NOW**: renumbered to the single clean per-table sequence used by every other object table — STG: N1 (STG_STATUS), N2 (SCENARIO_ID); TFM: N1 (RUN_ID), N2 (RUN_ID, TFM_STATUS), N3 (FBDI_CSV_ID), N4 (STG_SEQUENCE_ID), N5 (RECON_KEY). Old non-conforming names are dropped via guarded blocks in each table's own file; verified on the local DB (35 conforming indexes, zero `_TBL_N%` leftovers). |
| F12 | One DMT_CEMLI_CATALOG_TBL seed row (ARReceipts — REST, deliberately built last) carried STATUS_COLUMN NULL. | **FIXED NOW**: set to TFM_STATUS in the MERGE-converging catalog seed (a NULL becomes malformed engine SQL the day the object's TFM table lands). Deployed and verified: zero catalog rows with STATUS_COLUMN not TFM_STATUS. |

## Proposed rules (added IN RED to DMT_DESIGN.html section 7 PROPOSED block)

1. **Checker fidelity** — a conformance script must check everything its rule states or
   print an explicit NOT CHECKED line per omission.
2. **Seed identifiers resolve at the gate** — every identifier a seed row names
   (table, column, procedure) is resolved against the dictionary as a regression-gate
   assertion; F1 was exactly an unresolved seed identifier.
3. **Sweeps fix what they touch** — a mechanical sweep that edits a file fixes every
   in-scope violation in that file; a sweep that renames a column but leaves the seed
   naming the old column has not finished.
4. **One normative definition site** — each contract (dictionary, index list, status
   set) is stated normatively in exactly one place and referenced everywhere else.

## Gate results (this remediation)

- Extended checker: 195 tables + 2 infra tables, 197 PASS / 0 FAIL; 184 identity
  SANCTIONED-DEFERRAL lines; FK tally 108 named / 78 SYS-named / 202 missing ->
  TRACKED F5; 8 explicit NOT CHECKED lines. Exit success.
- `--fresh` rebuild + second install: recorded in the PR body.
- Unit suites (8, live included) + supplier golden: recorded in the PR body.

## RE-REVIEW verdict (2026-07-09): PASS — conformance tranche CLOSED
All six fix-now findings (F1,F2,F3,F4,F11,F12) confirmed fixed correctly in committed
files AND on the deployed dmt2-local DB. Extended checker 197/197 with honest NOT-CHECKED
disclosure. Previously-hidden violations (nullable status columns, missing DMT_LOG_TBL
RUN_ID/QUEUE_ID + DMT_WORK_QUEUE NEXT_POLL_AFTER indexes, missing QUEUE_ID column) genuinely
fixed. FORCE/alias removals compile clean — the only invalid views are the 15 tracked-broken
INTEGRATION_ID-drifted views (each commented). Both seeds converge, zero duplicate keys.
Deferrals F5-F10 recorded. 4 new red rules present with example boxes.
Two non-blocking residues logged for later: (a) catalog seed MERGE matches on
(CEMLI_CODE, NVL(TFM_TABLE)) while the unique key is (CEMLI_CODE, SORT_ORDER) — converges
today, tighten when next touched; (b) the proposed "one normative definition site" red rule,
if accepted, is in tension with the checker header restating the dictionary — resolve at
promotion. NEXT: owner gate — full live supplier rerun (all five objects, Rule #1 per object)
before Wave 1.
