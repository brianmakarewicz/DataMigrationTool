# Contract v1 Reconciliation — Conformance Plan and Final State

**Status as of 2026-09-21.** This document tracks the effort to put every FBDI (and HDL)
object onto one uniform reconciliation contract, the post-run reporting layer that reads it,
and the APEX console that surfaces it. It is the companion to the Object Status Matrix in
`docs/DMT_REBUILD_PLAN.html` section 0 and the session log in `docs/status.md`.

## What "Contract v1" means

Every object reconciles through **one** nine-column BIP report shape and **one** shared
reader, instead of a bespoke reconciler per object. The nine columns are:

`OBJECT_TYPE, RECORD_KEY, SOURCE_TYPE, FUSION_STATUS, FUSION_ID, ERROR_MESSAGE, LOAD_REQUEST_ID, SOURCE_REF, DMT_REFERENCE`

The shared reader `DMT_RECON_CONTRACT_PKG.FETCH_ROWS` pages the report with a keyset (no
dynamic SQL); a small per-object `APPLY_CONTRACT_V1_<obj>` does static MERGEs into that
object's transform (TFM) table(s). Template package: `db/packages/dmt_worker_results_pkg.pkb.sql`
(GL uses its own equivalent, `dmt_gl_results_pkg`).

**The one rule that makes it work:** the transform must stamp `RECON_KEY` equal to the
report's `RECORD_KEY`, per tier. Multi-tier objects stamp per TFM table. If the two keys do
not match, the MERGE finds nothing and every row lands UNACCOUNTED.

**A reconciliation move is a package deal.** For any object, the reader code, its registry row,
and its BIP data model must all move together in the same change. A pull request that ships only
the data model (a "DM-only" recon change) is a half-migration and the automated reviewer rejects
it — nothing consumes the DM yet, so no rows reconcile.

**The six FBL config objects are deliberately NOT on Contract v1** (owner decision). They
reconcile inline during load. Leave them as-is.

## Final state (all merged unless noted)

### 1. FBDI reader migrations — DONE (15/15 merged)

