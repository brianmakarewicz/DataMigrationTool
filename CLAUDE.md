# DMT2 — Data Migration Tool Rebuild

Clean re-platform of the Data Migration Tool (frozen predecessor: `brianmakarewicz/ConversionTool`,
local `~/workspace/data-migration-tool/`). Seeded 2026-07-07 from the proven `db_full/` greenfield
install (1,055 objects, verified on local Docker).

**Master plan:** `docs/DMT_REBUILD_PLAN.html` (in this repo) — phases, build order,
per-stage test plan, roadmap, risks. Read the "Build Order of Operations" section before building.

**Object Status Matrix (single source of truth for per-object live status):** section 0 of
`docs/DMT_REBUILD_PLAN.html` (`#objstatus`) — one row per object with its good/bad example,
verify checkbox, and blocker. **Update this matrix at the close of every session** whenever an
object's live result or accounting status changed (a cell edit in place — it is a status table,
not a dated log). It is the fastest read of where each object actually stands.

## THE MISSION — what this tool is FOR (read before deciding what "done" means)

DMT2 **runs the Fusion import processes** for each object and then **accurately reports the
row-level outcome of every record** it sent: each record either **succeeded** (found in its
Fusion base table → LOADED) or **failed with a real Fusion error** (→ FAILED, carrying that
error). Nothing else counts as done.

The deliverable is **honest accounting, not clean data.** Concretely:

- **The job is to get each object's process running end-to-end** so that GOOD rows import to
  the base table AND BAD rows are reported with their real Fusion rejection message.
- **The job is NOT to fix every bad row.** A bad row that Fusion rejects is a SUCCESS for this
  tool — it was correctly imported-attempted and its real error was captured and reported. Do
  not "fix" test data to make a rejection disappear; that hides the very thing the tool exists
  to report.
- **Never fabricate an outcome.** LOADED only with a real base-table row; FAILED only with a
  real Fusion error string; otherwise the record is UNACCOUNTED (a defect in OUR code — we have
  not yet found where Fusion recorded the outcome), never a made-up verdict. Drive UNACCOUNTED
  to zero by FINDING the real outcome, never by inventing one.
- **Two honest failure shapes (get them right):**
  1. **Job succeeded but rejected some rows per-record** → capture the import/report job's
     output and mark each rejected row FAILED with its real message. (This is most objects.)
  2. **The job itself crashed at the job level** (e.g. a Fusion `ORA-01008` inside the costing
     proc; an AutoInvoice job-level abort) → Fusion produced NO per-row verdict, so every record
     is honestly left UNACCOUNTED and the object's tile renders **dark red**. Do NOT patch data
     to force the job to "succeed" — that hides an unaccounted-because-the-job-failed condition.
     Getting that job to run is a separate, later concern from accounting its records honestly.
- **"Getting an object running" ≠ making its data perfect.** It means the pipeline reaches
  Fusion, the good rows land in the base table, and the bad rows come back with real errors.

## Current posture (2026-07-07)

- **Docker-only.** No ATP exists yet — all work runs against the local Docker instance
  (`dmt2-local`, port **1523**). The new Always Free ATP comes later.
- **GitHub repo:** https://github.com/brianmakarewicz/DataMigrationTool — main is protected
  (pull request + 1 approval required, no force pushes). ALL changes go through PRs.
- **PR workflow:** this machine authors branches/PRs as brainmakeassistant. The reviewer is
  the GitHub Actions workflow `.github/workflows/pr-review.yml`, which fires **on every PR
  open / synchronize (push) / reopen / ready_for_review — event-driven, NOT hourly and NOT on
  a timer.** It reviews as brianmakarewicz and approves+merges clean PRs with an AUTOMATED
  APPROVAL banner (usually within minutes of opening or pushing), or requests changes with
  file/line findings. Never merge without its review; never wait for an "hourly" cycle.
