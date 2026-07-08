# Fixed Asset Load — Recovery Plan

> Status: **GATE OPEN — TESTING.** User disabled FA Additions approval on US CORP (2026-06-29 ~18:18).
> Stuck batches auto-posted: serial 2344567 now in `fa_additions_b` as ASSET_NUMBER=**113298**
> (SYSTEM-ASSIGNED — proven file left asset_number blank → confirms Fusion auto-numbers on POST).
> Now running fresh prefixed E2E test through the new Phase-2 orchestration.
> Owner: Claude Code (DB). Created: 2026-06-29.
>
> **ANCHOR QUESTION (live test settles it):** our generator SUPPLIES a prefixed asset_number.
> If Fusion honors it → prefix-LIKE reconcile works. If it auto-numbers anyway → switch anchor
> to serial/tag/DFF. Watch the fresh run's TFM asset_number vs `fa_additions_b`.

## Goal
Restore Fixed Assets to **E2E LOADED** using the proven-good `FaMassAddition.zip`
data, with a corrected **multi-stage ESS run** and a new **all-or-nothing per-FBDI**
reconciliation semantic, with **one FBDI per book**.

## LIVE TEST LOG (2026-06-29, gate open)

- **Run 104 (prefix 9615):** progressed AWAITING_LOAD → AWAITING_IMPORT (chained Prepare job
  9682872 found — job-order fix works), then FAILED at the postrun transition:
  `ORA-02290: DMT_WORK_QUEUE_STATUS_CK violated`. **BUG (live-caught):** the new
  `AWAITING_POSTRUN` status wasn't in the work-queue CHECK constraint. **FIXED** — added it to
  the live constraint + `schema/migration/phase1_pipeline_redesign.sql` + `deploy_phase1.py`.
  (Also: `INCLUDE_UNTAGGED=Y` with no scenario swept in ALL NEW rows, not just untagged ones —
  pulled in tagged REG-FA regression rows. For isolated tests, re-seed fresh untagged rows after
  a prior run has consumed the others, or use a dedicated scenario.)
- **Run 105 (prefix 9616):** clean good-only (FATEST-A1/A2). Flowed AWAITING_LOAD →
  AWAITING_IMPORT → **AWAITING_POSTRUN** (PostMassAdditions 9682976 submitted by the new Phase-2
  code) — then STUCK at poll=0. **BUG 2 (live-caught):** the heartbeat `dispatch_ess_polls`
  only spawned POLL_ONE for `AWAITING_LOAD/AWAITING_IMPORT`, not `AWAITING_POSTRUN` →
  the second-stage job was never polled. **FIXED** — added `AWAITING_POSTRUN` to the IN-list
  in `dmt_queue_pkg.pkb` (deployed VALID).
  - **PostMassAdditions 9682976 succeeded:** "2 records processed, 0 couldn't be processed."
  - **★ ANCHOR RESOLVED:** both assets posted to `fa_additions_b` with OUR prefixed numbers
    `9616FATEST-A1` / `9616FATEST-A2` (NOT auto-numbered). **Fusion HONORS a supplied
    asset_number** → the existing prefix-LIKE Tier-2 reconcile works AS-IS. No anchor change
    needed. (Proven manual file got auto-number 113298 only because it left asset_number blank.)
  - Interface rows: POSTING_STATUS=POSTED, LOAD_REQUEST_ID=9682887 (= load ESS = reconcile P_BATCH_ID).
  - GOOD path E2E proven: load → Prepare → Post → base table, with our prefix surviving.
- **★ TEST A PASSED (run 105):** after both bug fixes, the full flow completed
  `AWAITING_POSTRUN → RECONCILING → DONE`. HDR/BOOK/ASSIGN TFM all **LOADED (2/2)**;
  RUN_STATUS=**COMPLETED** (finalizes on a later heartbeat via `update_run_statuses` —
  the transient IN_PROGRESS was just timing). RULE #1 satisfied: GOOD rows reached
  `fa_additions_b`, confirmed by reconcile.
