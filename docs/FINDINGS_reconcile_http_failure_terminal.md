# Finding: a single reconcile-phase HTTP failure (ORA-29273) terminally fails an already-loaded object

**Date:** 2026-07-20 (run 179 analysis)
**Severity:** an object whose data loaded to Fusion is reported FAILED because one HTTP call blipped
**Status:** root-caused; fix is a design decision (retry semantics) for the owner — NOT done

## Two objects, same signature in run 179

### MiscReceipts
- Load ESS 9766005 **SUCCEEDED**; explicit PollTMEssJob 9766035 **SUCCEEDED** (03:53–03:57).
- First BIP fetch in the load job (03:59:21) **succeeded** — reported "1 record FAILED in Fusion."
- The separate reconcile job's fetch (04:02:58) failed 20s later:
  `FETCH_BIP_RESULTS failed → RECONCILE_ONE failed → RECONCILE_BATCH failed`,
  all with `ORA-29273: HTTP request failed`.
- Net: the object is FAILED and shows **no records** in `DMT_RECORD_DETAIL_V`, even though the
  data loaded and the first fetch already had results.

### Expenditures
- Load child ended WARNING; the import-job lookup `GET_IMPORT_ESS_ID` failed with the same
  `ORA-29273: HTTP request failed` after 2 attempts, so reconciliation ran with a blank import
  id and could not confirm anything.

## Why this is wrong

The load already happened. A failed HTTP call to Fusion during the *verify* phase tells us
nothing about whether the rows loaded — it only means we could not check right now. Treating it
as a terminal object failure:
- violates the binding rule "no direct interface/base message ⇒ UNACCOUNTED, never invent one"
  (we invented a FAILED verdict from an HTTP error), and
- contradicts the already-decided pattern that a transient verify-phase failure is not terminal
  (see the "poll EXPIRED is not terminal FAILED; retry next tick" rule).

The first MiscReceipts fetch succeeded and the second failed 3 minutes later against the same
endpoint, report, and P_BATCH_ID — so this is an HTTP-layer failure, not a config/path/wallet
problem (those would fail consistently). What ORA-29273 wraps underneath (timeout vs. 5xx vs.
network reset) is not captured in the log; that detail should be surfaced so the failure mode is
known rather than guessed.

## Proposed fix (owner decision — retry semantics)

When a reconcile-phase Fusion call fails at the HTTP layer (ORA-29273) rather than returning a
BIP/SOAP application fault, the object should be left in its RECONCILING/AWAITING state and
retried on the next poller tick (bounded by a retry cap), not marked FAILED. A genuine SOAP/BIP
application fault (wrong report, bad SQL) must still raise immediately per the existing
"BIP SOAP faults raise immediately, never silently retry" rule — so the fix must distinguish an
HTTP-transport failure from an application fault. This touches the shared reconcile / queue-worker
path, so it needs the owner's agreement on the retry policy and a verification run.

## Separate observation (not the cause here): BIP registry points at /Custom/DMT/

`DMT_BIP_REPORT_TBL` points ~10 objects (Projects, Assets, Grants, MiscReceipts, Requisitions,
BillingEvents, PlanningBudgets, Expenditures, ProjectBudgets, COMMON_LOOKUPS) at `/Custom/DMT/`
(the frozen stack's catalog folder), not `/Custom/DMT2/` as CLAUDE.md specifies. This is NOT
what failed MiscReceipts — Projects/Assets/BillingEvents reconcile successfully against those
same `/Custom/DMT/` reports, so the frozen reports are live and working. It is a
consistency/ownership question (should DMT2 deploy and point at its own `/Custom/DMT2/` copies?)
to raise separately, not a run-179 failure cause.
