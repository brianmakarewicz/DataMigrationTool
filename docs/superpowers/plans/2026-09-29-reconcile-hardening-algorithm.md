# Reconcile-hardening algorithm (for planner review) — 2026-09-29

Four workstreams. **Hard constraint: every fix is UNIFORM (one shared mechanism driven by
registry/config), never per-object one-offs.** The shared hooks already exist:
- `DMT_REF_CARRIER_CFG_TBL` — per-object slot map (SLOT_A_FIELD, SLOT_A_BASE_COLUMN,
  SLOT_C_ATTRIBUTE, REF_FORMAT, CONFIDENCE, ACTIVE_FLAG).
- `DMT_REF_ID_PKG.BUILD_REF` — builds `DMT:<run>:<wq>:<tfm>`.
- Queue reconcile dispatch in `DMT_QUEUE_WORKER_PKG` (`RECON_PROC` per object, `dispatch_reconcile`,
  the post-reconcile "unaccounted sweep").
- A shared Contract-v1 base-table-proof LOADED path (the results-package LOADED gate).

Reviewer: confirm each of these is the real shared point, and that the plan below routes through
them rather than adding per-object code. Flag anywhere it would fragment.

## Track 1 — Re-run reconcile for a run (backlog #95)
- New `DMT_RECONCILE_PKG.RERUN_RUN(p_run_id)` (or a proc on the queue worker): for every object in
  the run that still has GENERATED rows, RE-DISPATCH only the reconcile step via the EXISTING
  `dispatch_reconcile` / per-object `RECON_PROC` path — do not call each object's package directly.
  One driver, registry-dispatched, so it works for all objects automatically.
- APEX button on Run Detail (page 82) "Re-run reconcile" → the proc for `:P82_RUN_ID`.
- Optional: exclude FAILED runs from the unaccounted baseline (view/query change), so an abandoned
  run stops counting as defects.
- Conformance check: it must use the same dispatch the live poller uses, not a parallel path.

## Track 2 — Fusion-id gate (backlog #11 capture + #82 enforce)
- Harden the ONE shared LOADED gate: a row cannot reach LOADED unless its registered `FUSION_*_ID`
  column is populated (and unique per-row for one-per-row objects). Needs a registry of each
  object's FUSION id column + grain (per-row vs composite). If one doesn't exist, add it as a
  column on the existing per-object registry (NOT scattered constants).
- Fix the reconcilers that reach LOADED without writing the id (Assets, Items, Expenditures,
  BillingEvents, ProjectBudgets, MiscReceipts lot/serial children, remaining HDL) by having each
  write its id AT ITS MATCH POINT through a shared helper — same helper for all.
- The gate then enforces it uniformly: any object that still doesn't write its id simply can't
  reach LOADED (stays GENERATED, surfaced by the sweep) — no silent false positives.
- Two objects can't produce a plain surrogate id (handle per backlog, still through the registry):
  GLBudgets → composite natural key `ledger~budget~period~ccid` (#87); Projects Team Members → no
  base table at all (#68, OWNER DECISION below).

## Track 3 — Carrier matching (backlog #12 stamp + #65 match)
- Generator side: stamp `BUILD_REF` into the object's configured Slot A / Slot B / Slot C from
  `DMT_REF_CARRIER_CFG_TBL`, uniformly (driven by the config, not hardcoded per generator).
- Reconcile side: match on the **three-tier fallback**, implemented ONCE in a shared match helper
  driven by the config: (1) Slot A reference; (2) if Slot A is null → Slot C attribute; (3) if the
  attribute is also null (segment not enabled / not carried) → the object's business key. Stamp
  `FUSION_ID` on the matched row (Track 2's gate then guarantees it's populated).
- CONFIG CORRECTNESS PASS (required, per the AP lesson): each object's slot must be VERIFIED to
  (a) exist in that object's FBDI/HDL load template and (b) round-trip to its base column, before
  ACTIVE_FLAG stays Y. Known-bad today: **APInvoices Slot A = REFERENCE_KEY1 is marked CONFIRMED
  but is NOT in the 164-column AP-lines FBDI template — it breaks the load.** AP must fall to its
  attribute or business key. Reviewer: propose how the verification is recorded (CONFIDENCE +
  a proven-on-run reference) so no future object trusts an unverified slot.

## Track 4 — Items Fusion-id grain (backlog #86)
- Store the composite `INVENTORY_ITEM_ID~ORGANIZATION_ID` (parent~child convention, same as
  GLBalances) so each item-per-org row has unique proof. This is Track 2's registry entry for
  Items (grain = composite), not a special case.

## Decisions to surface to the owner
1. **Projects Team Members (#68):** no queryable Fusion base table exists. Accept the import job's
   success list as proof of load, OR leave those records honestly unaccounted forever. NEEDS OWNER
   CALL — it's the one place Rule #1 (no LOADED without a base-table row) can't be met.
2. **Items grain (#86):** confirm `INVENTORY_ITEM_ID~ORGANIZATION_ID` is the intended grain
   (per-org), vs one id per item.
3. **GLBudgets (#87):** confirm storing the natural cell key instead of the VPD-blocked version id;
   needs a live check of which key parts are queryable.
4. **Gate enablement (#82):** turning the gate on will flip any current "LOADED-without-id" rows to
   not-LOADED (surfacing gaps). Confirm we enforce it now, with Track 1 (re-run reconcile) as the
   recovery path so it isn't disruptive.
5. **AP carrier:** REFERENCE_KEY1 is not loadable for AP lines; AP's carrier is deferred to its
   attribute (needs DFF enabled) or business-key match. Confirm that's acceptable.
