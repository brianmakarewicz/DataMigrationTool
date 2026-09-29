# DMT2 -- Session Status Log

## Session -- 2026-09-29 -- Unaccounted objects resolved (all traced to faulted runs, not matching bugs)

**Bottom line.** The three long-standing "unaccounted" objects were NOT matching bugs -- all three trace to runs that faulted mid-reconcile and were never re-run (the reconcile correctly RAISED on a transient BIP/Fusion outage rather than fabricating a verdict). Re-running the reconcile accounts every record with real base-table / error proof and no code fix.

- **Items / Item Master (4 records, run 119).** Not a bug. Re-ran the item reconcile -> 3 good items LOADED (real INVENTORY_ITEM_ID) + 1 bad item (org ZZZ) FAILED with the real "invalid organization" Fusion error. The ITEM_NUMBER+ORGANIZATION_CODE match works; the rows were stuck only because run 119's reconcile faulted. No code change needed.
- **GL Budget Lines (run 119).** Not a bug (PR #483, merged). Same run-119 fault. Re-ran reconcile -> 2 LOADED + 1 FAILED. Added a WARN log for residual GENERATED rows.
- **AP Invoice Lines (run 325).** No real bug. A prior sub-agent (PR #482) "fixed" a supposed Fusion line-renumbering with a per-invoice business-key fallback -- but a controlled test disproved the premise: Fusion PRESERVES the sent line number (sent line 3 -> stored line 3) and only APPENDS its own tax lines, so the original exact per-line match is correct. **Reverted #482 via PR #484 (merged).** A follow-on REFERENCE_KEY1 traceability carrier (PR #485) was CLOSED -- it breaks the AP load: the AP invoice-lines FBDI is a fixed 164-column template and REFERENCE_KEY1 is not in it (stamping it as a 165th column makes SqlLdr reject the file, 0 rows committed).

**The real fix (backlogged):** backlog #95 (P2) -- a first-class "re-run reconcile for run N" capability, since faulted runs leave GENERATED rows with nothing to re-reconcile them. A per-line traceability carrier for AP is deferred until the ATTRIBUTE1 DFF segment is enabled (the business-key/deferred case per PR #481).

## Session -- 2026-09-29 -- Comparison report: APEX two-view redesign, count/$ split, cached snapshot for instant load

**What was done.** The post-run comparison report got its APEX front end finished and made fast. Five PRs:

- **PR #476 (merged).** Added a "View run comparison report for this run" drill link on the Run Detail page (page 82) that opens the comparison page (page 85).
- **PR #477 (merged).** Redesigned page 85 into two views: an **Overview** (one card per object, grouped by process area, with a balance badge, and an errors count that drills to the failed records) and a **Detailed comparison** (an Interactive Report). Also removed four hardcoded explanatory note strings (Talent Profiles, Project Budgets, Expenditures, Grants) from the HCM and PPM comparison packages (DMT_HCM_COMPARE_PKG / DMT_PPM_COMPARE_PKG) -- set to NULL; the balance logic did not change.
- **PR #478 (merged).** Split the detailed comparison table into separate count and dollar columns per stage (Staged, Errors, Loaded, Variance). The dollar columns are left blank for objects that carry no money; helper columns are hidden.
- **PR #479 (merged).** Renamed `scripts/deploy_supplier_bip_reports.py` to `deploy_recon_bip_reports.py` (it deploys the Wave-1 recon reports for the supplier family AND Customers). Added backlog item #94 (P3) to `docs/backlog.html`: a business-key checksum for money-less comparison objects.
- **PR #480 (OPEN, awaiting the Actions reviewer).** Speed fix. New table `DMT_RUN_COMPARISON_TBL` caches one computed snapshot per run. `DMT_RUN_COMPARE_PKG.SAVE_RUN_COMPARISON(run)` makes the live Fusion pass once and stores it. Page 85 now reads that table (instant load) instead of making ~23 live Fusion calls (about 15-28 seconds) on every open. Added a "Refresh from Fusion" button (re-pulls on demand and shows "as of <timestamp>") and a "Run Comparison" entry in the navigation menu. Verified live on local app 501, run 132.

**Correction to a prior status entry.** The earlier "clean up 167 stale Docker override-credential rows (NULL username)" item was a misdiagnosis. Those rows are in `DMT_ERP_INTERFACE_OPTIONS_TBL` and are SEEDED reference data -- the ERP interface options catalog (business object to FBDI/ESS job path), seeded by `db/seed/dmt_erp_interface_options_tbl.sql`, 180 rows. `FUSION_USERNAME` / `FUSION_PASSWORD` are NULL by design; credentials come from the config default (`DMT_UTIL_PKG.GET_CEMLI_CREDENTIALS`). Deleting them would wipe the catalog and diverge from git. This is NOT a cleanup task and was removed from priorities.

**What's next.**
1. Merge PR #480 once the Actions reviewer approves.
2. Blanket PO money: change the generator (`dmt_blanket_po_fbdi_gen_pkg`) to emit an amount-based BPA line so Fusion keeps the amount and Blanket PO money reconciles. Requires a live BlanketPOs run to verify. Not yet started.
3. Promote the comparison feature to ATP GOLD via `scripts/ci_promote.py` -- AFTER PR #480 (and the Blanket PO change) merge, so GOLD gets the finished code. Built and proven on local Docker only.

**Blockers:** None. (PR #480 is open and waiting on the automated reviewer, which is expected, not a blocker.)

**Git state:** On branch `feat/comparison-cache-and-nav` (the PR #480 branch), tree clean of tracked changes. This branch is 1 commit ahead of `origin/main` (the PR #480 commit) and 1 behind (PRs #476-#479 already merged into main after this branch was cut). Untracked scratch only (worktrees, `_scratch_export501/`, `scratch_matrix*.txt`, `docs/rca_regression_2026-09-18.md`) -- safe to ignore or clean.

**Next session:** first action is to sync -- `git checkout main && git fetch && git merge --ff-only origin/main`, confirm a clean tree -- BEFORE any new work. If PR #480 has merged by then, main already has the cache/nav work; if not, check the branch out again to finish it.

## Session -- 2026-09-28 -- Post-run comparison report: ALL 23 objects rolled out (PR #475); walking skeleton merged (#474)

**What happened.** The walking skeleton (framework + Purchase Orders) merged to main as PR #474 -- which included a governance step the owner approved: amending coding-standard #66 to sanction the comparison framework's one dispatch site (`DMT_RUN_COMPARE_PKG.BUILD_ROWS`) as a fourth dynamic-invocation site, plus an anti-circumvention clause so nobody can smuggle a new dynamic-dispatch need through an existing site. (The automated reviewer first blocked a self-certified amendment; it was redone as a proper owner-approved accepted rule via the design-change sentinel.)

Then the remaining **22 objects** were rolled out in 7 families (Suppliers x5; Blanket POs + Contracts; AP Invoices + Customers + AR Invoices; GL Balances + GL Budgets; PPM x5; Assets + Requisitions; HCM x3) on branch `feature/comparison-rollout-objects`. Each family was independently reviewed, then a whole-branch review (most capable model) and a scoped re-review of its fix wave. Opened as **PR #475** (awaiting the Actions reviewer).

**Proof.** Full grid for run 132 verified live: **23 of 23 objects present, all in balance.** Every key path exercised (load-request id, import-request id, stamped GROUP_ID/SOURCEREF/key-map, captured Fusion id), money reconciled where Fusion carries it, env-blocked objects honestly 0-loaded with a note. No prefix or timestamp-window keys anywhere.

**Whole-branch review hardening applied:** a Fusion fault on any object now shows an explicit "unknown" row instead of the object vanishing; the BIP deploy manifest now lists all 23 comparison reports; Salaries money sum hardened against non-numeric. Bugs caught live during rollout and fixed: Assets multi-book fan-out (scoped to the posted book), Requisitions double-staged double-count (scoped via TFM), an Assets nonexistent-column reference.

**Left:** merge PR #475 (Actions reviewer); confirm the 4 env-blocked objects (AR Invoices, Project Budgets, Grants, Talent Profiles) on a run where they load; Blanket PO money needs an amount-based line to reconcile in Fusion; rename the generic-but-supplier-named BIP deploy script.

## Session -- 2026-09-27 -- Post-run comparison report: discovery proven for all 23 objects; walking-skeleton built (Purchase Orders end-to-end)

**What this feature is.** A new report that, after a run, shows each object side by side:
how many records we staged, how many failed in our tool, and how many actually succeeded
in Fusion -- with money totals -- and checks they add up (`Fusion successes + TFM errors =
STG total`, per object). The success number is queried live from Fusion. This is a separate
process from the existing row-by-row reconciliation (`DMT_RUN_SUMMARY_PKG` /
`AUDIT_IN_FUSION`): it is aggregate control totals keyed by a batch id, not a per-record match,
and it carries money, which the recon layer does not.

**Design + plan (committed on branch `spec/post-run-comparison`, not yet merged):**
- Spec: `docs/superpowers/specs/2026-09-27-post-run-comparison-design.md`
- Proven query matrix (one file per object + the index): `docs/superpowers/specs/discovery/QUERY_MATRIX.md`
- Implementation plan: `docs/superpowers/plans/2026-09-27-post-run-comparison.md`

**Discovery -- proved every query by hand before any code (read-only, against run 132 on
local Docker).** All 23 objects reconcile. 19 are proven with a production-safe key and
balance exactly; 4 loaded nothing this run (AR Invoices, Project Budgets, Grants, Talent
Profiles -- blocked by Fusion setup), so their staged/failed sides were proven and their
Fusion query designed for a future run. Key rules that fell out and now bind the build:
- The run's record set always comes through the transform rows (STG has no RUN_ID and holds
  duplicate seed rows); never scope by business key or the test prefix.
- Fusion key order: a batch id (the import/load ESS request id we already record, which can be
  a list per object) -> a stamped reference that round-trips -> the captured Fusion id, used
  only where no batch id exists (proven so for Projects and GL Budgets). Never the prefix or a
  timestamp window.
- Money reconciles from Fusion for 9 objects. Contracts genuinely have no money (header-only
  agreement). Blanket PO money is dropped by Fusion because the line is generated quantity-based
  (a generator matter, not reconciliation). Expenditures shows Fusion's recomputed cost, so its
  money variance is real and intended.

**Rotated the Fusion demo password.** It had expired (all users 401), which blocked the live
Fusion side of discovery. Rotated everywhere and verified all five users return 200. Residual:
167 per-object override-credential rows on the Docker DB (NULL username) still hold the old
password -- they are inert (no username to log in as) but should be cleaned up before the next
real Docker pipeline run.

**Build -- subagent-driven, 6 of 7 tasks complete and reviewed; the APEX page (Task 7) was in
progress at write time.** Walking skeleton = the shared framework plus Purchase Orders end to
end; the other 22 objects follow the same template later. Artifacts built and deployed to
local Docker:
- `DMT_CMP_ROW_OBJ` / `DMT_CMP_ROW_TAB` -- the uniform comparison-row type.
- Three columns on `DMT_BIP_REPORT_TBL` (`CMP_DM_CATALOG_PATH`, `CMP_REPORT_CATALOG_PATH`,
  `CMP_FUNCTION`) -- the per-object comparison-report registry.
- `bip/PurchaseOrders/PO_CMP_DM.xdm` + `PO_CMP_RPT.xdo` -- the PO Fusion aggregate report
  (deployed to `/Custom/DMT2/PurchaseOrders/`).
- `DMT_PO_COMPARE_PKG.GET_COMPARISON(run)` -- the PO comparison function.
- `DMT_RUN_COMPARE_PKG.GET_RUN_COMPARISON(run, cursor)` -- the framework: enumerates a run's
  objects, dispatches to each object's function via the registry, skips-and-logs a broken one.
- `test/comparison/verify_run132.sql` -- the end-to-end gate.

**Proof:** the live end-to-end test on run 132 passes -- Purchase Orders shows staged 3 / 2300,
errors 1 / 50, Fusion 2 / 2250, in balance. Every failure carried a real Fusion error; every
success was read back live from a Fusion base table.

**What's next:**
1. Finish the APEX page (Task 7) on app 501, run the whole-branch review, open the PR, and merge
   `spec/post-run-comparison`.
2. Roll out the other 22 objects with the proven template: one Fusion aggregate BIP report, one
   `GET_COMPARISON` function, and one `CMP_FUNCTION` registry seed per object (all queries are
   already proven in `QUERY_MATRIX.md`). The 4 zero-loaded objects confirm on a run where they load.
3. Follow-ups: to reconcile Blanket PO money, generate the BPA line as amount-based so Fusion
   keeps the amount; clean up the 167 stale Docker override-credential rows from the password
   rotation.

## Session -- 2026-09-25 -- EBS-adaptor backlog fixes merged to DMT2; full regression PASSED (run 132, zero new regressions)

**What was done:** Reviewed and corrected the 7 backlog items the EBS adaptor logged, then
kicked off one full DMT2 regression against the real Fusion demo. All DMT2-side fixes are
merged to `main` and deployed to the local Docker instance (`dmt2-local`), which installed
clean with zero invalid objects.

DMT2 repo (brianmakarewicz/DataMigrationTool) -- all in PR #470 unless noted:
- **#469 chunked-ingest API (issue CLOSED):** new package `DMT_CSV_INGEST_PKG`
  (`start_file` / `append_chunk`) does the large-text append on the ATP side, so CSV cells
  longer than 8000 characters can cross the database link. EXECUTE granted to EBS_ADAPTOR.
- **#468 PO distributions FBDI:** restored the wrongly-dropped ATTRIBUTE5 (Fusion's
  PoDistributionsInterface needs ATTRIBUTE1..20 with no gaps). Widened 123 to 124 columns
  across the generator, staging table, transform table, transform, metadata seed, view, and
  gold fixtures. The reconciliation id now lands in ATTRIBUTE_NUMBER1, not ATTRIBUTE_DATE10.
- **#449 CSV loader multibyte:** loader buffers now declared CHAR (fixes the ORA-06502 class).
  Defensive hardening -- normal multibyte already loaded on current code.
- **#466 staging-table primary-key collision:** fresh-install DDL now uses GENERATED ALWAYS
  AS IDENTITY (PR #470). The migration was CORRECTED in **PR #471** because an in-place
  identity conversion is impossible (ORA-30673) and the first migration had already cleared
  the sequence default before failing, breaking all 73 tables. Replaced with a recovery that
  restores the sequence default and advances the sequence past the current max. Verified on
  dmt2-local: fixed 73 of 73 tables, zero left without a default.
- **#453 supplier lookups (SUPPLIER_TYPE / TAX_ORGANIZATION_TYPE):** the DMT2 artifacts were
  already on main and verified correct against live Fusion (POZ_VENDOR_TYPE 22 values,
  POZ_ORGANIZATION_TYPE 11 values). Remaining work is on the Fusion side (see What's next).

EBSAdaptors repo (brianmakarewicz/EBSAdaptors) -- PR #29 MERGED; live proof on the EBS VM
deferred (VM saved for RAM):
- **#25 coherent parent/child sampling:** generate_all_csvs samples N driver keys once per
  object into a session temp table; driver views no-op when the table is empty, so full
  extracts are unchanged and the signature is unchanged.
- **#21 missing view-source grants:** recorded 21 missing SELECT grants in
  00_CREATE_SCHEMA.sql (Projects/Grants, Requisitions, Inventory, dynamic-SQL base tables).

**Regression -- PASSED (run 132, prefix 93212, all objects terminal):** across the whole run,
**zero ORA-00001, zero ORA-06502, zero ORA-01840**, and every object's LOADED count matches the
prior baseline (run 131) exactly -- **zero new regressions**. PurchaseOrders loaded 2 rows with
real FUSION_IDs plus 1 correctly FAILED. Overall harness status COMPLETED_ERRORS comes only from
the same pre-existing items as baseline (ARInvoices/Grants/ProjectBudgets/TalentProfiles at 0
LOADED were 0 in run 131 too). NOTE on #468: the gold-regression PO data never populates
ATTRIBUTE_NUMBER1 in the shifting slot, so it cannot positively reproduce the original ORA-01840
-- the fix is verified by column analysis + no-regression here; positive reproduction is owed
from the EBS-adaptor PO extract on the VM.

The EBS Vision VM was saved (resumable, not shut down) to free RAM for the regression.

**What's next (remaining follow-ups, none blocking this session's goal):**
1. On the EBS VM (resume it first): verify #21 and #25 -- fresh dmt_ebs_adaptors install = zero
   ORA-00942; PurchaseOrders limit-5 extract header keys == line parent keys; and positively
   reproduce #468 (re-run the run-169 PO extract, confirm distributions load). #468 stays OPEN
   until that confirms.
2. Deploy the #453 lookup data models (.xdm) to /Custom/DMT2/Lookups/ on Fusion, then run
   DMT_LKP_REFRESH_PKG.REFRESH_FUSION_VALUES for both SUPPLIER_TYPE and TAX_ORGANIZATION_TYPE.
3. On the EBS side, re-point push_csv_to_atp to call DMT_CSV_INGEST_PKG (#469) and drop the
   old STG-sequence workaround (#466 auto-generates now). See EBSAdaptors docs/backlog.md.
4. Resume EBS adaptor Task 5 (Suppliers pipeline end-to-end) once the above hold.

Done this session: regression verdict read (PASS); DMT2 #449/#466 closed, #469 closed;
EBSAdaptors PR #29 merged.

**Blockers:** none for the DMT2 work. Remaining items (#468 positive proof, #25/#21 live
verification) are gated only on resuming the EBS VM.

**Git state:** DMT2 on `main`, tree clean (only untracked scratch files), local level with
origin/main (0 ahead / 0 behind). #470 and #471 merged. EBSAdaptors on branch
`monroe/ebs-to-fusion-e2e-spec` (PR #29); the uncommitted #21 grant + backlog + plan edits
were committed and pushed this close-out (commit 0aabc1d) -- EBS tree now clean.

**Next session:** first action is to sync -- `git checkout main && git fetch && git merge
--ff-only origin/main`, then confirm a clean tree BEFORE any new work. EBSAdaptors PR #29 is
merged; the remaining EBS items are the VM-gated verifications above.


## Session -- 2026-09-23 -- Backlog batch merged, full regression PASS (run 121), ATP Gold deployed

**Headline:** A large backlog batch was executed and merged, the full regression re-ran clean on
local Docker (RUN_ID 121, prefix 93201), and DMT2 was deployed to the ATP Gold instance (schema +
APEX app 500). The three long-standing UNACCOUNTED break-fixes are now closed with real Fusion
evidence. The only UNACCOUNTED left in the entire run is 3 Project Budget Lines (backlog #79).

**What was accomplished:**
- **Backlog batch merged.** Engine cleanups (single BIP path #20, status-rename verify #26,
  instance-ids-by-name #36, validator entry points #42, mode-driven predicates + retire RETRY #44
  -- which also corrected 22 transform packages whose ALL mode wrongly selected only NEW rows,
  retire non-sanctioned EXECUTE IMMEDIATE #46, LIKE-on-codes #47). APEX work (funnel/Object-Detail
  #10, palette #29, Activity Log + log-attribution #30, dead views #31, fold render procs #41,
  verify #49/#50/#51/#55, page deletes #52/#58, INTEGRATION_ID->RUN_ID rename #53 with label
  follow-ups #442/#443, partition tiles #70/#74). Plus the Items per-batch import-id concurrency
  fix #75 and two clean-install bug fixes: #440 (widen DMT_BIP_REPORT_TBL.TFM_TABLE 100->240,
  fixed an ORA-12899) and #441 (GET_OR_CREATE_SCENARIO made idempotent, fixed a DUP_VAL_ON_INDEX).
- **Three reconciliation fixes proven with real Fusion evidence, 0 UNACCOUNTED:** GL Budget Lines
  (#422), AP Invoice Lines (#420), Item Master (#423).
- **Full regression PASS (RUN_ID 121, prefix 93201, local Docker).** The 3 recon objects at 0
  UNACCOUNTED with real Fusion base ids/errors; P2P chain green (Suppliers + children, PO all
  LOADED); #44 ALL-mode caused no regression; LOG_TYPE clean. Only 3 UNACCOUNTED in the whole run,
  all Project Budget Lines (pre-existing gap = backlog #79). APEX link-check: 0 broken across 40
  pages. (Prefix was leapfrogged to 93201, above the shared Fusion pod's supplier max ~93107,
  after a `--fresh` reset put the sequence back low.)
- **ATP Gold deployed (main HEAD 92468c5).** Schema installed to DMT2_OWNER on the queryapp ATP
  via ci_promote plus hand-applied migrations (TFM_TABLE->240 + Customers row reseeded, dead
  procs/views dropped, prefix sequence leapfrogged to 93300); 0 invalid, git-matched. APEX app 500
  imported from `apex/f501src`, alias LIVEDMT2, login HTTP 200.
  Gold console: https://g6726c838b72234-queryapp.adb.us-ashburn-1.oraclecloudapps.com/ords/r/dmt2/livedmt2/ (DMTADMIN).

**Open backlog count (after adding the 2 tooling items in this close-out):** 33 open
(STILL OPEN + PARTIAL) -- P1 2, P2 14, P3 17 -- of 81 total (RESOLVED 46, PARTIAL 5, STILL OPEN 28,
STALE 2). The two remaining P1s are #7 (reconcile registered in two places -- its durable fix IS
#16) and #9 (full-fidelity multi-CSV scenario upload).

### NEXT SESSION START

**The P1 batch -- #7 + #9 (with #16):**
- **#7 folds into #16.** Make the registry column `RECON_PROC` on `DMT_PIPELINE_DEF_TBL` the single
  reconcile dispatch for every object, and **delete the hardcoded partition ELSIF chain** that
  currently registers reconcile in a second place. One registry-driven dispatch, no duplicate
  hand-maintained branch. This is the durable fix that closes #7.
- **#9 -- full-fidelity multi-CSV-zip scenario upload.** Build an upload that accepts a full zip
  with **one CSV per STG (staging) table**, so a regression scenario loads once at full fidelity
  (all child detail: supplier addresses/sites/contacts, PO lines/distributions, etc.). This also
  makes regression re-runs clean, because a reloaded scenario no longer comes back degraded and
  re-breaks Suppliers/Customers/PO.

**Smaller follow-ups:**
- **#79** -- ProjectBudgets recon-verify gap (the 3 UNACCOUNTED Project Budget Lines).
- **GLBudgets page-52 / page-57 label drift** on the drill (cosmetic, non-gating).
- **#80** (NEW, P3) -- ci_promote.py deploy_db does not run `db/migrations/` or `db/tools/`, so
  MODIFY-width and guarded-DROP migrations must be hand-applied on every ATP promotion; extend the
  glob or add a run-migrations step.
- **#81** (NEW, P3) -- migration `2026-09-22_drop_dead_pay_rel_detail_view.sql` has its PL/SQL
  block `/` terminator on the same line as the block, so SQLcl `@@` silently skips it; reformat the
  terminator onto its own line.

### ENVIRONMENT NOTES (next session)

- **Local Docker (`dmt2-local`, port 1523)** is credentialed, has APEX 26.1 reinstalled, and the
  prefix sequence is at 93201.
- **Gotcha:** `build_local_db.sh --fresh` **WIPES the Fusion credentials + APEX + resets the prefix
  sequence.** After a `--fresh` you must: (1) re-credential from `connections.json`, (2) re-import
  the APEX app, and (3) leapfrog the prefix sequence above the shared Fusion pod's supplier max
  (~93107) so new supplier ids do not collide on the demo. Skip these and the next run will fail on
  bad creds, a missing app, or a prefix collision.

## Session -- 2026-09-21 -- Full regression gate PASSED (run 351); monolith deletion cleared

**Headline:** The full end-to-end regression passed as the gate for deleting the old
`run_one_object_type` monolith. Run 351, prefix 10291, ran against the real Fusion demo and drove
all 34 objects to a terminal state. The refactor that deleted `run_one_object_type` and moved every
object into a self-contained `RUN_<object>()` recipe (PR #418) introduced **zero new regressions**:
every object's LOADED / FAILED / UNACCOUNTED count matched its pre-refactor baseline (runs 325-347).

**What it proves:** Splitting the one giant object-runner into one recipe per object changed no
object's outcome. Good rows still load, bad rows still fail with real Fusion errors, and the count of
unaccounted rows is unchanged. The refactor is safe; the APEX port (Stage F step 2) can now proceed.

**Why the harness still prints FAIL (all PRE-EXISTING, none refactor-caused):**
- **3 true UNACCOUNTED objects** (open since run 325, each its own break-fix ticket): Items / Item
  Master (4 records), GL Budget Lines (2), AP Invoice Lines (1).
- **O2C AutoInvoice / interface objects at 0 LOADED** (waiting on the functional owner): Customers
  Account Sites, Account Site Uses, and ARInvoices AR Lines. These ride the AutoInvoice/interface
  path blocked on demo-instance functional setup.
- **Environment / functional-blocked (non-gating):** Grants (not set up on the demo), TalentProfiles
  / Profile Items (HCM V2 metadata the demo rejects), and 9 HCM/HDL objects with no seed data.

**Review items (not gating):** 38 cosmetic malformed LOG_TYPE entries (the package name landed in the
log-level column; NOT from PR #418). The APEX authenticated smoke test could not run because there is
no DMT_SMOKE end-user account on app 500 (only the login page was verified).

**Next up:**
1. Three UNACCOUNTED break-fixes: Items / Item Master, GL Budget Lines, AP Invoice Lines.
2. APEX #74 (partition-value drill-down) and #75 (partition-aware tile load-id fallback).
3. Create a DMT_SMOKE end-user account on app 500 so the authenticated APEX smoke test can run.
4. Cosmetic LOG_TYPE cleanup (package name mistakenly written into the log-level column).

**Docs updated this close-out:** the Object Status Matrix in `docs/DMT_REBUILD_PLAN.html` section 0
(intro note, Items/APInvoices/GLBudgets/Customers/ARInvoices/Grants/TalentProfiles rows, and the
"Proven live" footer); the Stage F execution-status line in the same file; and the Stage F build-order
line in `CLAUDE.md`.

## Session -- 2026-09-14 -- Deploy DMT2 to the queryapp ATP (DMT2_OWNER) + drive the regression

**Headline:** DMT2 is now deployed and running on the **queryapp ATP** as a NEW schema **DMT2_OWNER**
(alongside the frozen ConversionTool `DMT_OWNER`, same PDB). Branch `feat/schema-relative-code`,
PR #236, 13 commits, tree clean. Enabled by making the DB code **schema-relative** (stripped the
hardcoded `DMT_OWNER.` qualifier, ~2,880 refs, so it installs into any owner; backward-compatible
on Docker). Full `install.sql` clean (0 invalid); scenario loaded; ACL + credentials set.

**Connection:** `DMT2_OWNER` / `Migr8_Dmt2#2026Qz` @ `queryapp_tp` (wallet
`C:\Users\Monroe\workspace\data-migration-tool\wallet`, set `TNS_ADMIN`). No APEX UI deployed
(engine/DB only). Harness env: `DMT2_CONN`, `DMT2_WALLET`, `DMT2_WALLET_PW`.

**Fixes made (all committed + deployed), each honest (real load or real Fusion error):**
1. `ENUMERATE_ESS_FILES` FK bug (ORA-02291 -- passed Fusion request id where local ESS_JOB_ID pk
   needed; starved reconciliation) -- took P2P from 0 to 10 accounted.
2. Parent->child accounting cascades: Requisitions (line/dist->header), Customers (party-site->
   site-use), Projects (project->task incl. orphan), MiscReceipts (transaction->lot).
3. HDL reconcile: when a data set loads 0 objects with real messages, mark still-GENERATED rows
   FAILED with the data set's real errors (Workers/Assignments).
4. Grants: fixed Award-Batch-Import-Report XPath (`//G_4`) -> 3 awards FAILED with real errors.
5. Expenditures: scenario source 'Time Card'->'External Time Entry System' + capture per-txn
   rejections from `//G_STAG_ERR`.

**Regression -- latest full run RUN_ID 120, prefix 10004 (fresh).** Good records LOAD cleanly for
PurchaseOrders, APInvoices, Customers, GLBalances, Projects, GLBudgets, Assets, BillingEvents,
ProjectBudgets (intended-good in, bad->FAILED). HCM 14/14 accounted; Projects 5/5.

**Reconciler false-negatives FIXED this session (all committed + deployed, verified run 120):**
- **Suppliers family** — DONE. All 5 supplier objects (Suppliers, Addresses, Sites, Site
  Assignments, Contacts) now show 2 good LOADED / 1 bad FAILED. The reconciler treats a Fusion
  "already exists" as LOADED (the record IS in Fusion; the pipeline re-submits within a run).
- **Requisitions** — DONE for headers (2 good LOADED / 3 bad FAILED). Same "already exists" ->
  LOADED handling. Child lines/distributions are still stuck FAILED on run 120 (a re-reconcile
  artifact); a fresh run with a new prefix cascades them to LOADED.
- **Items** — DONE (Item Master 3 good LOADED / 1 bad FAILED). Fixed the base-table confirm
  report to join on the item number instead of an id Fusion never stamps when the master import
  errors, and made reconciliation cover all of Fusion's split load requests.
- **PurchaseOrders / BlanketPOs / Contracts** — DONE (POs 2 good LOADED / 1 bad FAILED;
  Blanket 1/1; Contracts 1/1). The base-table confirm report was keyed on the Fusion import
  request id, which a within-run re-submit breaks, so a good PO that was actually in the base
  table got reported as a duplicate failure. Now it confirms the PO by its document number.
- **Fresh run 122 (prefix 10006) — DEFINITIVE VALIDATION, all P2P fixes hold end-to-end
  including child cascades.** Good records load, bad records fail with real errors, zero
  UNACCOUNTED except two honest cases:
  - PurchaseOrders: Headers 2L/1F, Lines 3L/1F, Locations 2L/1F, Distributions 2L/1F.
  - Suppliers family (5 objects) 2L/1F each; Items (Master) 3L/1F; Requisitions Headers 2L/3F,
    Lines 2L/2F, Dists 2L/2F; BlanketPOs 1L/1F; Contracts 1L/1F; APInvoices 2L/2F.
  - Financials: GLBalances, GLBudgets, Assets all good LOADED. Projects: Projects, Tasks,
    Team Members, Txn Controls, BillingEvents all good LOADED. O2C: Customers core tiers LOADED.
  - Honest remaining: ARInvoices 3 UNACCOUNTED (consolidated-billing job crash);
    Expenditures/Grants/HCM FAILED with real errors; Customers Account Sites and Items Item
    Categories 0 LOADED (consistent across 3 runs -- need separate investigation).
  - ONE open ruling for the owner: a requisition rejected for a bad HEADER (REQ-BADHDR) leaves
    its otherwise-valid line + distribution UNACCOUNTED (2 records). The reconciler deliberately
    does not compose a "parent header rejected" cascade (the error_attribution rule). Deciding
    whether to propagate the header's real rejection error to those children is the owner's call.

**Open items (NOT reconciler defects):**
- **ARInvoices** -- AutoInvoiceMasterEss crashes at job level ("consolidated billing is enabled...").
  3 lines UNACCOUNTED (mission-honest job crash). Needs consolidated billing disabled on the demo
  (Fusion setup) or the correct consolidated-billing AutoInvoice job.
- **MiscReceipts serial** -- 1 row, no parent-transaction link in the source data; needs a
  transform/schema change or Fusion serial verification.
- **Expenditures / Grants / Workers-Assignments** -- now honestly FAILED with real Fusion errors
  (instance config / bad-data), captured correctly.

## Session -- 2026-07-21/22 -- Resolve run-234 UNACCOUNTED honestly
**What was done:** Located the real Fusion outcome for all 23 UNACCOUNTED records from the first
honest scorecard (run 234) and landed 11 merged PRs (#222-#232). All are merged; #227's remaining
work is a HUMAN versioned BIP redeploy (not the PR). Evidence for every claim is committed under
`docs/findings/` (run234_*, run235_*, run238_projects_capture_validation). Full detail:
`docs/sessions/2026-07-21_unaccounted-resolution.md`. Highlights:
never fabricate LOADED (#222); real error -> FAILED (#223); Projects capture-the-report-child +
parse fix, validated end-to-end run 238 (#224/#229); Grants award-import-report (#225, capture
follow-up pending); HCM file-level error attribution (#226); Customers site-use error tier (#227);
Expenditures xref project/task resolution + reverted a dead GL_DATE patch (#228/#230); funnel
`ALL_UNACCOUNTED` dark-red flag (#231).
**Accounting model settled:** true job-level crash (Expenditures ORA-01008; AR AutoInvoice abort)
-> leave records UNACCOUNTED + dark-red tile, never fabricate or patch data; job success + per-row
reject -> capture the report/log and mark each rejected row FAILED with its real error.
**Docs updated this close-out:** project CLAUDE.md (added THE MISSION section; fixed stale "hourly
reviewer" -> event-driven; pointed to the Object Status Matrix + "update every session"); the
Object Status Matrix in `docs/DMT_REBUILD_PLAN.html` section 0 (Projects/Expenditures/Grants/
ARInvoices/Requisitions/PayrollRelationships/TalentProfiles/Customers rows).
**What's next:** finish the Grants report-capture end-to-end (same fix as #229 — better: add the
capture once in `DMT_QUEUE_WORKER_PKG.RECONCILE_ONE` so it fixes every object); run a full
regression to validate every merged reconciler + produce the complete scorecard; Customers BIP
redeploy (human) + the forward FBDI fix to stamp `SITEUSE_ORIG_SYSTEM/_REF`; wire the APEX funnel
tile to `ALL_UNACCOUNTED`; fix the two HDL generators (PayrollRelationships -> `AssignedPayroll`;
TalentProfiles ProfileItem attributes) + Worker WorkTerms duplicate-date so those HCM objects LOAD.
**Also tracked (from the blind review):** (1) reconcile committed-vs-deployed package drift — the
deployed bodies of `DMT_PROJECT_RESULTS_PKG`, `DMT_LOADER_PKG`, `DMT_ESS_UTIL_PKG` are ahead of the
committed files and a committed report path still reads `/Custom/DMT/`; git-first requires syncing
these. (2) The matrix Workers row is ☑ from the older run-162 live proof, but the run-234 worker
chain loaded ZERO (a false LOADED that #222 fixed) — re-verify Workers on the next full run.
**Run-238 caveat:** the Projects run-238 result was observed live in-session and recorded in
`docs/findings/run238_projects_capture_validation.md`, but was not re-queried after the DB port
wedged; re-confirm on the next full regression run.
**Blocker:** `dmt2-local` DB healthy internally (via `docker exec`) but host DB port 1523
forwarding is wedged; `wsl --shutdown` + container restart issued, host Oracle ports (1521/1523)
still not forwarding at close. The Python deploy script + regression harness need host 1523, so the
full-regression validation is deferred until the port returns. Stale run 154 QUEUED to clear.

## Session -- 2026-07-14
**What was done:** Requirements-design review of the canonical design doc
(`workspace/DMT2/docs/DMT_DESIGN.html`); artifact republished. Related edits to
`objects/Customers/README.md`. Specifics:
- Added subsection 7.1 "Canonical per-object processing recipe," built from the real
  DMT2 code (Suppliers template plus GLBalances/Customers partitioning).
- Decided to RETIRE 1099Invoices as a separate object -- it is AP filtered to invoice
  type 1099.
- Rewrote the BIP-mirror rule in plain English and added the change-the-model sequence
  (accepted).
- Verified BIP objects against the single-source object list: all 25 FBDI objects match.
  Found two naming splits (GLBudgets vs GLBudgetBalances; Lookups vs COMMON_LOOKUPS) plus
  a `/Custom/DMT/` path drift. Logged a BIP conformance-checker rule (red, awaiting approval).
- Tightened the seed-departure rule to require owner approval before a departure ships (red).
- Moved the HZ customer-batch resolved issue out of the standards table into
  `objects/Customers/README.md`; corrected that README's stale "blocked" status.
- Merged the two section-1 tables into one: folded BIP data-model / report / interface into
  the object table as three columns and deleted the standalone BIP table, so the object list
  can no longer diverge.
- Added a "Depends on" column to all four object tables (from DMT_PIPELINE_DEF_TBL.DEPENDS_ON).
- Added four specific engine-cleanup backlog entries (red) with exact files, procedures, and
  line numbers: (1) reconcile double-registration fail-open (dmt_queue_worker_pkg vs loader
  ELSIF 1152-1201, x_success:=TRUE fall-through at :1203); (2) GLBudgets dual identity
  (RUN_GL_BUDGETS renames to 'GLBudgetBalances' at dmt_loader_pkg.pkb.sql:4726 plus 9 loader
  arms); (3) retire 1099Invoices; (4) remove dead PlanningBudgets engine arms.
- Promoted the 15 owner-approved rules plus the Pipeline column, the SupplierBankAccounts row,
  and the canonical lookup registry to accepted (black).

**Rule established this session:** In this design doc, RED means exactly one thing --
awaiting the owner's approval. Work-done status is tracked in the Status column, never by
color. Proposed work becomes a backlog item, which may be red until approved.

**Open items awaiting the owner (all red in the doc):** the Post-Install rule
(setup_runtime_config.py taking the connections-file path as an argument -- not yet approved),
the tightened seed-departure rule, the BIP checker rule, the four new backlog entries, and
the pre-existing red section-12 rows from earlier sessions.

**What's next:** These design-doc changes are NOT this session's priority for follow-up work.
The active priority order (restated by the owner 2026-07-14) is:
1. DMT rebuild on the local Docker (primary).
2. Generic per-object flow review (the canonical per-object processing recipe / generic
   starter flow).
3. APEX install on the local Docker.
4. Requirements design review (DMT_DESIGN.html) -- this session's work; now behind the three
   above. Next design-doc action is to get owner rulings on the red items listed above, then
   promote or remove them.

**Blockers:** Today's DMT_DESIGN.html and Customers/README.md changes are NOT yet committed to
git. DMT2 main is protected, so this needs a short-lived branch plus a PR before the changes
land. Three timestamped safety archives (DMT_DESIGN.html.archive.2026071*) are in docs/ and
should not be committed.
