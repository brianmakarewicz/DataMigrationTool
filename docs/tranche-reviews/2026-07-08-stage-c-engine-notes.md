# Stage C — Catalog dispatch + mock CEMLI engine proof (2026-07-08)

Result: **queue engine proven end-to-end on Docker with no Fusion.** 6/6 unit suites green
(queue-engine 25/25), GLBalances golden still byte-identical, invalid baseline 47 → 46
(DMT_SCHEDULER_PKG now VALID — the second of the two known-invalid packages fixed).

## What changed
- Hardcoded dispatch retired: EXECUTE_ONE's 39-branch CASE, RECONCILE_ONE's ~24-branch
  ELSIF (including a LIKE 'Supplier%' standards violation), and the scheduler's two CASEs
  (pipeline sequence, dependency graph) all replaced by registry lookups over
  DMT_PIPELINE_DEF_TBL dispatch columns (EXEC_PROC, EXEC_MODE, RECON_PROC,
  RECON_HAS_CEMLI_ARG), seeded character-exact from the retired CASE arms.
- DMT_MOCK_PKG + MockObject/MockChild under a new TEST pipeline: full status walk,
  config-injected failures, dependency edge. Proves dispatch, halt/continue, one-active-run,
  crash-never-hangs.

## Real defects found and FIXED
1. **Infinite loop in SUBMIT_OBJECTS** (100% CPU, observed live): `EXIT WHEN l_pos = 0`
   never fires because INSTR on an exhausted string returns NULL. All 6 unsafe exits fixed
   with NVL. Almost certainly the historical "SUBMIT_PIPELINE hang" the old stack worked
   around with the inline create_run_and_queue shim.
2. **DMT_SCHEDULER_PKG body INVALID off-APEX** (PLAN_RUN used APEX_COLLECTION) — rewritten
   onto the committed DMT_PLAN_PREVIEW_GTT; valid everywhere.
3. **One-active-run-per-object was NOT implemented** (decided 2026-07-07) — implemented at
   submission (assert_objects_not_active). Note: judges active work items, not run rows.
4. **CONTINUE-policy promotion was NOT implemented** — PENDING dependents of a FAILED
   parent hung forever; promote_ready/dependencies_met now treat DONE|FAILED as terminal
   per section 2.

## OPEN STANDARDS QUESTION (user ruling needed — proposed in red in the canonical doc)
Registry-driven dispatch cannot name its target procedure statically. One narrow dynamic
invocation now exists: DMT_QUEUE_WORKER_PKG.invoke_registered — bind-only, named notation,
target validated against a strict PKG.PROC regex before execution, sole EXECUTE IMMEDIATE
in any DB object. Needs an explicit approved-exception ruling (the 2026-07-07 exception
covers deploy scripts only).

## Registry-vs-CASE mismatches (findings)
- CASE arms with no registry object: ItemCategories (bundled into Items), PlanBudgets
  (out of scope), PayrollRels (retired spelling; canonical PayrollRelationships seeded).
- Registry objects with no executor yet: ARReceipts + 7 CONFIGURATION objects — EXEC_PROC
  NULL, dispatch raises a clear not-registered error (config-runner fold is the tracked P2).
- Old scheduler dependency CASE disagreed with the decided seed in several places
  (PurchaseOrders deps, Requisitions ordering, MiscReceipts absent) — registry now
  authoritative.
- Items' conditional ItemCategories reconcile kept as a narrow commented special case;
  clean end state folds it into the Items results package.

## Remaining section-2 gaps (reported, not fixed)
- ESS_POLL_TIMEOUT_MINUTES config not wired: POLL_ONE uses hardcoded 30-poll C_ESS_TIMEOUT
  and fails from the timer without the decided reconcile-after-timeout behavior. Needs the
  Fusion-facing Stage C pass (blocked on live access anyway).
- CANCEL_RUN still exists though the design says REMOVED (tracked section-12 item).
- Assets' run-time book split remains an EXECUTE_ONE hardcode (data-dependent split,
  per-design).