- **★ TEST B PASSED — ALL-OR-NOTHING DISPROVEN (run 106, prefix 9617):** 1 good + 1 bad in the
  SAME FBDI. Result: `HDR_TFM = {LOADED:1, FAILED:1}`.
  - `9617FATEST-B1` (good) → **LOADED** in `fa_additions_b` (asset_id 561148); interface POSTED.
  - `9617FATEST-B2` (bad, expense acct 15160) → **FAILED**, interface POSTING_STATUS=**ERROR**,
    real attributed error: *"You must enter a valid expense account ID..."*
  - PrepareMassAdditions output: "10 processed, 0 couldn't be processed" — it does NOT fail the
    file; it sets each row's posting_status (POST for good, ERROR for bad). PostMassAdditions
    posts only the POST rows.
  - **CONCLUSION: Oracle does PER-RECORD accounting, NOT all-or-nothing per FBDI.** The user's
    premise ("any bad row fails the whole FBDI") is empirically FALSE on this instance.
    **Phase 3 (all-or-nothing reconcile) should be DROPPED** — implementing it would wrongly fail
    genuinely-loaded rows. The EXISTING per-record reconcile is correct and already satisfies
    RULE #1 (good→LOADED in base, bad→FAILED with reportable error + row-level attribution).

## OUTCOME: Fixed Assets E2E LOADED — both tests pass. Phases 1–2 done; Phase 3 dropped (evidence).
## Regression data refreshed (script + scenario 1). Committed b04b0a4/2a3a75f.

## MULTI-BOOK PLAN (2026-06-30, in progress) — one FBDI per book
**Confirmed by user: one book per asset** (no shared header/assignment across books → clean).

**Finding:** the generic `split_multi_fbdi` won't work as-is — it queries the TFM table by
RUN_ID/status, but the transform that populates TFM runs INSIDE EXECUTE_ONE, AFTER the
SPLITTING phase. Naively adding Assets to `DMT_CEMLI_SPLIT_CFG` → split sees empty TFM →
0 partitions → "No qualifying rows" → breaks the run. (Partition infra is the pending
"Phases 9–11" redesign; PO uses a separate internal loop, incompatible with async.)

**Approach — transform-then-split for Assets:**
1. `g_partition_key` global on `DMT_LOADER_PKG`; `EXECUTE_ONE` sets it from queue row PARTITION_KEY.
2. Assets generator `GENERATE_FBDI(... p_partition_key)` filters FaMassAdditions + distributions
   to one BOOK_TYPE_CODE.
3. Assets EXECUTE_ONE flow: un-partitioned row → transform → split into per-book child queue
   rows (query populated BOOK TFM) → self DONE. Each child row (PARTITION_KEY=book) →
   generate(book) → load → Prepare → Post(book) → reconcile. Reuses AWAITING_POSTRUN.
