# Finding: multi-batch grouped objects lose later batches to a premature reconcile sweep

**Date:** 2026-07-20 (run 179 analysis)
**Severity:** real data loss for any object that loads in more than one batch
**Status:** root-caused in code; fix proposed, NOT yet implemented (needs a verification run + blind review because it touches a standard shared helper)

## Symptom

Items run 179: only 2 of 4 items reached the base table. `DMT-RT-PLAIN-001` loaded;
`DMT-RT-LOT-001` (lot-controlled) and `DMT-RT-SERIAL-001` (serial-controlled) ended
`[RECONCILE_ERROR] Item not confirmed in Fusion (not found in EGP_SYSTEM_ITEMS_B)`.
They looked like Fusion rejects. They are not — they were never loaded.

## What actually happened

The Items loader groups by `BATCH_ID` and loops one FBDI zip per batch
(`db/packages/dmt_loader_pkg.pkb.sql`, the `IF p_cemli_code = 'Items'` block ~line 2025).

- The lot/serial items were seeded into **batch 8102**; the plain/bad items into **batch 8101**.
- The loop processes 8101 first: generate → load → **reconcile**.
- Batch 8101's reconcile calls `DMT_EGP_ITEM_RESULTS_PKG.RECONCILE_BATCH`, which calls
  `SWEEP_UNACCOUNTED(p_run_id)`.
- `SWEEP_UNACCOUNTED` (dmt_egp_item_results_pkg.pkb.sql:337-359) marks **every** row of the
  run that is not already LOADED/FAILED:

  ```sql
  WHERE RUN_ID = p_run_id
  AND   TFM_STATUS NOT IN ('LOADED','FAILED')
  ```

  It has **no batch or load scoping**. So it swept batch 8102's still-**STAGED** rows and
  failed them with the "not found in base" message.
- When the loop then reached batch 8102, `GENERATE_FBDI(8102)` found "No STAGED rows"
  (they were already FAILED) and skipped it. Batch 8102 never loaded.

**Proof:** all four Items TFM rows share `LAST_UPDATED_DATE = 03:35:48` — the exact timestamp
of batch 8101's `PARSE_AND_UPDATE`. Batch 8102 was failed during batch 8101's reconcile,
before its own generation turn (~03:35:50, "No rows for item batch 8102. Skipping").

## Why single-batch objects are unaffected

For a single-batch object, by reconcile time every row is already GENERATED (none are STAGED),
so sweeping "everything not LOADED/FAILED" only catches GENERATED-but-unconfirmed rows — the
intended behavior. The bug only bites when a later batch still has STAGED rows during an
earlier batch's reconcile.

## CONFIRMED: also affects Requisitions (2026-07-20)

Requisitions groups by BATCH_ID (7001, 7002) and shows the same signature, made more visible by
its header/line/distribution hierarchy:

- Batch 7002's **lines** (`179_RQHDR_100000396/397/398`) and **distributions**
  (`179_RQDIST_100165773/774/775`) were all marked FAILED at **04:47:10** — the exact timestamp
  of **batch 7001's** `PARSE_AND_UPDATE`/reconcile. The run-scoped sweep in the requisition
  results package failed batch 7002's still-non-terminal children during batch 7001's reconcile.
- When batch 7002's generation turn came (also 04:47:10), the header generator found no valid
  children and logged "No rows for requisition batch 7002. Skipping."
- The now-orphaned batch 7002 **headers** — including the intended-good `RT-REQ-002` — were left
  STAGED and swept at the object-level reconcile at **04:57:53** with
  `[RECONCILE_ERROR] Requisition header not confirmed`.

So a good requisition (RT-REQ-002) was never given a load attempt. This is the same run-scoped
per-batch sweep, so the fix is systemic (every multi-batch grouped object), not Items-only. The
requisition reconciler's `SWEEP_UNACCOUNTED` is the same standard §7 helper.

## Proposed fix (needs owner review + a verification run)

The per-batch sweep must not fail rows that were never part of this batch's load. Two options:

1. **Exclude STAGED from the per-batch sweep** — change the scope to
   `TFM_STATUS NOT IN ('LOADED','FAILED','STAGED')` (i.e. only sweep GENERATED-but-unconfirmed
   rows), and rely on the final object-level accounting gate to fail any genuinely-orphaned
   STAGED rows after all batches run. Smallest change, but it edits the **standard §7
   `SWEEP_UNACCOUNTED` helper that is replicated byte-identically across ~33 reconciler
   packages**, so it is a standardized change under the blind-review protocol.
2. **Sweep once per object, not per batch** — for grouped objects, move the sweep out of the
   per-batch `RECONCILE_BATCH` and run it once after the batch loop completes. Scoped to the
   grouped-load orchestration, leaves the standard helper untouched, but changes control flow.

Either way this needs a fresh-scenario NEW-mode re-run to confirm (a) lot/serial items now
reach `EGP_SYSTEM_ITEMS_B` and (b) no single-batch object regresses.

## Not to be confused with

This is unrelated to whether Fusion accepts lot/serial items. We have not yet learned whether
Fusion *would* accept them, because they were never submitted. That question only becomes
testable after this fix.