- **Fusion BIP folder for this stack:** `/Custom/DMT2/` (never `/Custom/DMT/` — that belongs to the frozen stack).
- **FBL file delivery:** decision deferred (blocks the 6 FBL config objects only — Phase 4).
- **Frozen stack:** bugs may still be fixed on the old ATP; every such fix must be ported here.

## Local Docker DB

```bash
sh db/tools/build_local_db.sh            # bring up / reuse dmt2-local, install everything
sh db/tools/build_local_db.sh --fresh    # destroy + full rebuild
# connect: dmt_owner / DmtLocal#2026 @ //localhost:1523/FREEPDB1
```

Ports in use elsewhere: 1521 (rt-oracle-free), 1522 (old dmt-local). DMT2 = **1523**.

## Layout

| Dir | Contents |
|---|---|
| `db/` | Full schema: install.sql + sequences/tables/views/packages/procedures/jobs/seed/grants/synonyms + tools/ |
| `docs/` | THE requirements doc (DMT_DESIGN.html — the one and only copy; moved here 2026-07-08) + the rebuild plan (DMT_REBUILD_PLAN.html) + object catalog, coding-standards mirror, tranche-reviews/ |
| `objects/` | Per-CEMLI README.md (read before touching any object) |
| `bip/` | BIP data models + reports per CEMLI (deploy target `/Custom/DMT2/`) |
| `apex/` | DMTApplication.sql — the APEX app export (Data Migration Console); imported under a new app id per copy-before-modify |
| `test/` | Regression bundle + FBDI fixtures |
| `scripts/` | Core harness only: dmt_regression_run.py, dmt_run_assert.py, dmt_deploy.py, dmt_db_git_sync.py, insert_regression_test_data.py, hooks/dmt_db_guard.py |
| `cicd/` | GitHub Actions workflows + CI docker assets (to be built — Phase 1D) |

## THE OBJECT MODEL — repeatedly corrected; get it right (2026-07-08)

**One object = one FBDI zip = one load ESS job.** Nothing else defines an object.
- PurchaseOrders = ONE object; its single zip carries several CSVs (headers, lines,
  locations, distributions) = record types of one object.
- The supplier family = FIVE SEPARATE OBJECTS (Suppliers, SupplierAddresses,
  SupplierSites, SupplierSiteAssignments, SupplierContacts): five zips, five ESS jobs,
  chained by DEPENDS_ON. They are NOT sub-objects. Never use "sub-object" for them.
- Before describing ANY object's structure (chat, prompts, code, tests, PR bodies):
  read its rows in db/seed/dmt_cemli_catalog_tbl.sql and db/seed/dmt_pipeline_def_tbl.sql.
  The registry is the truth. Structure claims without that lookup are guesses.

## Rules carried over from the old stack (all still binding)

1. No test passes unless GOOD rows reach Fusion base tables (LOADED via BIP) AND BAD rows reach FAILED with reportable ERROR_TEXT.
2. Pure PL/SQL pipeline; Python is dev/test shim only.
3. Git-first DDL: DB changes only by running committed files. Never connect as ADMIN/SYSTEM for DMT DDL.
4. Prefix system always on (test 9001+); never reset STG/TFM row status — re-run with a new prefix.
5. Errors accumulate in ERROR_TEXT, never overwrite.
6. Read `objects/{Name}/README.md` before working on any CEMLI.
7. APEX work is deferred until the full regression scenario passes on the engine (see plan, Stage F).

## Blind tranche-review protocol (MANDATORY)

Every completed tranche gets a **blind subagent review** before the next tranche starts.
Tranche boundaries: all sequences · all tables · indexes/FKs/synonyms · all views · seed data ·
the common utility packages (Stage B) · then once after every ~5 object packages (Stages D/E).
Never per-object; never skipped.

Rules of the protocol:
1. The reviewer is **blind**: it gets no build context, rationale, or history — only
   "read the spec, review these files, report."
