# DMT2 §12 Backlog Reclass Audit — 2026-09-16

Read-only audit of every P1/P2/P3 item in section 12 of `docs/DMT_DESIGN.html`, cross-checked against the live repo (`db/`, `scripts/`) and recent merges (PRs through #244). Each embedded "PROPOSED/VERIFIED DONE" annotation in the design doc was independently confirmed (or refuted) by grepping the code; verdicts below reflect the *repo as it stands today*, not the doc's self-report.

Legend for verdicts: **RESOLVED** = fix is in the tree and confirmed; **PARTIAL** = core landed, follow-up remains; **STILL OPEN** = not started or only decided; **STALE/OBSOLETE** = superseded / parked, no action wanted.

## Summary table

| # | Item | Priority | Verdict | Cost | Risk |
|---|------|----------|---------|------|------|
| 1 | Converge base DDL to RUN_ID model | P1 | RESOLVED | 1 | 1 |
| 2 | Full install script (db_full/) | P1 | STALE/OBSOLETE | 1 | 1 |
| 3 | Consolidate the prefix mechanism | P1 | RESOLVED | 1 | 1 |
| 4 | One DMT_FBDI_CSV_TBL row per physical CSV | P1 | RESOLVED | 1 | 1 |
| 5 | Port the Customer FBDI batch-import fix | P1 | RESOLVED | 1 | 1 |
| 6 | Batch/group-id passthrough + partition (PO/GL/REQ/Items) | P1 | RESOLVED | 1 | 1 |
| 7 | Reconcile registered in two places / fail-open | P1 | PARTIAL | 4 | 5 |
| 8 | Move per-object logic out of run_one_object_type | P1 | STILL OPEN | 9 | 8 |
| 9 | Full-fidelity scenario upload (multi-CSV zip) | P1 | STILL OPEN | 8 | 5 |
| 10 | Funnel metrics view + Object Detail redesign | P2 | PARTIAL | 5 | 3 |
| 11 | Reconcilers reach LOADED without capturing Fusion id | P2 | STILL OPEN | 5 | 4 |
| 12 | Every object inject a run-scoped batch id | P2 | STILL OPEN | 7 | 6 |
| 13 | ALL-mode transform bypasses pre-validation | P2 | STILL OPEN | 3 | 5 |
| 14 | Build the stage→transform error table | P2 | PARTIAL | 5 | 4 |
| 15 | Fold config objects into queue + retire runners/ | P2 | RESOLVED-EXCEPT-GLCalendar | 6 | 6 |
| 16 | Catalog-driven queue dispatch | P2 | RESOLVED | 7 | 7 |
| 17 | Retire GLBudgets↔GLBudgetBalances dual identity | P2 | RESOLVED | 1 | 1 |
| 18 | Retire 1099Invoices as a separate object | P2 | RESOLVED | 1 | 1 |
| 19 | Convert cross-object key refs to DMT_XREF_PKG | P2 | PARTIAL | 5 | 4 |
| 20 | Fold FETCH_BIP_RESULTS into RUN_BIP_REPORT | P2 | STILL OPEN | 5 | 4 |
| 21 | Conform 25 recon reports to Contract v1 | P2 | STILL OPEN | 7 | 5 |
| 22 | Contract v1 reports for 14 HDL objects | P2 | STILL OPEN | 7 | 4 |
| 23 | Add BASE tiers to 15 interface-only recon reports | P2 | PARTIAL | 6 | 5 |
| 24 | Fix illegal upstream STG_STATUS='LOADED' check | P2 | RESOLVED | 2 | 2 |
| 25 | Naming conformance sweep | P2 | STILL OPEN | 5 | 3 |
| 26 | Rename work status VALIDATING → PROCESSING | P2 | STILL OPEN | 3 | 4 |
| 27 | Centralize [RECONCILE_ERROR] unmatched-row sweep | P2 | PARTIAL | 3 | 3 |
| 28 | Shared DMT_IMPORT_REPORT_PKG.APPLY_ERRORS | P2 | STILL OPEN | 3 | 3 |
| 29 | Implement outcome-based tile palette | P2 | STILL OPEN | 4 | 2 |
| 30 | Log attribution + Activity Log browser | P2 | STILL OPEN | 6 | 3 |
| 31 | 73 invalid views bound to dropped columns | P2 | PARTIAL | 3 | 3 |
| 32 | Items ORA-01427 reconciler bug | P2 | RESOLVED | 1 | 1 |
| 33 | Expenditures loader hardcodes a BU | P2 | RESOLVED | 1 | 1 |
| 34 | Assignment HDL generator hardcodes a BU | P2 | RESOLVED | 1 | 1 |
| 35 | Assets loader hardcodes a book type | P2 | RESOLVED | 1 | 1 |
| 36 | Config holds instance IDs by number not name | P2 | STILL OPEN | 5 | 5 |
| 37 | Enforce mandatory scenario on ingestion paths | P2 | STALE/OBSOLETE | 3 | 2 |
| 38 | Remove cancellation (CANCEL_RUN) | P3 | STILL OPEN | 3 | 4 |
| 39 | Banks to REST | P3 | STILL OPEN | 6 | 3 |
| 40 | Delete abandoned adaptor stubs | P3 | RESOLVED | 1 | 1 |
| 41 | Eliminate standalone procedures | P3 | PARTIAL | 5 | 5 |
| 42 | Standardize validator entry points | P3 | STILL OPEN | 4 | 4 |
| 43 | Split supplier transform/reconciler pkgs per object | P3 | STILL OPEN | 5 | 5 |
| 44 | Mode-driven selection predicates; retire RETRY | P3 | STILL OPEN | 6 | 6 |
| 45 | Document prefixed business key(s) per object | P3 | STILL OPEN | 2 | 1 |
| 46 | Eliminate runtime EXECUTE IMMEDIATE | P3 | STILL OPEN | 5 | 6 |
| 47 | Replace LIKE-matching with equality | P3 | STILL OPEN | 2 | 3 |
| 48 | Complete validator tag adoption | P3 | STILL OPEN | 4 | 2 |
| 49 | Verify Run Pipeline screen against spec | P3 | STILL OPEN | 2 | 1 |
| 50 | Dashboard redesign | P3 | STILL OPEN | 4 | 2 |
| 51 | CSV upload E2E verification (Pages 2–12) | P3 | STILL OPEN | 3 | 1 |
| 52 | Delete superseded APEX pages | P3 | STILL OPEN | 2 | 2 |
| 53 | Rename APEX *_INTEGRATION_ID → *_RUN_ID | P3 | STILL OPEN | 3 | 3 |
| 54 | Remove files table from ESS Job Detail | P3 | STILL OPEN | 3 | 2 |
| 55 | 2 invalid package bodies (INIT / REST_LOADER) | P3 | RESOLVED | 1 | 1 |
| 56 | Retire superseded docs | P3 | STILL OPEN | 4 | 1 |
| 57 | Browser-verify Page 82 tile grid | P3 | STILL OPEN | 2 | 1 |
| 70 | Partitioned-object run-detail tiles misreport load/import IDs + parent placeholder | P1 | STILL OPEN | 4 | 3 |

**Counts by priority**

| Priority | RESOLVED | PARTIAL | STILL OPEN | STALE/OBSOLETE | Total |
|----------|----------|---------|------------|----------------|-------|
| P1 | 5 | 1 | 3 | 1 | 10 |
| P2 | 10 | 5 | 11 | 1 | 27 |
| P3 | 3 | 1 | 17 | 0 | 21 |
| **All** | **18** | **7** | **31** | **2** | **58** |

(Items 15 and 16 moved out of STILL OPEN on 2026-09-21. Item 16 is RESOLVED;
item 15 is RESOLVED-EXCEPT-GLCalendar — counted here under RESOLVED, with the one
deferred GLCalendar wiring noted in its detail below.)

---

# P1 items

## 1. Converge base DDL to the RUN_ID model — P1
**Verdict: RESOLVED.**
**Proof:** The migration script `phase1_pipeline_redesign.sql` is absent from the entire repo (grep across `db/` returns zero matches). `DMT_WORK_QUEUE_TBL` and `DMT_CEMLI_SPLIT_CFG` are first-class table files wired into `db/install.sql`; the redesigned tables carry their full post-migration column set inside the `CREATE` (no bare migration `ALTER ADD`). The four run-detail views are committed git files. A fresh `--fresh` install replays clean from committed files. Git is the sole source of truth.
**Cost 1 / Risk 1** — nothing to do; verify-only.

## 2. Full install script (db_full/) — P1
**Verdict: STALE/OBSOLETE.**
`db_full/` is a full snapshot of the *frozen* ConversionTool predecessor schema, kept for reference only. Owner decision 2026-07-13: **PARKED, no adoption**; DMT2 develops on its own `db/install.sql`. The remaining "re-snapshot / schema-compare / merge branch / close issue #31" steps are explicitly not to be done.
**Cost 1 / Risk 1** — remove from active backlog; reference artifact only.

## 3. Consolidate the prefix mechanism — P1
**Verdict: RESOLVED.**
**Proof:** Only `DMT_RUN_PREFIX_SEQ` exists; the old `DMT_PREFIX_SEQ` and dead `DMT_PREFIX_MASTER_TBL` survive only in the standalone `db/tools/drop_retired_prefix_objects.sql` cleanup (correctly not in `install.sql`). Dead per-CEMLI prefix functions removed. Dependent-prefix picking works off `DMT_PIPELINE_RUN_TBL.PREFIX` keyed by RUN_ID. `db/views/dmt_prefix_history_v.sql` (`DMT_PREFIX_HISTORY_V`) is built and wired into install.
**Cost 1 / Risk 1.**

## 4. One DMT_FBDI_CSV_TBL row per physical CSV file — P1
**Verdict: RESOLVED** (core + phase-2 column drop, PR #53).
**Proof:** CSV is now a child of ZIP via `DMT_FBDI_CSV_TBL.FBDI_ZIP_ID` + `FILE_SEQ`; shared `DMT_UTIL_PKG.REGISTER_CSV` + `BUILD_ZIP_FROM_CSVS` persist one row per physical CSV and build the zip from persisted `CSV_CONTENT`. All 23 FBDI generators converted; phase-2 dropped `DMT_FBDI_ZIP_TBL.FBDI_CSV_ID` (guarded) and removed the dead `DMT_FBDI_ZIP_CSV_FK` stanza. Proven live (Requisitions/GLBalances/Customers).
**Cost 1 / Risk 1.**

## 5. Port the Customer FBDI batch-import fix — P1
**Verdict: RESOLVED** (live 2026-07-12).
**Proof:** Load job corrected to `CDMAutoBulkImportJob` (auto-creates the import batch) not `BulkImportJob`; object ParameterList arg is the code `CUSTOMER`. Generator `p_batch_id` filter + loader partition by `(BATCH_ID, Source System)` with the 4-value ParameterList; transform passthrough of `BATCH_ID` and every `*_ORIG_SYSTEM`; reconciler BIP keyed on run prefix (removed the `orig_system='DMT'` hardcode). GOOD customers confirmed in `HZ_CUST_ACCOUNTS`, BAD rows reportable from `HZ_IMP_ERRORS`.
**Cost 1 / Risk 1.** (Residual follow-up "regenerate Customers golden" is trivial data maintenance.)

## 6. Batch/group-id passthrough + partition for PO/GL/REQ/Items — P1
**Verdict: RESOLVED** (Customers + GL + Requisitions + PurchaseOrders + Items all proven live 2026-07-13).
**Proof:** Requisitions carries `NVL(s.BATCH_ID, run_id)` and partitions by header BATCH_ID (one FBDI + one Import Requisitions ESS run per batch); GOOD requisitions in `POR_REQUISITION_HEADERS_ALL`. PO partitions by Procurement BU (Import Orders leaves arg 5 blank); GOOD POs in `PO_HEADERS_ALL` (674875/674876). Items grouped by BATCH_ID; Item Master in `EGP_SYSTEM_ITEMS_B`, categories in `EGP_ITEM_CATEGORIES`. GLBalances already partitioned per-ledger.
**Cost 1 / Risk 1.** Note: the *harness* mis-flag of grouped child rows is tracked separately (item 11 area / regression evaluator, still open).

## 7. Reconcile is registered in two places and can silently reconcile nothing — P1
**Verdict: PARTIAL.**
**Proof (guard landed):** The fail-open guard is confirmed in the tree at `db/packages/dmt_loader_pkg.pkb.sql:1369`:
```sql
RAISE_APPLICATION_ERROR(-20044,
    'No reconcile arm matched CEMLI_CODE ''' || p_cemli_code ||
    ''' in submit_and_reconcile_one. Refusing to report success without ...
```
An unregistered CEMLI can no longer fall through to `x_success := TRUE`; the object goes to ERROR instead of a false pass.
**What still remains (plain):** There are still two lists of "how to reconcile each object" that a developer must keep in sync by hand. The immediate safety hole (a silent false "success") is plugged, but the underlying duplication is not — a mismatch now produces a loud error rather than a silent lie, but it's still a mismatch.
**Developer detail:** The queue path reads `RECON_PROC` from `DMT_PIPELINE_DEF_TBL` and invokes it dynamically, while partitioned objects run a hardcoded `ELSIF` chain over CEMLI codes inside `submit_and_reconcile_one`. For partitioned objects the registry `RECON_PROC` is decorative. The durable fix (drive the per-partition reconcile from `RECON_PROC` too — single dispatch) is deferred to the catalog-driven dispatch item (16).
**Suggested fix:** Fold into item 16; make `RECON_PROC` the single source and delete the ELSIF chain.
**Cost 4 / Risk 5** — touches the shared loader's reconcile dispatch for every partitioned object.

## 8. Move all per-object pipeline logic out of run_one_object_type — P1
**Verdict: STILL OPEN.**
**What it is (plain):** The tool has one giant central engine function that "knows" the individual steps for every object type inline. Adding or changing one object means editing this shared engine in many spots, which is error-prone and is the root cause of the drift bugs elsewhere in this backlog. The goal is to make each object own its own recipe so the engine just calls it.
**Developer detail:** `run_one_object_type` spans `db/packages/dmt_loader_pkg.pkb.sql:1037–3638` (~2,600 lines) and carries ~10 hardcoded per-CEMLI ladders (validate, transform, generate CSVs, build zip, submit ESS, mark load failures, reconcile). One object's logic is spread across ten ladders. Example of the anti-pattern (thin wrappers still name objects as literals into the monolith):
```sql
l_dummy := run_one_object_type(p_run_id, 'Suppliers', v_scenario_id, p_run_mode, p_skip_bu_refresh);
...
l_dummy := run_one_object_type(p_run_id, 'PurchaseOrders', v_scenario_id, p_run_mode, p_skip_bu_refresh);
```
**Impact:** Cross-object drift (the C1–C3 divergences), and every new object requires editing ten shared ladders — the structural cause of items 7, 16, 17, 18.
**Suggested fix:** Give each object package a single `RUN(p_run_id, ...)` entry point that does all sub-steps; register it in the object's registry row (`EXEC_PROC` pattern) and invoke via the one dynamic call the queue worker already uses. Removes all IF/THEN literals.
**Cost 9 / Risk 8** — the biggest structural refactor in the backlog; touches every object and the shared engine.

## 9. Full-fidelity scenario upload — multi-CSV zip per object — P1
**Verdict: STILL OPEN.**
**What it is (plain):** The current spreadsheet upload only captures the top-level record for each object (a supplier's name, an invoice header) and drops all the child detail (a supplier's addresses, sites, contacts; PO lines and distributions). A scenario reloaded through it comes back degraded and re-breaks Suppliers/Customers/PO. We need an upload that accepts a full zip — one CSV per staging table — so a regression scenario can be loaded once at full fidelity.
**Developer detail:** The DMC upload feature (`DMC_Upload_Feature_DDL.sql` / `DMC_Upload_File_Specs.md`, which live in the workspace root, not committed under `db/`) is a thin one-table-per-object loader writing only header STG tables. It omits child hierarchies and required fields (`BUSINESS_RELATIONSHIP`/`SPEND_AUTHORIZED`, `PARTY_ORIG_SYSTEM=LEG1`, `SHIP_TO_LOCATION`, …). No code in `db/` implements the multi-CSV STG-schema zip described.
**Impact:** Blocks the "insert STG once, lock, re-run by prefix" workflow — every re-run needs a fresh full reload.
**Suggested fix:** Extend the upload to accept a single zip containing one header-bearing CSV per STG table (filename = object/table, header row = STG column names). STG-schema, not position-based FBDI. Must cover all 43 objects and every child table.
**Cost 8 / Risk 5** — large UI/upload feature; low blast radius on existing pipeline code but touches every object's STG contract.

## 70. Partitioned-object run-detail tiles misreport load/import IDs and don't distinguish the parent placeholder — P1
**Verdict: STILL OPEN.**
**What it is (plain):** On the run-detail screen, an object that *partitions* — one that spawns one child work item per partition key (for example Items or Customers by `BATCH_ID`, or GL by Ledger) — is drawn as a row of tiles that misrepresents what actually ran. Observed on run 138. Three things are wrong.
**Developer detail:**
1. **The parent placeholder tile shows a load ID and an import ID it should not have.** The first tile is the partition *parent* (the coordinator); it does not itself submit an ESS load or import job — those belong to the child partitions — so it must not display a load or import request ID.
2. **The parent tile is not visually distinguished from the real load tiles.** It should render as a parent placeholder (the partition coordinator), visibly different from the child partition tiles, and it should show *what* it partitioned on (the partition key and the set of partition values), since surfacing that is the parent's actual role.
3. **Every child partition tile shows the SAME load and import IDs, which is impossible.** Each partition is its own separate ESS load job plus import job with distinct request IDs. Every child tile currently shows identical load/import IDs; each must show its own distinct load and import request ID, and should indicate which partition it ran (the partition value, e.g. `BATCH_ID=5001`).

**Required end state:** the run-detail UI for a partitioned object shows — (1) on the parent tile, what it partitioned on and that it is a parent placeholder with NO load/import ID; (2) on each child tile, which partition it ran; (3) each child's correct, distinct load and import request IDs.
**Likely touch points (pointers, not a fix):** the run-detail view/records source (`DMT_RUN_RECORDS_V` / `DMT_RECORD_DETAIL_V`) and the run-detail APEX page tiles (p52/p57), plus how parent-vs-child work items and their per-child ESS job IDs are surfaced from `DMT_WORK_QUEUE_TBL` / `DMT_ESS_JOB_TBL`.
**Cost 4 / Risk 3** — UI plus view plumbing across the run-detail tiles and the work-item/ESS-job join; medium.

---

# P2 items

## 10. Funnel metrics view + Object Detail redesign — P2
**Verdict: PARTIAL** (view done 2026-07-16; UI half open).
**Proof (view):** `db/views/dmt_object_funnel_v.sql` (`DMT_OBJECT_FUNNEL_V`) is built, deployed VALID, validated against real runs — one row per `(RUN_ID, CEMLI_CODE, SUB_OBJECT)` with the full funnel column set. Built on `DMT_OBJECT_DETAIL_V` FULL-OUTER-joined to the two `DMT_STG_TFM_ERROR_TBL` lanes, anti-joined to `DMT_RECORD_DETAIL_V` (no double-count).
**Still open:** the APEX Object Detail region rebuild to the approved mock-ups. `TRANSFORM_FAILED` reads 0 until the transform-stage error wiring (item 14) lands.
**Cost 5 / Risk 3** — UI work; the DB dependency is satisfied.

## 11. Reconcilers that reach LOADED without capturing the Fusion id — P2
**Verdict: STILL OPEN** (proposed 2026-07-16).
**What it is (plain):** When an object loads successfully we should record the Fusion-generated ID for each row, so we can prove exactly which record went where. Roughly 15 reconcilers do this; the rest mark a row "loaded" without saving the ID, which weakens the audit trail.
**Developer detail:** The `FUSION_%_ID` TFM column exists on 97/98 tables. Not writing it: Assets (`dmt_fa_asset_results_pkg`'s report returns `fusion_id` but never writes `FUSION_ASSET_ID`), GLBudgets, Items, Expenditures, BillingEvents, ProjectBudgets, MiscReceipts lot/serial children, and the remaining HDL objects.
**Impact:** LOADED rows without a captured base-table id — reconciliation can't point to the exact Fusion record; prerequisite gap for bulk BIP reconciliation.
**Suggested fix:** For each, make the recon BIP report return the base-table id and add it to the `SET` clause of the reconciler's LOADED update (or the HDL `LOOKUP_FUSION_IDS` cursor). Add a conformance check that fails a reconciler writing `TFM_STATUS='LOADED'` without a `FUSION_%_ID` assignment. Start with Assets.
**Cost 5 / Risk 4** — per-object, mechanical but many packages.

## 12. Every object must inject a run-scoped batch id — P2
**Verdict: STILL OPEN** (proposed 2026-07-17).
**What it is (plain):** Today most objects tell their own run's records apart only by sticking the run prefix onto a business key (a supplier name, PO number). That's fragile — it collides when two records share a key and breaks when Fusion renumbers. Every object should stamp a proper run-scoped batch id onto each record it sends, landing in a queryable Fusion column.
**Developer detail:** Only GLBalances (`RECON_KEY` → `GL_INTERFACE.REFERENCE21`) and the PurchaseOrders family (run-scoped `INTERFACE_HEADER_KEY`) stamp a batch id independent of the business key; several objects stamp nothing run-scoped (ProjectBudgets, GLBudgets, MiscReceipts, SalaryBases). The near-universal `RECON_KEY` TFM column is populated by GLBalances alone.
**Impact:** Reconciliation matches on a fragile prefixed-business-key instead of an exact key; blocks bulk HDL BIP reconciliation (item 22).
**Suggested fix:** Inject RUN_ID / run PREFIX / a SourceSystemId embedding the run id onto each record, landing in a queryable Fusion column. Centralize the per-object recon-key→Fusion-landing-column map.
**Cost 7 / Risk 6** — touches each object's generator/transformer/reconciler.

## 13. ALL-mode transform bypasses pre-validation rejections — P2
**Verdict: STILL OPEN** (proposed 2026-07-16).
**What it is (plain):** When a run is done in "ALL" mode, a record that pre-validation already rejected still gets transformed and sent onward — so in that mode pre-validation is effectively ignored. It works correctly in NEW mode.
**Developer detail:** Pre-validation marks a row FAILED and writes a `[PRE_VALIDATION]` error row, but the transform's ALL-mode predicate (`p_run_mode='ALL'`, no STG-status filter) re-reads and transforms that same row. Confirmed on AR run 167: identical STG ids in both the pre-validation error rows and the AR Lines TFM rows. The funnel view compensates (counts once as transformed), but the behavior stands.
**Impact:** Pre-validation is toothless in ALL/FAILED mode — a known-bad row can still reach Fusion.
**Suggested fix:** The transform's ALL/FAILED predicates must exclude rows that have a `[PRE_VALIDATION]` error row for this run (or whose STG status is FAILED this run).
**Cost 3 / Risk 5** — small predicate change but in the shared transform selection path (affects every object).

## 14. Build the stage→transform error table (DMT_STG_TFM_ERROR_TBL) — P2
**Verdict: PARTIAL** (table exists; wiring in progress).
**Proof:** `DMT_STG_TFM_ERROR_TBL` exists (foundation build) and is consumed by the funnel view; Suppliers validators wired first (`dmt_poz_sup_validator_pkg.pkb.sql` references it).
**Still open (plain):** the full rollout — each validator/transformer must write this table with the right `[PRE_VALIDATION]`/`[TRANSFORM_ERROR]` tag, and the per-package `FLAG_STG_FAILED` helper generalized beyond Suppliers. `TRANSFORM_ERROR` transform-stage wiring not done; `QUEUE_ID` stays NULL for validator-written rows until work-item context is threaded down.
**Suggested fix:** Roll the fixed-shape INSERT + `FLAG_STG_FAILED` helper across the remaining validators, then the transformers.
**Cost 5 / Risk 4** — many packages; prerequisite for the funnel's TRANSFORM_FAILED lane.

## 15. Fold config objects into the queue + retire packages/runners/ — P2
**Verdict: RESOLVED-EXCEPT-GLCalendar** (2026-09-21).
**What it changed (plain):** Six of the nine "runner" packages were never dead — they are the live queue path for six config objects, dispatched by a registry row, not manual SQL. Three runners really were dead and are now deleted. One config object (GLCalendar) is deliberately left un-wired for now.
**Proof — six runners are LIVE (queue-wired via EXEC_PROC in `db/seed/dmt_pipeline_def_tbl.sql`):** ValueSets → `DMT_FND_VS_RUNNER_PKG.RUN_STANDARD` (line 199), Lookups → `DMT_FND_LOOKUP_RUNNER_PKG.RUN_STANDARD` (line 201), UnitsOfMeasure → `DMT_INV_UOM_RUNNER_PKG.RUN_STANDARD` (line 202), PaymentTerms → `DMT_AP_PAY_TERM_RUNNER_PKG.RUN_STANDARD` (line 203), TaxConfig → `DMT_ZX_RUNNER_PKG.RUN_STANDARD` (line 204), CashBanks → `DMT_CE_BANK_RUNNER_PKG.RUN_STANDARD` (line 209). These are dispatched (LOCAL exec mode) through `DMT_QUEUE_WORKER_PKG.EXECUTE_ONE`, so they run in the normal queue with Run History and accounting — no manual SQL.
**Proof — three runners were DEAD and are deleted:** `DMT_EGP_ITEM_RUNNER_PKG`, `DMT_EGP_ITEM_CAT_RUNNER_PKG`, `DMT_GL_CALENDAR_RUNNER_PKG` had zero callers (grep across `db/`, `scripts/`, `apex/`, `test/` found only their own files, the `db/install.sql` `@@` lines, and README/backlog prose) and no EXEC_PROC row referenced them. Their six `.pks`/`.pkb` files are removed, their `@@` lines removed from `db/install.sql`, and they are dropped on the DB by the committed migration `db/migrations/2026-09-21_drop_dead_config_runner_packages.sql`. After the drop, DMT_OWNER shows 0 invalid objects — nothing depended on them. No package was orphaned: the Items-family support packages the two item runners called are still used by the live `DMT_LOADER_PKG.RUN_ITEMS` path, and the GLCalendar support packages are retained as the deferred object's own code.
**Still open (the one exception):** GLCalendar is intentionally NOT queue-wired yet — its EXEC_PROC stays NULL (`db/seed/dmt_pipeline_def_tbl.sql` line 199, with an explanatory comment). Its validator/transform/FBL-gen/results packages exist but are unproven, and accounting calendars have no automated Fusion load (manual setup in Setup and Maintenance). Wiring it requires a proven live config run first.
**Cost 6 / Risk 6** — done except the GLCalendar wiring, which needs a live run.

## 16. Catalog-driven queue dispatch — P2
**Verdict: RESOLVED** (re-confirmed 2026-09-21; the earlier "STILL OPEN" was stale).
**What it is (plain):** Adding a new object no longer means editing a big decision block in the queue worker. Each object is one row in a registry table, and dispatch is a lookup plus a dynamic call.
**Proof:** The registry table is `DMT_PIPELINE_DEF_TBL`, seeded one row per object in `db/seed/dmt_pipeline_def_tbl.sql` — each row carries EXEC_PROC / EXEC_MODE / RECON_PROC / RECON_HAS_CEMLI_ARG / PARTITION_KEYS_PROC (the run procedure, post-run reconcile, and partition function). `DMT_QUEUE_WORKER_PKG.EXECUTE_ONE` dispatches by reading that row (`get_dispatch`) and calling the registered procedure (`invoke_registered`) — there is no per-object CASE/ELSIF chain in the dispatch path. Reconcile dispatch is likewise registry-driven (RECONCILE_VIA_REGISTRY reads RECON_PROC). Adding an object is a new seed row, not a code edit.
**Cost 7 / Risk 7** — was the enabler for items 7, 8, 15.

## 17. Retire the GLBudgets ↔ GLBudgetBalances dual identity — P2
**Verdict: RESOLVED** (2026-07-15).
**Proof:** No `GLBudgetBalances` reference remains in the loader (grep of `dmt_loader_pkg.pkb.sql` returns none). Runner passes `'GLBudgets'`, all nine loader arms/results package/generator use `GLBudgets`; BIP path repointed to `/Custom/DMT2/GLBudgets/`; `bip/GLBudgetBalances/` renamed to `bip/GLBudgets/`.
**Cost 1 / Risk 1.** (Residual: deploy the GLBudgets BIP DM+report to the new Fusion path when driven live — deployment task, not code.)

## 18. Retire 1099Invoices as a separate object — P2
**Verdict: RESOLVED** (merged into AP, 2026-07-15).
**Proof:** No `1099` packages remain (`ls db/packages/*1099*` → none); `RUN_1099` gone from the loader. `db/tools/drop_retired_1099_object.sql` exists so existing DBs converge. AP now processes all invoice types (removed the `NOT LIKE '%1099%'` exclusions in six views).
**Cost 1 / Risk 1.**

## 19. Convert cross-object key references to DMT_XREF_PKG — P2
**Verdict: PARTIAL** (PR #172).
**Proof:** `db/packages/dmt_xref_pkg.pkb.sql` is built and deployed; BillingEvents transformer resolves `PROJECT_NUMBER` through it.
**Still open (plain):** Every other transformer that still prefixes a *cross-object* reference (AP supplier/PO refs, AR customer refs, Requisitions, PO, Grants, Project-child refs) must convert to the matching `DMT_XREF_PKG` resolver; then retire `get_upstream_prefix`/`get_dep_prefix`. Own-key prefixing stays on `PREFIXED()`.
**Suggested fix:** Per-object PR, one transformer family at a time.
**Cost 5 / Risk 4** — many transformers; risk of mis-resolving a cross-object key.

## 20. Fold FETCH_BIP_RESULTS + bip_soap_post into shared RUN_BIP_REPORT — P2
**Verdict: STILL OPEN** (spec exists: `docs/soap_fetch_fold_spec.md`).
**What it is (plain):** 21 reconcilers each carry their own copy of the "call the BIP report over SOAP and fetch the result" plumbing. That should be one shared routine.
**Developer detail:** `DMT_UTIL_PKG.RUN_BIP_REPORT` exists and is already called at the drift-warning point (item that added the `/Custom/DMT/` warning), but the 21 reconcilers still carry inline `FETCH_BIP_RESULTS` + `bip_soap_post`. Not yet folded.
**Impact:** 21× duplicated SOAP plumbing — a fix must be applied 21 times.
**Suggested fix:** Migrate each reconciler to `DMT_UTIL_PKG.RUN_BIP_REPORT` per the spec; sequence before item 21 (fold centralizes fetch, then item 21 centralizes parse).
**Cost 5 / Risk 4.**

## 21. Conform the 25 reconciliation reports to Contract v1 — P2
**Verdict: STILL OPEN.**
**What it is (plain):** The reconciliation reports use inconsistent names and parameters. Standardize them to one contract — a common name pattern, six standard parameters, a seven-column response — so one generic parser can read them all.
**Developer detail:** Rename artifacts to `DMT_{OBJ}_RECON_*`, migrate off `P_BATCH_ID` to the six standard parameters (incl. keyset-pagination pair), return the seven-column response, add TFM `RECON_KEY`, build the generic parser + registry columns (`CONTRACT_VERSION` flag). Not started; sequence after item 20.
**Cost 7 / Risk 5** — Fusion-side artifact churn + per-object migration.

## 22. Contract v1 reports for the 14 HDL objects — P2
**Verdict: STILL OPEN.**
**What it is (plain):** The HCM/HDL objects don't yet have proper reconciliation reports that confirm rows landed in the Fusion base tables; a partial per-record REST lookup covers only 3. Build a base-tier report per HDL object.
**Developer detail:** Build a recon report per HDL object (business key + Fusion id from HCM base tables), register in the BIP registry, and update `DMT_HDL_UTIL_PKG.RECONCILE_HDL` to mark LOADED only on report confirmation; retire the partial 3-object `LOOKUP_FUSION_IDS` bulk path (the one-off Record Detail "Verify in Fusion" button is retained).
**Impact:** HDL objects can't be positively base-confirmed (Rule #1 gap).
**Cost 7 / Risk 4** — 14 new reports; depends on item 12 (run-scoped key).

## 23. Add BASE tiers to the 15 interface-only reconciliation reports — P2
**Verdict: PARTIAL** (PurchaseOrders/Suppliers family/BlanketPOs/Contracts/AP/Items/ItemCategories proven; ARInvoices blocked; 1099 folded into AP).
**Proof:** PurchaseOrders two-tier report proven live (PO_HEADERS_ALL, run 122, PR #57); Suppliers family all five base-confirmed (PRs #63/#65/#67/#69/#71); BlanketPOs/Contracts (PR #73); APInvoices (PR #75, base-joins `ap_invoices_all`); Items/ItemCategories (PR #74, base-join `egp_system_items_b`/`egp_item_categories`, incl. the `ITEM_CATEGORY_ASSIGNMENT_ID` column fix).
**Still open (plain):** ARInvoices is NOT base-proven — two code fixes done (removed the illegal customer-account pre-check; fixed fixture batch source to `PSFT Migration`) but base load is blocked by a demo-instance setting (consolidated billing enabled → AutoInvoice master refuses import). The AR two-tier report still falls back to interface status when the base row is absent; must derive LOADED purely from `ra_customer_trx_all.customer_trx_id`.
**Developer detail / owner action:** Owner decision requested — switch the AR import ESS job to the consolidated-billing-compatible process, or disable consolidated billing on the demo. AR code fixes held on an un-pushed branch (not yet a PR).
**Cost 6 / Risk 5** — mostly done; ARInvoices needs the demo-config unblock + report finalization.

## 24. Fix the illegal upstream STG_STATUS='LOADED' dependency check — P2
**Verdict: RESOLVED** (2026-07-15).
**Proof:** AP/AR/PO validators fixed pre-crash; the four that still had the live bug — `DMT_EXPENDITURE_VALIDATOR_PKG`, `DMT_BILLING_EVENT_VALIDATOR_PKG`, `DMT_PRJ_BUDGET_VALIDATOR_PKG`, `DMT_GRANTS_VALIDATOR_PKG` — now join the projects STG row to its `DMT_PJF_PROJECTS_TFM_TBL` row (1:1 by `STG_SEQUENCE_ID`) and require `pt.TFM_STATUS='LOADED'`. A latent grants prefixed-vs-raw-key bug was also fixed. All recompile VALID.
**Cost 2 / Risk 2.** (Live per-object proofs land when Expenditures/BillingEvents/ProjectBudgets/Grants are driven E2E.)

## 25. Naming conformance sweep — P2
**Verdict: STILL OPEN** (naming decisions closed; execution pending).
**What it is (plain):** A cleanup pass to make every registry use the canonical §1 object codes and view/file naming (`*_V` suffix, etc.). All the *decisions* are made; the edits aren't all applied.
**Developer detail:** Worklist in `DMT_OBJECT_CATALOG.html`: stray ItemCategories registry rows, MiscReceipts upload-registry filenames, unregistered Grants CSV, Lookups scheduler token, FBL objects absent from the CONFIGURATION sequence, HDL ZIP-name drift, `PayrollRels → PayrollRelationships`, NULL-CEMLI row in `DMT_ERP_INTERFACE_OPTIONS_TBL`, `DMT_V_* → *_V`, stale view header comments, keep-or-drop for orphaned `DMT_RCV_HEADERS`/`RCV_TRANSACTIONS`. (GLBudgets naming already done via item 17.)
**Cost 5 / Risk 3** — many small edits across seed/views; low individual risk.

## 26. Rename work status VALIDATING → PROCESSING — P2
**Verdict: STILL OPEN.**
**What it is (plain):** The work status labelled "VALIDATING" actually covers the whole data phase (validate, transform, generate, submit), so the name is misleading; rename it to "PROCESSING".
**Developer detail:** `VALIDATING` still appears in `dmt_queue_worker_pkg.pkb.sql` (grep hit). Rename in `DMT_QUEUE_PKG`/`DMT_QUEUE_WORKER_PKG`, the work-queue rows, and the APEX tile rendering.
**Impact:** Cosmetic/clarity, but touches status literals used across DB + UI.
**Cost 3 / Risk 4** — status-literal rename has moderate blast radius (any code comparing the literal).

## 27. Centralize the [RECONCILE_ERROR] unmatched-row sweep — P2
**Verdict: PARTIAL** (PROPOSED DONE 2026-07-15; HDL/config deferred).
**Proof:** 19 FBDI/base-confirming reconcilers now carry the byte-identical tagged `SWEEP_UNACCOUNTED` and call it at the end of `RECONCILE_BATCH` (confirmed `SWEEP_UNACCOUNTED` present across many `*_results_pkg`); conformance script `scripts/check_sweep_unaccounted.py` enforces it (PRs #121/#125/#126/#128/#132/#133/#134).
**Still open:** the deferred HCM/HDL/config reconcilers are reported NOT CHECKED — their sweep lands with their base-tier reconciliation (items 22/23).
**Cost 3 / Risk 3.**

## 28. Shared DMT_IMPORT_REPORT_PKG.APPLY_ERRORS — P2
**Verdict: STILL OPEN.**
**What it is (plain):** The same "match import-report error rows back to our records" UPDATE is copy-pasted in two results packages; extract it to one shared procedure.
**Developer detail:** Inline in `DMT_EXPENDITURE_RESULTS_PKG` and `DMT_PROJECT_RESULTS_PKG`. Extract to a shared procedure parameterized by TFM table + key column. No `DMT_IMPORT_REPORT_PKG` exists yet.
**Cost 3 / Risk 3.**

## 29. Implement the outcome-based tile palette — P2
**Verdict: STILL OPEN.**
**What it is (plain):** The run-detail tiles are coloured by two different code paths; replace both with the single agreed palette (green / light green / light red / red / grey / blue / white) driven by per-object outcome counts including unaccounted.
**Developer detail:** Both color paths live in `DMT_RUN_DETAIL_TILES`; replace with the single palette decided 2026-07-06. Subsumes the old "async path never shows orange" item.
**Cost 4 / Risk 2** — presentation logic, isolated.

## 30. Log attribution + Activity Log browser — P2
**Verdict: STILL OPEN.**
**What it is (plain):** Add a queue-item id to log rows so log entries can be traced to the exact work item, and build an Activity Log browser page with pre-filtered entry points from Run Detail and Object Detail.
**Developer detail:** Add nullable `QUEUE_ID` to `DMT_LOG_TBL` (and `DMT_STG_TFM_ERROR_TBL`); index `RUN_ID`/`QUEUE_ID`; implement `DMT_UTIL_PKG.SET_LOG_CONTEXT` + auto-stamping and set context in the three `DMT_QUEUE_WORKER_PKG` child jobs; build the APEX browser page. Must land before the deprecated dashboard is deleted.
**Cost 6 / Risk 3** — DB + UI, but additive (nullable column).

## 31. 73 invalid views bound to dropped INTEGRATION_ID / archived CONVERSION_MASTER — P2
**Verdict: PARTIAL** (decision made; deletion + usage-check pending).
**Proof/decision:** 2026-07-04 decision: DELETE the 36 `*_imp_rpt_v` views (confirmed invalid, unreferenced, outside the git-first deploy tree). The 37 summary `DMT_*_V` views still need a usage check → fix-vs-delete.
**Still open:** actually delete the 36 and triage the 37. These are the documented invalid-object baseline (73 views) that show up as "invalid" on every install.
**Cost 3 / Risk 3** — deletion is safe if truly unreferenced; the 37 need a usage audit first.

## 32. Items ORA-01427 reconciler bug — P2
**Verdict: RESOLVED** (2026-07-15).
**Proof:** In `DMT_EGP_ITEM_RESULTS_PKG` the FAILED-row STG echo-back was a scalar subquery returning >1 row (an item transforms into several TFM rows per staging row). Rewritten to take the first FAILED TFM row deterministically via `ROW_NUMBER() OVER (ORDER BY TFM_SEQUENCE_ID)` (CLOB-safe). Recompiles VALID.
**Cost 1 / Risk 1.**

## 33. Expenditures loader hardcodes a business unit — P2
**Verdict: RESOLVED** (confirmed 2026-07-15).
**Proof:** The Expenditures ParameterList now reads `EXPENDITURE_BU_NAME` from config and resolves the id via `GET_LOOKUP('BU_NAME_TO_BU_ID', ...)`; no literal BU id remains in the loader. (Later reinforced by PRs #235/#242/#243 Expenditures fixes.)
**Cost 1 / Risk 1.**

## 34. Assignment HDL generator hardcodes a business unit — P2
**Verdict: RESOLVED** (2026-07-15).
**Proof:** `db/packages/dmt_worker_hdl_gen_pkg.pkb.sql` now reads config key `WORKER_DEFAULT_BU_NAME` (default `'US1 Business Unit'` if absent) for the assignment `BusinessUnitShortCode` instead of the literal; config row seeded idempotently. Recompiles VALID.
**Cost 1 / Risk 1.**

## 35. Assets loader hardcodes a book type — P2
**Verdict: RESOLVED** (confirmed 2026-07-15).
**Proof:** The Assets ParameterList now reads config key `ASSET_BOOK_TYPE` (`GET_CONFIG('ASSET_BOOK_TYPE') || ',,NORMAL'`); the only `'US CORP'` left is an illustrative comment.
**Cost 1 / Risk 1.**

## 36. Config holds instance IDs by number, not name — P2
**Verdict: STILL OPEN** (proposed 2026-07-09).
**What it is (plain):** Some configuration values are stored as raw Fusion internal ID numbers that differ on every instance, so moving to a new pod means editing code/config by number. Store the *name* and look up the id at pipeline start (as the BU lookup already does).
**Developer detail:** `DMT_CONFIG_TBL` seeds `PO_DEFAULT_BUYER_ID`, `PO_DEFAULT_REQ_BU_ID`, `PO_DEFAULT_PRC_BU_ID`, and the `*_INTERFACE_DETAILS_ID` values as raw ids. Convert to name + prepopulated-lookup resolution.
**Impact:** New-instance onboarding is a code edit, not a config exercise.
**Suggested fix:** Add lookups (like `BU_NAME_TO_BU_ID`) for buyer/BU/interface-details; store names in config.
**Cost 5 / Risk 5** — touches PO defaults used across the PO family.

## 37. Enforce mandatory scenario on every ingestion path — P2
**Verdict: STALE/OBSOLETE** (owner revised 2026-07-15 — remaining work is APEX-only).
**What changed:** Owner decided NOT to retire the `p_include_untagged` parameter (kept as a deliberate escape hatch for manual runs). No procedure code change wanted. Enforcement moves to the UI: the APEX ingestion paths constrain every submission to name a scenario.
**Residual:** the APEX-side scenario constraint (APEX-agent scope) — reclassify as a UI item, not a DB item.
**Cost 3 / Risk 2** — UI-only.

---

# P3 items

## 38. Remove cancellation (CANCEL_RUN + CANCELLED status) — P3
**Verdict: STILL OPEN.**
**What it is (plain):** Runs are meant to always execute to a terminal state; mid-flight problems are recovered by an ALL-mode re-run under a new prefix. So the cancel feature and CANCELLED status should be deleted from code and screens.
**Developer detail:** Delete `CANCEL_RUN` and the `CANCELLED` run status from code and screens (decided 2026-07-07). Not yet done.
**Cost 3 / Risk 4** — removing a status touches state-machine comparisons in DB + UI.

## 39. Banks to REST — P3
**Verdict: STILL OPEN.**
**What it is (plain):** The bank-account migration currently uses the old FBL (flat-file) mechanism; retire that and build a REST pipeline (banks → branches → accounts).
**Developer detail:** Retire `DMT_CE_BANK_FBL_GEN_PKG` and the Banks FBL artifacts; build/verify the REST pipeline per `objects/Banks/README.md` (correct its staging table names to `DMT_CE_BANK_*`). `dmt_ce_bank_runner_pkg` still present.
**Cost 6 / Risk 3** — new REST pipeline for one object family.

## 40. Delete the abandoned adaptor stubs — P3
**Verdict: RESOLVED** (2026-07-15).
**Proof:** `DMT_EBS_ADAPTOR_PKG` / `DMT_GENERIC_ADAPTOR_PKG` deleted (`ls db/packages/*adaptor*` → none); four package files + four install.sql lines removed; `db/tools/drop_retired_adaptor_stubs.sql` added for existing DBs. 0 invalid.
**Cost 1 / Risk 1.**

## 41. Eliminate standalone procedures — P3
**Verdict: PARTIAL** (PR #91: 5 dead procs dropped; folding the 6 live render procs TABLED).
**Proof:** All 5 dead procedures dropped (`DMT_FBDI_FILE_CHAIN`, `DMT_PLAN_RUN_GTT`, plus the 3 submit procs already retired); `db/tools/drop_retired_dead_render_procs.sql` added.
**Still open:** folding the 6 live render procs (`DMT_RUN_DETAIL_TILES/_HEADER`, `DMT_OBJECT_DETAIL_BREADCRUMB`, `DMT_ESS_JOB_DETAIL`, `DMT_RENDER_VIEW`, `DMT_PLAN_PREVIEW_HTML`) + `DMT_SUBMIT_RUN_V2` into packages — needs the APEX app-metadata edit + split-export-to-git workflow established first (re-points ~11 app-155 region sources).
**Cost 5 / Risk 5** — blocked on the APEX-to-git workflow.

## 42. Standardize validator entry points — P3
**Verdict: STILL OPEN.**
**What it is (plain):** Validator packages expose their entry procedure under inconsistent names; standardize all 43 to `VALIDATE_PRE_TRANSFORM`/`VALIDATE_POST_TRANSFORM`.
**Developer detail:** 4 pkgs use `VALIDATE_BATCH`, 1 `VALIDATE_UPSTREAM`, plus object-specific names. Conform all 43.
**Cost 4 / Risk 4** — rename touches every caller of the renamed entry points.

## 43. Split the supplier transform/reconciler packages per FBDI object — P3
**Verdict: STILL OPEN.**
**Developer detail:** `DMT_POZ_SUP_TRANSFORM_PKG` and `DMT_POZ_SUP_RESULTS_PKG` each cover five FBDI objects (Suppliers, Addresses, Sites, SiteAssignments, Contacts). Standard is one package per object per stage. Both multi-object packages still present.
**Cost 5 / Risk 5** — splitting a live, proven package family (the whole supplier pipeline).

## 44. Mode-driven selection predicates; retire reset_scenario_status + RETRY — P3
**Verdict: STILL OPEN.**
**What it is (plain):** Pass the run mode into validators/transforms so selection is driven by it (NEW = unprocessed, FAILED = failed-last-attempt, ALL = whole scenario), and delete the reset procedure and the RETRY status.
**Developer detail:** Related to item 13 (ALL-mode predicate). Delete `reset_scenario_status` and the RETRY status; base selection cursors on mode.
**Cost 6 / Risk 6** — changes selection logic for every object + removes a status.

## 45. Document the prefixed business key(s) per object — P3
**Verdict: STILL OPEN.**
**Developer detail:** Docs-only — add a "prefixed keys" column to the §1 canonical object list naming exactly which key(s) each object's transform prefixes.
**Cost 2 / Risk 1** — documentation.

## 46. Eliminate runtime EXECUTE IMMEDIATE — P3
**Verdict: STILL OPEN.**
**What it is (plain):** Replace dynamic SQL executed at runtime with static SQL; dynamic SQL should be allowed only in deploy scripts, never in a live database code object.
**Developer detail:** Targets the Object Detail breakdown region, `DMT_LOADER_PKG` dynamic updates, and the ESS-id lookup. Note that the queue-worker's registered-dispatch `EXECUTE IMMEDIATE` is intentional (catalog dispatch) — this item is about the *non-dispatch* dynamic SQL. `EXECUTE IMMEDIATE` still present in the loader and queue worker.
**Cost 5 / Risk 6** — rewriting dynamic updates to static touches the loader's core update paths.

## 47. Replace LIKE-matching on known codes with equality — P3
**Verdict: STILL OPEN.**
**Developer detail:** Start with the 1099 routing filter (note: 1099 object itself is retired via item 18, but any residual `LIKE '%1099%'` invoice-type routing remains), then audit all packages/views for `LIKE` on enumerable codes and switch to `=`.
**Cost 2 / Risk 3** — small edits but a wrong equality could silently drop rows; needs care per site.

## 48. Complete validator tag adoption — P3
**Verdict: STILL OPEN.**
**Developer detail:** 25 of 43 validator bodies append untagged `ERROR_TEXT`; conform them to `[PRE_VALIDATION]`/`[POST_VALIDATION]` per the §5 tag table.
**Cost 4 / Risk 2** — mechanical string-tag edits across 25 packages.

## 49. Verify the Run Pipeline screen against its new spec — P3
**Verdict: STILL OPEN.**
**Developer detail:** The plan-preview modal was reported working 2026-07-07 (previously hung); the screen now has a full spec + mock-up (section 8). Verify behavior matches in the next smoke run. Verification task, no code change expected.
**Cost 2 / Risk 1.**

## 50. Dashboard redesign — P3
**Verdict: STILL OPEN.**
**Developer detail:** Live pipeline stats + recent runs, no Activity Log entry point (decided 2026-07-06); approved mock exists; write the matching one-paragraph spec into section 8 when picked up. Coupled to item 30 (Activity Log) and the deprecated-dashboard deletion.
**Cost 4 / Risk 2** — UI.

## 51. CSV upload E2E verification (Pages 2–12) — P3
**Verdict: STILL OPEN** (partial per doc).
**Developer detail:** Browser-verify the CSV upload flow end to end across APEX pages 2–12. Verification task.
**Cost 3 / Risk 1.**

## 52. Delete superseded APEX pages — P3
**Verdict: STILL OPEN.**
**Developer detail:** Delete pages 13, 15, 50, 51, 55, 56, 70–72, 81, 83 via App Builder. APEX-cleanup task.
**Cost 2 / Risk 2** — verify no live drill-through references first.

## 53. Rename APEX *_INTEGRATION_ID page items/columns to *_RUN_ID — P3
**Verdict: STILL OPEN.**
**Developer detail:** Drill-through screens (P52/P53/P57) still pass the retired `*_INTEGRATION_ID` name; §9 documents the end-state `*_RUN_ID` names; retire the compat alias afterward. (This is the UI tail of the RUN_ID convergence whose DB side is item 1 — RESOLVED.)
**Cost 3 / Risk 3** — APEX rename + retire alias; risk if a page still binds the old name.

## 54. Remove the files table from ESS Job Detail — P3
**Verdict: STILL OPEN.**
**Developer detail:** Files are listed/downloaded only on ESS Output; make each job id in the ESS Job Detail hierarchy the link to that job's files (decided 2026-07-06, §9). DB+UI.
**Cost 3 / Risk 2.**

## 55. 2 invalid package bodies (DMT_PIPELINE_INIT_PKG, DMT_REST_LOADER_PKG) — P3
**Verdict: RESOLVED** (2026-07-15).
**Proof:** Both compile VALID. `DMT_PIPELINE_INIT_PKG` repaired in Stage B; `DMT_REST_LOADER_PKG` had two invalid JSON paths in `PARSE_REST_RESPONSE` on 26ai (runtime-concatenated `'$.' || p_id_field` → switched to the PL/SQL `JSON_OBJECT_T` API; unquoted `o:errorDetails` → quoted `'$."o:errorDetails"[0].detail'`). Total invalid on dmt2-local = 0.
**Cost 1 / Risk 1.**

## 56. Retire the superseded docs — P3
**Verdict: STILL OPEN.**
**Developer detail:** Line-by-line port `DB_REQUIREMENTS.md` + `UI_REQUIREMENTS.md` into `DMT_DESIGN.html`, then delete both; update `data-flow.md`/`architecture.md` to the RUN_ID/queue model; archive (not delete) the stale pre-review copy. Docs.
**Cost 4 / Risk 1.**

## 57. Browser-verify Page 82 tile grid + live REST Verify call — P3
**Verdict: STILL OPEN** (partial per doc).
**Developer detail:** Browser-verify the Page 82 tile grid and the live REST "Verify in Fusion" call. Verification task.
**Cost 2 / Risk 1.**

---

## Notes on method & confidence

- Verdicts labelled RESOLVED were each confirmed against the current tree, not taken on the doc's word: the `-20044` guard (item 7) is at `dmt_loader_pkg.pkb.sql:1369`; `phase1_pipeline_redesign` (item 1) and `GLBudgetBalances`/`RUN_1099`/adaptor/1099 packages (items 17/18/40) are absent; the funnel/prefix-history views and `DMT_XREF_PKG`/`DMT_STG_TFM_ERROR_TBL` exist; item 16 (catalog-driven dispatch) is RESOLVED — `DMT_QUEUE_WORKER_PKG.EXECUTE_ONE` dispatches from the `DMT_PIPELINE_DEF_TBL` registry with no per-object CASE; item 15 is RESOLVED-EXCEPT-GLCalendar — six of the nine `*_RUNNER_PKG` are live queue-wired, three genuinely dead ones were deleted (2026-09-21), GLCalendar wiring deferred (re-verified 2026-09-21, superseding the earlier "items 15/16 open" note); `run_one_object_type` is still the ~2,600-line monolith (item 8 open).
- Two items were reclassified to **STALE/OBSOLETE** because the owner explicitly parked or reversed them: db_full adoption (item 2) and the scenario-enforcement procedure change (item 37, now UI-only).
- Cost/Risk are integers 1–10 as requested; where an item is RESOLVED the numbers reflect the trivial verify-only residual, not the original effort.
- Several "verification only" P3 items (49, 51, 57) are open only in the sense that the browser smoke check hasn't been re-run; no code defect is known.