4. `submit_postrun_job` uses queue row PARTITION_KEY as the book code (not MAX(book)).
5. Reconcile scoped per book (load_ess_id Tier-1 already per-FBDI; Tier-2 prefix matches the
   run — fine since one book per asset means each asset's number appears once).
Needs live test cycles. Lowest-risk first: generator filter + g_partition_key.

**IMPLEMENTED 2026-06-30 (compiled VALID; testing run 108, books US CORP + US FIN SVCS CORP):**
- Generator: `GENERATE_FBDI(... p_book)` + `gen_mass_additions_csv`/`gen_distributions_csv`
  filter by book; per-book filename; TFM status updates scoped to the book's assets.
- Loader: `g_partition_key` global; `RUN_ASSETS_TRANSFORM_ONLY` (validate+transform, no gen);
  `run_one_object_type` skips Assets validate+transform when partitioned and passes
  `g_partition_key` to GENERATE_FBDI.
- Queue worker `EXECUTE_ONE`: Assets un-partitioned row → transform-only → spawn one child
  queue row per distinct STAGED BOOK_TYPE_CODE → self DONE. Children (PARTITION_KEY=book)
  → generate(book) → load → Prepare → Post(book) → reconcile, each independent.
  (No `DMT_CEMLI_SPLIT_CFG` row — split done in EXECUTE_ONE after transform, since the generic
  split runs before transform and would see an empty TFM.)
- `submit_postrun_job` uses the queue row's PARTITION_KEY as the Post book code.
- Reconcile unchanged: Tier-1 per-FBDI load_ess_id; Tier-2 prefix is run-wide but the
  status filter + unique asset_numbers (one book per asset) prevent cross-book mis-attribution.

- **SUBMIT_OBJECTS hangs** (known SUBMIT_PIPELINE gotcha) — use inline create-run+queue SQL
  workaround (see `/tmp/fa_launch_inline.py` pattern) + ENSURE_POLLER_RUNNING.

## DECISIVE FINDING (2026-06-29) — approval workflow blocks posting

ESS logs of the manual run (via `DMT_ESS_UTIL_PKG.GET_ESS_OUTPUT_TEXT`):
- **PrepareMassAdditions (9682278):** "20 records processed, 0 couldn't be processed." Clean.
- **PostMassAdditions (9682284):** *"A transaction approval request has been raised for the
  batch FBDI2 … This transaction is submitted for approval. You can post the transaction
  only after it's approved."*

So assets are NOT loaded — `PostMassAdditions` only raises an approval request; the asset
stays at `posting_status=POST` and never reaches `fa_additions_b`. RULE #1 holds. The
blocker is the **FA Additions Approval workflow** on the demo instance. The reconcile-target
question is moot: once the approval gate is cleared, assets post to base and the existing
base-table reconcile is correct.

**Fork — how to clear the gate:**
- (1) **Disable Additions approval on the US CORP book** (FSM / Transaction Console) — one-time,
  then Post posts directly. Matches prior-session "Option A." **RECOMMENDED.** Needs Fusion
  config access (UI); no confirmed REST to toggle it.
- (2) Auto-approve the pending BPM task via REST — **CONCLUSIVELY INFEASIBLE with current
  creds.** Probed `/bpm/api/4.0/tasks` as all 4 DMT users (fin_impl, calvin.roth,
  natalie.salesrep, scm_impl) across assignmentFilter Admin/Group/Reportees/Owned/Creator:
  the FA additions approval task is not visible/actionable to any of them. Would need the
  actual approver's credentials.
- (3) Override RULE #1 for Assets (treat POST as loaded) — rejected; masks the gate.

**BLOCKED ON USER:** clearing the approval gate requires either (a) disabling Additions
approval on the US CORP book in Fusion, or (b) supplying the approver's credentials. Until
then, no Assets run can post to `fa_additions_b`, so Phases 2–6 cannot be validated.

## What is DONE and ready (no further work possible until gate cleared)
- Phase 1: job order swapped (live ATP + seed override). IMPORT=PrepareMassAdditions,
  POST_LOAD=PostMassAdditions.
- `SUBMIT_IMPORT_JOB` parametrized (book-code paramList + `;`/`,` delimiters); body VALID.
- Diagnostic report `DMT_FA_DIAG` deployed; `scripts/fa_diag_deploy_run.py` works
  (the ONLY working ad-hoc Fusion read path now that runDataModel is dead).
- Confirmed: Prepare processes 20/0; Post raises approval, asset stuck at posting_status=POST.

## CRUX FINDING (2026-06-29) — reconcile target is wrong (SUPERSEDED by above)

Deployed a diagnostic BIP report (`/Custom/DMT/common/DMT_FA_DIAG_RPT`, source
`bip/common/DMT_FA_DIAG_DM.xdm`; run via `scripts/fa_diag_deploy_run.py`). Evidence:
- The proven asset (serial `2344567`, `load_request_id=9682258`) and the manual screenshot
  run (`load_request_id=9682273`) are ALL in `fa_mass_additions` with **`posting_status=POST`**.
- **ZERO rows in `fa_additions_b` created in the last 30 days** — nothing has reached the
  base table, including the run the user called "successful."
- Therefore our reconcile (Tier-2 = `fa_additions_b` base table, prefix match) can never
  succeed on this instance. The asset's success signal lives in `fa_mass_additions`
  (`posting_status`), not the base table.

**Implication:** "LOADED" for Assets on this instance most likely means
`fa_mass_additions.posting_status = POST/POSTED` after PostMassAdditions SUCCEEDED — not a
base-table row. Reconcile must be re-pointed at the interface table's posting_status.
Awaiting user confirmation of the success definition before rebuilding reconcile.

## SESSION FINDINGS (2026-06-29) — read before executing

- **`runDataModel` is DEAD on the refreshed instance.** Ad-hoc Fusion SQL via
  `v2/ReportService runDataModel` now returns `Unmarshalling Error: unexpected element
  dataModelReport`. All `diag_fa_*.py` scripts that used it fail. **Only `runReport`
  against pre-deployed `.xdo` reports works.** To inspect base tables ad-hoc we must
  deploy a diagnostic report (FBT deploy path, as `deploy_bip_reports.py` uses).
- **Proven-good file leaves `ASSET_NUMBER` BLANK** (CSV field 4, confirmed by mapping the
  proven CSV against `FaMassAdditions.ctl`). Fusion auto-assigns the number on POST.
- **Our generator DOES populate `ASSET_NUMBER`** (field 4) with the prefixed value
  (`9613RT-ASSET-G1`). Standard FBDI Mass Additions *honors* a supplied asset number — so
  **root cause #2 (anchor) is a RISK TO VERIFY, not a confirmed bug.** Once the job order
  is fixed and assets actually post, our prefixed asset_number may survive and the existing
  prefix-LIKE reconcile may just work. **Disentangling experiment:** fix job order → staged
  run with our prefixed data → read `fa_additions_b` → did asset_number survive?
  If YES, keep asset_number anchor. If auto-numbered, switch anchor to a controllable
  pass-through that survives: `SERIAL_NUMBER`, `TAG_NUMBER`, `ASSET_KEY_SEGMENT1`, or DFF
  `ATTRIBUTE1..30` (proven file's `TEST1/TEST2` land in the DFF attributes).
- **Phase 1 swap rationale:** for OUR orchestration, the chained-import job (run inside
  `loadAndImportData`/`SUBMIT_LOAD`, consumes `IMPORT_JOB_NAME`) must be
  **PrepareMassAdditions**; the standalone follow-up (Phase 2, consumes `POST_LOAD_JOB_NAME`
  via `SUBMIT_IMPORT_JOB`) must be **PostMassAdditions**. Current config has these reversed.
  Seed file only sets CEMLI_CODE (job names inherited from base row 9) — add an explicit
  override.
- **Delimiter:** `SUBMIT_LOAD` splits `IMPORT_JOB_NAME` on `;`; `SUBMIT_IMPORT_JOB` splits
  on `,`. Make `SUBMIT_IMPORT_JOB` accept both (GREATEST(INSTR ',', INSTR ';')) in Phase 2.

## Root causes confirmed this session (runs 99–102 all `RECONCILE_ERROR`)
1. **Jobs reversed in config.** `DMT_ERP_INTERFACE_OPTIONS_TBL` for Assets has
   `IMPORT_JOB_NAME = …additions;PostMassAdditions` and
   `POST_LOAD_JOB_NAME = …additions;PrepareMassAdditions`.
   The proven manual run (ESS screenshot 6/29) ran **PrepareMassAdditions** as the
   import-stage job (child of `InterfaceLoaderController`), then **PostMassAdditions**
   as a separate submission.
2. **Second stage never runs.** `POST_LOAD_JOB_NAME` is referenced by **zero** lines
   of package code. The queue worker has no second-stage sequencing.
3. **Consequence:** rows never reach the base table (`FA_ADDITIONS_B`) → every run
   dies at `RECONCILE_ERROR` ("row not found in interface or base table").

## Agreed behavior (locked with user)
- **STG → TFM:** selective failure is fine. A bad record can drop out before transform
  without affecting siblings. Unchanged.
- **TFM → Oracle import:** **all-or-nothing per FBDI.** If any one record in an FBDI
  fails on the Oracle import side, that **entire FBDI** fails → every TFM row that fed
  that FBDI is marked FAILED. We must *prove* Oracle behaves this way via the two tests.
- **Scope = one FBDI only.** A failure in one FBDI must NOT touch other FBDIs. No global
  flag, no whole-run cascade.
- **One FBDI per book.** Parse distinct `BOOK_TYPE_CODE`; generate and run a **separate**
  FBDI end-to-end per book (separate load/import/post/reconcile). No shared post step.
- **Mechanics are a black box.** Run all ESS stages first, *then* check pass/fail.
  Replicate the staged sequence the manual run used; do not editorialize on internals.

## Phases

### Phase 0 — Prove the staged sequence AND find the reconcile match key
**Widened success bar (per advisor):** the deliverable is not just "data landed" but
"data landed AND I know which column reconcile must match on." Mass Additions typically
**auto-assigns asset_number on POST**, yet our reconcile matches
`FA_ADDITIONS_B.ASSET_NUMBER LIKE :prefix||'%'`. If the supplied asset_number does not
survive, reconcile finds nothing and reports the *identical* `RECONCILE_ERROR` — a second
root cause the job-swap does NOT fix. Resolve this in Phase 0.

- **0.1 (read-only):** the manual run already posted an asset. Query `FA_ADDITIONS_B` now
  for it — `asset_number, tag_number, serial_number, attribute_category, attribute1..15` —
  and answer: is `asset_number` our CSV value or system-generated? Which column carries the
  file's `TEST1/TEST2/FBDI1` markers? Whatever we **control AND survives** is the reconcile
  anchor. If it isn't `asset_number`, the prefix-LIKE reconcile is itself a root cause.
- **0.2 (read-only):** pull proven ParameterLists from `ESS_REQUEST_HISTORY` (via BIP) for
  the manual run's request IDs (Prepare 9682278, Post 9682284). Ground truth for both stages.
- **0.3:** replicate the staged run with a prefix/marker: `SUBMIT_LOAD` (Prepare, `;`
  delimiter, proven paramList) → poll → standalone Post (proven paramList) → poll → confirm
  our marker in `FA_ADDITIONS_B`.
- **0.4 (bad-row probe):** push a good+bad FBDI and observe whether Prepare **whole-file
  fails** or **partially prepares**. This observation drives Phase 3 (do not assume).

**Primitive fixes required before 0.3 (per advisor):**
- Parametrize `SUBMIT_IMPORT_JOB` to accept a paramList (it hardcodes `NEW,N,<run_id>`);
  Prepare/Post need Book Type Code.
- Mind the delimiter: `SUBMIT_LOAD` expects `;`, `SUBMIT_IMPORT_JOB` splits on last `,`.

### Phase 1 — Fix the config
Swap the Assets row in `DMT_ERP_INTERFACE_OPTIONS_TBL` so `IMPORT_JOB_NAME` =
PrepareMassAdditions and `POST_LOAD_JOB_NAME` = PostMassAdditions. Update the seed file
`schema/seed/04_dmt_erp_options_cemli_seed.sql` to match (survive redeploy).

### Phase 2 — Per-book grouping + staged run in the queue worker
- Generator groups Assets by `BOOK_TYPE_CODE` → one FBDI zip per book.
- Each book runs the full staged ESS sequence independently (import-stage job, then the
  standalone `POST_LOAD_JOB_NAME` job), each polled to terminal before reconcile.

**IMPLEMENTED 2026-06-29 (compiled VALID; gated-validation pending).**
- `SUBMIT_IMPORT_JOB` exposed in loader spec (was body-private).
- `DMT_QUEUE_WORKER_PKG.submit_postrun_job` helper added: looks up `POST_LOAD_JOB_NAME`,
  derives book-code paramList for Assets (`MAX(BOOK_TYPE_CODE)` from book TFM), submits.
- `POLL_ONE`: `AWAITING_IMPORT` success → submit post-run → new `AWAITING_POSTRUN` state →
  poll → `RECONCILING`. Reuses existing `POSTRUN_ESS_JOB_ID` column (no DDL; views/APEX
  already display it). Zero blast radius — only Assets has `POST_LOAD_JOB_NAME`.
- STILL GATED: exact PostMassAdditions paramList format, and the per-book grouping in the
  GENERATOR (one zip per book → one queue row per book). Current code handles single-book
  runs via MAX(book); multi-book needs the generator/partition split (next step).

**ORIGINAL DESIGN NOTES (traced 2026-06-29) — async state machine in `DMT_QUEUE_WORKER_PKG.POLL_ONE`.**
Current async flow: `AWAITING_LOAD → AWAITING_IMPORT → RECONCILING` (EXECUTE_ONE submits
load via RUN_ASSETS async, POLL_ONE walks states, RECONCILE_ONE reconciles). The Post stage
is a NEW state inserted before RECONCILING:
1. **DDL:** add `POST_LOAD_ESS_JOB_ID` column to `DMT_WORK_QUEUE_TBL`.
2. **New status `AWAITING_POST_LOAD`.**
3. In POLL_ONE `AWAITING_IMPORT` success branch (line ~376-387): instead of always →
   RECONCILING, look up `POST_LOAD_JOB_NAME` for the CEMLI. If present → call
   `SUBMIT_IMPORT_JOB(run_id, post_load_job, <post_param_list>)`, store id in
   `POST_LOAD_ESS_JOB_ID`, set status `AWAITING_POST_LOAD`, POLL_COUNT=0. If absent →
   RECONCILING (unchanged — every other CEMLI keeps current behavior).
4. Add `WHEN 'AWAITING_POST_LOAD' THEN POST_LOAD_ESS_JOB_ID` to the `l_ess_id` CASE (line ~312).
5. New success branch for `AWAITING_POST_LOAD` → RECONCILING.
6. **Credential note:** the Post submit + poll must use the same per-CEMLI user as the load
   (GET_CEMLI_CREDENTIALS) — polling another user's ESS request 500s (see Runs 86/96/97).
   `SUBMIT_IMPORT_JOB` currently uses default `erp_soap_url`/creds — may need a user override
   param for the Assets fin_impl user.
7. **GATE-DEPENDENT UNKNOWN:** the exact PostMassAdditions ParameterList (book code; README
   says `US CORP,,NORMAL`). Discover from the proven run / verify at the gated run before trusting.
   `SUBMIT_IMPORT_JOB` is already parametrized to accept it.
Why not built blind now: async state-machine correctness (re-poll, timeout, per-user ESS
creds) is validated by running it, plus the paramList is unverified — high rework risk
until an asset can post.

### Phase 3 — All-or-nothing reconcile, scoped per FBDI
**Design driven by Phase 0.4 observation, not assumption.** If Oracle whole-file-fails on
any bad row: after a book's FBDI import reaches terminal, if **any** row in that FBDI
failed / didn't reach `FA_ADDITIONS_B`, mark **all** TFM rows that fed *that* FBDI as
FAILED — real error on the offending row, cascade note on siblings naming it. If Oracle
*partial*-prepares (some good rows post despite a sibling failing), revisit: marking all
FAILED would wrongly fail genuinely-loaded rows. Other books' FBDIs untouched. No config
flag; Assets reconciler behavior. Match on the Phase-0 anchor column, not blindly asset_number.

### Phase 4 — Align generator + STG test data to proven values
**Static generator review (2026-06-29, gate-independent):** first 23 fields map structurally
to the CTL — no column-drift in the head. Two VALUE diffs vs the proven file to verify during
the gated run (do NOT change blind):
- Field 3 `TRANSACTION_NAME`: proven = `Addition`, generator emits blank.
- Field 23 `QUEUE_NAME`: proven = `POST`, generator emits blank (POSTING_STATUS=POST is set).
Also: `test_assets_pipeline.py` is STALE (old INTEGRATION_ID/RUN_ASSETS model, not RUN_ID/queue).
A generate-and-diff vs the proven zip (423 hdr / 67 dist cols) is the right gate-independent
check but needs a fresh RUN_ID-model harness — fold into Phase 0.3 setup.

Reverse-map the proven CSV into STG columns so our generator reproduces an equivalent
file: prorate `CAL MONTH`, category `EQUIPMENT/MANUFACTURING`, expense acct
`101.10.68130.000.000.000`, location `USA/NEW YORK/NEW YORK`, book `US CORP`, cost
120000, STL/120mo, DPIS 2025/06/01. Verify generated column counts (423 hdr / 67 dist)
against the proven file.

### Phase 5 — Two test runs (UsePrefix=Y)
- **Test A (all-good):** 1–2 good assets → all reach **LOADED**, confirmed in
  `FA_ADDITIONS_B`.
- **Test B (good + bad in one book's FBDI):** bad row fails on the Oracle import side →
  capture its real error and mark **all** rows in that FBDI FAILED, with nothing
  committed to the base table. Proves the all-or-nothing behavior is real.

### Phase 6 — Lock in
Update regression data, `objects/Assets/README.md`, `status.md`; run Assets regression;
commit & push.

## Reference facts
- Proven file: `C:\Users\Monroe\Downloads\FaMassAddition.zip`
  - `FaMassAdditions.csv`: 1 row, 423 fields (US CORP, Equipment, $120000, CAL MONTH,
    EQUIPMENT/MANUFACTURING, STL/120mo, DPIS 2025/06/01, POST,POST at pos 22-23)
  - `FaMassaddDistributions.csv`: 1 row, 67 fields (units 1, USA/NEW YORK/NEW YORK,
    acct 101.10.68130.000.000.000)
- ESS screenshot (6/29 2:36–2:38 UTC): InterfaceLoaderController 9682273 →
  PrepareMassAdditions 9682278 (Succeeded), then PostMassAdditions 9682284 (Succeeded).
- Primitives: `DMT_LOADER_PKG.SUBMIT_LOAD` (loadAndImportData),
  `SUBMIT_IMPORT_JOB` (standalone submitESSJobRequest), `POLL_ESS_JOB`.