2. The reviewer **re-reads the canonical requirements doc — `docs/DMT_DESIGN.html` in this repo — in full at the start of every review**
   (the doc is in flux; never rely on a summary or a prior reading).
3. It reports: (a) requirement/naming violations, (b) internal inconsistencies across the
   tranche (same thing done two ways), (c) precisely-worded NEW coding-standard rules that
   would have prevented each class of drift found.
4. Proposed new rules are added to the coding-standards section of that canonical doc
   **in RED with a PROPOSED marker + date** (inline red styling inside the PROPOSED RULES block). Red = newly
   added and unverified — only the user promotes a red rule to accepted (normal styling).
5. Every finding is fixed or explicitly logged before the next tranche begins.

## Build-order status (plan section 4)

- [x] Stage A — Foundation DDL proven on dmt2-local (2026-07-07): fresh greenfield install
      from committed files; **DMT_OWNER baseline = 49 invalid** (all categorized:
      37 INTEGRATION_ID-drifted summary views pending usage check + 2 known-invalid
      packages + Fusion/DB-link-dependent objects), DMT_LOOKUP = 0 invalid / 17 seed rows,
      lookup install proven idempotent (double-run clean), heartbeat job created disabled
      and enabled as final install step. All 5 tranche blind reviews done and triaged
      (docs/tranche-reviews/); 28 proposed rules in RED in the canonical DMT_DESIGN.html
      (ConversionTool-dbfull/docs) section 7 awaiting user accept/reject.
- [x] Stage B (offline) — COMPLETE 2026-07-08: 4 unit suites green (util 31, csv 16,
      import-report 23, fusion skip-gated); golden files 15/15 from proven run 116;
      GLBalances generator byte-identical to frozen stack; 12+ real defects fixed
      (base64/32K family ×5, PARSE_ERRORS dead on 26ai, DMT_PIPELINE_INIT_PKG invalid,
      error-text-as-data, silent SOAP fault, scenario-mandatory, ESS pkg APEX dependency);
      blind utilities review PASS-WITH-FINDINGS, triaged in docs/tranche-reviews/.
      Invalid baseline now 47.
      **Stage B FULLY CLOSED 2026-07-08:** demo password rotated (5 users verified,
      hcm_impl added for HDL uploads); live Fusion suite 6/6 green (HTTP, BIP, fault,
      ESS poll, UCM upload). Open user decision: error-code-contract exception for the
      utility layer.
- [x] Stage C — COMPLETE (2026-07-08): prefix consolidated to one per-run sequence;
      3 decided control tables built+seeded; catalog-driven dispatch live (65 hardcoded
      branches retired); queue engine proven end-to-end with MockObject/MockChild (25/25);
      blind engine review PASSED after fixes. (DMT_PREFIX_HISTORY_V still pending — moved
      to the upstream Tier-2 worklist.)
- [x] Stage D — Suppliers vertical slice COMPLETE and CLOSED: all five supplier objects
      ran E2E through the real queue on the live demo instance (evidence, PR #16); blind
      re-review PASSED (#21). The six-step recipe is the template for every other object.
- [~] Stage E — Remaining Wave-1 objects IN PROGRESS: offline slices merged for GLBalances
      (#28), Customers (#29), Workers (#31), Projects (#30). Customers furthest along —
      Contract-v1 reconciler + base-table BIP report + live batch-id fix (#34-36).
      GLBalances per-line reconciliation (#41). GET_LOOKUP consolidation landed (#39).
- [ ] Stage F — Full regression gate → then APEX port

**ACTIVE PLAN (2026-07-12): upstream-first.** Clear the shared engine debt before driving
more Wave-1 objects live, so each object ports once. Full ordering: docs/DMT_REBUILD_PLAN.html
section 4.5 ("Backlog Coverage"). Status is tracked ONLY in docs/DMT_DESIGN.html section 12 —
check an item off there after it is fixed AND regression-tested.