All fifteen FBDI reader migrations are merged to `origin/main`. Each object now reconciles via
the shared `FETCH_ROWS` plus its own `APPLY_CONTRACT_V1_<obj>`. The final tranche of merges
included the PO family (PurchaseOrders / BlanketPOs / Contracts, 4-tier, PR #374), Assets
(PR #373), Grants award-header (PR #375), ARInvoices (2-tier, PR #371), Items (PR #368), and
Customers (PR #361), with Expenditures registered at `CONTRACT_VERSION=1` (PR #376).

### 2. Post-run reporting (backlog #66) — DONE (PR #377)

`DMT_RUN_SUMMARY_PKG` (GET_RUN_ROLLUP, GET_RUN_RECORDS, AUDIT_IN_FUSION) reads the per-record
UNION view `DMT_RUN_RECORDS_V`. The view carries the FUSION_ID and a build reference per record
and a deep link via `DMT_UTIL_PKG.GET_DEEP_LINK`. It is golden-equivalent to the older
`DMT_RUN_STATUS_V`. Files: `db/packages/dmt_run_summary_pkg.{pks,pkb}.sql`,
`db/views/dmt_run_records_v.sql`.

### 3. APEX recon console — merged, one fix in flight

- **App 501 (alias LIVEDMT2R), copied from 500**, surfaces the LOADED / FAILED / UNACCOUNTED
  tiles plus the nine-column reference columns on pages 52 and 57 (PR #378, merged).
- **Record-drill fix (PR #381, OPEN):** the page-52 to page-57 record drill returned a blank
  because the deployed record-detail view lacked columns the page selected (FUSION_ID /
  SOURCE_REF / DMT_REFERENCE) — PR #378's view change never actually deployed, so the region
  silently rendered nothing. This PR restores the drill. It is the last recon-UI change and is
  awaiting the automated reviewer.

### 4. Regression run 325 (2026-09-21) — net win, two regressions found and fixed

Run 325 was a clear net improvement: PurchaseOrders, Requisitions, APInvoices, BlanketPOs,
Contracts, SupplierContacts, and SupplierSiteAssignments all went from fully unaccounted to
loading correctly. The run surfaced two regressions, both fixed:

- **Customers — deploy-tool base64 overflow (PR #379).** `DMT_BIP_DEPLOY_PKG` used
  `RAW(32767)` for the base64 envelope, which overflowed on data models ≥ ~24 KB and blocked
  the Customers reconcile. Fixed by chunking at 22,500 bytes.
- **Projects — Txn Controls now reconciles from the real base table (PR #380).** Txn Controls
  is now marked LOADED from the real Fusion base table `PJC_TRANSACTION_CONTROLS`. Team Members
  is honestly left UNACCOUNTED (no queryable base-table outcome for that tier yet) rather than
  fabricating a verdict.

## Remaining gate

**Confirmatory clean regression run** once PR #377 (reporting), PR #380 (Projects), and PR #381
(APEX drill) are all merged, to prove the full set holds end-to-end with no new UNACCOUNTED.
This is the only open gate for the Contract v1 conformance effort.

## Shared reconcile settle + re-read before finalizing UNACCOUNTED (Backlog #147)

**Applies to every object**, implemented once in the shared reconcile path
(`DMT_QUEUE_WORKER_PKG.RECONCILE_ONE`), not per reconciler.

**Why.** A reconciler confirms a GOOD row LOADED only when it reads that row in
the Fusion base table (the Contract v1 nine-column recon report). A load/import
ESS job can report terminal (SUCCEEDED/WARNING) a short moment before a
just-created row becomes visible to that base-table query. This is a
commit/visibility lag, not a missing wait and not a missed request: the pipeline
already polls the job to terminal and the reconciler already reads every request
for the run. Read a beat too early, a GOOD row would be swept to UNACCOUNTED.
(First observed for Items in run 205: GOOD item RT-PLAIN-001 was concluded "not
created in base table" yet a REST re-check confirmed it was present in Fusion.)

**What.** Immediately before the shared unaccounted sweep finalizes anything,
`RECONCILE_ONE` counts the rows still awaiting base-table confirmation — still
GENERATED with no `[FUSION_ERROR]`, from the shared `ACCOUNT_ROWS` x_awaiting_base
count. If there are any, it waits `RECONCILE_SETTLE_SECONDS` and re-reads the base
table (by re-invoking that object's own registered reconciler), up to
`RECONCILE_MAX_RETRIES` times, stopping early as soon as none remain. A row that
appears is promoted to LOADED with its real base id; anything still absent after
the last retry falls through to the honest sweep (UNACCOUNTED) exactly as before.
It never fabricates LOADED.

**Guards (so it never wastes time).** The wait fires only when BOTH:
(a) the object's import ESS reached SUCCEEDED/WARNING this run (a late commit is
only plausible after a successful import; a job-level crash is honestly
UNACCOUNTED/dark-red, nothing to wait for — no delay added); AND (b) there are
rows awaiting base-table confirmation. A row that reconciled on the first pass is
already LOADED/FAILED, so it is never in the awaiting set — it short-circuits with
no wait and no change to its outcome. The retry fires **per object** (re-reading
all that object's awaiting rows together in one re-read), so the worst-case added
time is `RECONCILE_SETTLE_SECONDS × RECONCILE_MAX_RETRIES` once per
object-with-awaiting-rows (~60s with the defaults), never per row. HDL base-proof
objects keep their own longer base-lag deferral and are skipped here.

**Config keys** (`db/seed/dmt_config_tbl.sql`, read via `DMT_UTIL_PKG.GET_CONFIG`):

| Key | Default | Controls |
|---|---|---|
| `RECONCILE_SETTLE_SECONDS` | `30` | Seconds to wait before each base-table re-read. `0` disables the wait. |
| `RECONCILE_MAX_RETRIES` | `2` | Maximum settle-and-re-read passes per object before the sweep finalizes. `0` disables retries. |

## Related

- `docs/DMT_REBUILD_PLAN.html` section 0 — per-object Object Status Matrix (single source of
  truth for live status).
- `docs/status.md` — dated session log.
- Cross-session memory: `project_dmt2_reconciliation_uniform`.
