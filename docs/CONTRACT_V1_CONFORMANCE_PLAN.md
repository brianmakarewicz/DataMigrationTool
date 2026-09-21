# Contract v1 Reconciliation — Conformance Plan and Final State

**Status as of 2026-09-21 — BATCH CORE COMPLETE, two items still OPEN.** The batch core is done:
every FBDI transactional reader is on the uniform nine-column contract and reconciles good rows to
LOADED and bad rows to FAILED with real Fusion errors. But this batch is **not** fully closed —
two items remain open and are called out below: (1) **Customers**, where the reconciler now runs but
28 records came back UNACCOUNTED after a successful import; and (2) **Projects Team Members**, where
a fix is in progress to reconcile from the real Fusion base table. Do not read this document as
"both regressions closed."

This document tracks the effort to put every FBDI (and HDL) object onto one uniform reconciliation
contract, the post-run reporting layer that reads it, and the APEX console that surfaces it. It is
the companion to the Object Status Matrix in `docs/DMT_REBUILD_PLAN.html` section 0 and the session
log in `docs/status.md`.

## Honest scorecard (2026-09-21)

**Batch core — COMPLETE.** All FBDI transactional readers reconcile correctly on the confirmatory
run 327 (prefix 10267): GL, AP, PO, BlanketPOs, Contracts, Requisitions, all five Suppliers objects,
Assets, Expenditures, and BillingEvents each resolve good rows to LOADED and bad rows to FAILED with
0 unaccounted. `dmt_run_assert` is clean, and the deploy-tool base64 overflow (PR #379) is fixed so
the Customers reconcile report now deploys.

**Two items still OPEN — do not call these closed:**

1. **Customers — 28 records UNACCOUNTED after a successful import (STILL OPEN, backlog #70).** The
   #379 deploy crash is fixed and the reconciler now runs, but no records reach LOADED or FAILED —
   28 came back UNACCOUNTED. That is a real accounting gap. Root-cause needed: are the loaded rows
   sitting in the base table under a key the Customers recon report does not match, or were they
   rejected without their error being captured? Drive to zero unaccounted by finding the real
   outcome, never inventing one.
2. **Projects Team Members — reconcile from the real base table (IN PROGRESS, backlog #68).** This
   is **not** an accepted UNACCOUNTED state and **not** a Rule #1 exception. A queryable Fusion base
   table for project team members does exist — the earlier "no base table" claim was wrong, exactly
   like Transaction Controls, which turned out to reconcile from `PJC_TRANSACTION_CONTROLS`. A fix is
   in progress on branch `fix/projects-teammembers-basetable` to find that table and reconcile Team
   Members to LOADED. Until it lands, Team Members records are honestly UNACCOUNTED, but that is a
   defect to fix, not an end state.

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

### 3. APEX recon console — merged

- **App 501, copied from 500**, surfaces the LOADED / FAILED / UNACCOUNTED
  tiles plus the nine-column reference columns on pages 52 and 57 (PR #378, merged). The old
  app 500 was archived to a separate alias so 501 is the live console.
- **Record-drill fix (PR #381, merged):** the page-52 to page-57 record drill returned a blank
  because the deployed record-detail view lacked columns the page selected (FUSION_ID /
  SOURCE_REF / DMT_REFERENCE) — PR #378's view change never actually deployed, so the region
  silently rendered nothing. This PR restores the drill. It was the last recon-UI change.

### 4. Regression run 325 (2026-09-21) — net win, two regressions found and fixed

Run 325 was a clear net improvement: PurchaseOrders, Requisitions, APInvoices, BlanketPOs,
Contracts, SupplierContacts, and SupplierSiteAssignments all went from fully unaccounted to
loading correctly. The run surfaced two regressions, both fixed:

- **Customers — deploy-tool base64 overflow (PR #379).** `DMT_BIP_DEPLOY_PKG` used
  `RAW(32767)` for the base64 envelope, which overflowed on data models ≥ ~24 KB and blocked
  the Customers reconcile. Fixed by chunking at 22,500 bytes. The Customers reconcile report now
  deploys and reconciles.
- **Projects — Txn Controls now reconciles from the real base table (PR #380).** Txn Controls
  is now marked LOADED from the real Fusion base table `PJC_TRANSACTION_CONTROLS`. Team Members
  is still UNACCOUNTED, but this is **not** an accepted end state: a queryable base table for
  project team members does exist and a fix is in progress (branch
  `fix/projects-teammembers-basetable`) to reconcile Team Members to LOADED from it. See the
  honest scorecard above and backlog #68.

### 5. Confirmatory regression run 327 (2026-09-21) — batch core proven, two items open

The confirmatory clean regression (run 327, prefix 10267) confirmed the batch **core** holds
end-to-end: the FBDI transactional readers reconcile with zero unaccounted, `dmt_run_assert` is
clean, and no new regression appeared. It did **not** close the two items above.

- **Zero GENERATED** left over — every record reached a terminal step.
- **`dmt_run_assert` clean** — the automated post-run accounting check passed for the core set.
- **Customers** reconcile report now deploys (PR #379) and the reconciler runs — but 28 records
  came back UNACCOUNTED after a successful import (STILL OPEN, backlog #70).
- **Projects** Txn Controls LOADED from `PJC_TRANSACTION_CONTROLS`; Team Members reconcile from the
  real base table is IN PROGRESS (branch `fix/projects-teammembers-basetable`, backlog #68).

**Run 327 totals: 173 records = 56 LOADED / 80 FAILED (real Fusion errors) / 37 UNACCOUNTED,
0 GENERATED.** The 37 UNACCOUNTED break down as the known environment-blocked residuals
(ARInvoices, GLBudgets, ProjectBudgets, Grants, TalentProfiles, Salaries-HDL) **plus** the two open
items: the 28 Customers records and the Projects Team Members tier. The environment-blocked
residuals are out of scope for this batch; the Customers and Team Members items are in scope and
open.

## Batch outcome — CORE COMPLETE, two follow-ups open

The Contract v1 conformance **core is complete**: every FBDI transactional reader is on the uniform
nine-column contract, the post-run reporting layer reads it, the APEX console (app 501) surfaces it,
and the confirmatory regression (run 327, prefix 10267) proved the core set holds end-to-end. Two
follow-ups remain open and are the next work: (1) root-cause the 28 UNACCOUNTED Customers records
(backlog #70), and (2) land the Projects Team Members base-table reconcile (backlog #68, branch
`fix/projects-teammembers-basetable`). This batch is **not** to be reported as "both regressions
closed."

## Related

- `docs/DMT_REBUILD_PLAN.html` section 0 — per-object Object Status Matrix (single source of
  truth for live status).
- `docs/status.md` — dated session log.
- Cross-session memory: `project_dmt2_reconciliation_uniform`.
