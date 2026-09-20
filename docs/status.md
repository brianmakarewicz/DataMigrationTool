# DMT2 -- Session Status Log

## Session -- 2026-09-20 -- Backlog #11 done (config objects), #12 foundation + proof; six config objects moved to BIP reconcile

**Headline:** The six REST-loaded configuration objects now reconcile the same way as every
other object -- a BIP report over the Fusion base tables that also captures the Fusion id --
and the foundation for stamping a run-scoped reference on every record was built and proven
end-to-end on GLBalances. All work is on `origin/main` except one open PR (#314).

**Work completed this session (verified against `gh pr view`):**
- #297 Requisitions -- a rejected header now cascades its real error to its child line and
  distribution, so they are no longer left unaccounted. MERGED.
- #298 Projects -- an orphan task (parent project not in the batch) is rejected at
  pre-validation, scenario-scoped and safe in ALL mode. MERGED.
- #299 Docs status update. MERGED.
- #300 HDL -- the base-table retry window was widened (about an 11.5-minute backoff) so Workers
  no longer intermittently land unaccounted while Fusion is still writing the base row. MERGED.
- #301 TaxCards -- capture the Fusion calculation-card id on reconcile (backlog #11). MERGED.
- #302 UnitsOfMeasure -- capture the Fusion UOM id (interim). MERGED.
- #303 Requirement (PROPOSED, red): reconciliation MUST occur via a BIP report over the Fusion
  base tables, for every object. MERGED -- **still PROPOSED/red; the owner has NOT yet promoted
  it to accepted. This is an OPEN OWNER ACTION.**
- #304 REST reconcilers -- use the database default certificate store instead of forcing a
  wallet (fixed ORA-29273; no wallet needed locally). MERGED.
- #305-#310 The six REST config objects were converted to BIP base-table reconciliation with
  Fusion-id capture: UnitsOfMeasure (#305, with #302), ValueSets (#306), PaymentTerms (#307),
  Taxes/TaxConfig (#308), CashBanks/Banks (#309), Lookups (#310). All MERGED. Lookups has no
  numeric surrogate id, so its `FUSION_*_ID` columns are intentionally NULL -- existence in the
  base table is the proof.
- #311 Backlog #12 FOUNDATION -- the `DMT_REF_CARRIER_CFG_TBL` config table + a 39-row seed +
  the `DMT_REF_ID_PKG` id-writer (`BUILD_REF` produces `DMT:<run_id>:<work_queue_id>:<tfm_seq_id>`). MERGED.
- #312 Config transforms -- scope the staging selection to the run's scenario (fixed an ALL-mode
  cross-scenario pull that overflowed the ValueSets reconciliation parameter). MERGED.
- #313 REST reconcilers -- gunzip response bodies so a bad row's error text is human-readable
  (shared `DMT_UTIL_PKG.GUNZIP_RESPONSE`). MERGED.
- #314 Backlog #12 PROOF-OF-RECIPE on GLBalances -- stamp the run-scoped per-record reference
  end-to-end; the round-trip is PROVEN (`GL_JE_LINES.REFERENCE_2` = the built reference).
  **OPEN at session close -- verify and merge next session.**

**Key decisions and findings to preserve:**
1. Backlog #11 (capture the Fusion id on reconcile) is DONE for every config object that has a
   surrogate id. Lookups has none; that is documented, not a gap.
2. Backlog #12 design is OWNER-APPROVED: a per-record reference
   `DMT:<run_id>:<work_queue_id>:<tfm_seq_id>` written ALWAYS, including cutover. Each object has
   three carrier slots stored in `DMT_REF_CARRIER_CFG_TBL`: Slot A = the native source-reference
   field, gets the TFM id; Slot B = the native batch field, gets the run id; Slot C = a
   base-table column that ROUND-TRIPS, gets the full reference. Reconciliation matches on the TFM
   id; the run and work-queue ids are provenance. GLBudgets is the only object with no carrier --
   it falls back to a business-key reconcile (flagged).
3. CRITICAL #12 finding from the GLBalances proof: Slot C must be a column the object's import
   ACTUALLY carries to the base table -- do NOT assume it just because the base table has an
   ATTRIBUTE column. `GL_INTERFACE.ATTRIBUTE20` does NOT round-trip; the working path was
   `REFERENCE22` into `GL_JE_LINES.REFERENCE_2`. The 39-row seed's Slot C ATTRIBUTE choices are
   UNVERIFIED and must be verified per object during fan-out. This is the main risk for the #12
   fan-out.
4. The #12 fan-out to the remaining ~27 objects is NOT started. It is gated on (a) disk space
   (the Docker disk image is about 95 GB and C: is full, so new git worktrees fail -- owner is
   considering an external SSD then relocating the Docker disk image) and (b) per-object Slot C
   verification.
5. The Fusion demo password rotated mid-session. It was propagated everywhere via the
   rotate-demo-password skill (ATP config, local config, both `DMT_ERP_INTERFACE_OPTIONS_TBL`
   override tables, Vercel); all 5 demo users verified HTTP 200. The mid-run 401 wave in the big
   regression (run 294) was THIS rotation, not code.
6. Regression harness finding: write-once scenarios ACCUMULATE in shared staging, so an ALL-mode
   transform that does not filter by scenario pulls cross-scenario rows (fixed for the six config
   objects in #312; other objects already filtered). A full-regression run's red is often
   environmental (password rotation, scenario accumulation), not code -- classify failures against
   the prior baseline before calling anything a regression.
7. The fusion-bip MCP server holds a STALE in-memory password (cached before the rotation);
   `connections.json` and the database are current. Restart the MCP server next session to clear it.
8. Known residual OUR-side accounting gaps still open (NOT this session's regressions):
   AR AutoInvoice (job-level abort), MiscReceipts, ProjectBudgets (no carrier, newly exposed by
   scenario coverage). Grants is an environment issue (module not configured). All pre-existing.

**Docs updated this session (this PR):**
- `docs/DMT_REBUILD_PLAN.html` -- object status matrix: the six config rows now say
  reconcile-via-BIP + id-captured; GLBalances row notes it is #12-wired (proof, PR #314 open).
- `docs/backlog.html` -- #11 marked RESOLVED (config objects); #12 detail rewritten with the
  approved design, the Slot-C-must-round-trip finding, and fan-out-pending status; summary counts
  adjusted; #64 (P3) intact. JSON validated (64 items parse).
- `docs/DMT_DESIGN.html` -- open-items list: #11 config-objects RESOLVED note, #12 foundation +
  proof note, and the reconcile-via-BIP requirement note updated to record the conversions landed
  while staying PROPOSED (red) awaiting owner promotion. All additions red-styled; the design
  guard passed.

**NEXT-SESSION START LIST:**
1. Restart the fusion-bip MCP server to clear its stale cached password.
2. Resolve disk space (external SSD, then relocate the Docker disk image) BEFORE starting the
   #12 fan-out -- new git worktrees currently fail because C: is full.
3. Verify and merge PR #314 (GLBalances #12 proof).
4. Fan out #12 to the remaining objects, verifying the Slot C round-trip per object.
5. Owner to promote the reconcile-via-BIP requirement from PROPOSED to accepted (once satisfied).

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
