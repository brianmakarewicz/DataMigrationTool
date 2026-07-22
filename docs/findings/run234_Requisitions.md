# Run 234 Requisitions — Real Fusion Outcome Investigation (read-only)

**Date:** 2026-07-21
**Run:** 234, prefix 10115
**Object:** Requisitions
**Instance:** demo (fa-esew-dev28); queried live read-only via `scripts/fusion_bip_query.py --cred fin_impl`
**DMT DB:** dmt_owner @ //localhost:1523/FREEPDB1 (read-only)
**Scope:** No code changes, no pipeline run, no reconciliation rerun.

---

## Summary counts

| Record | DMT TFM status | REAL Fusion outcome |
|---|---|---|
| Req Header `10115RT-REQ-BADHDR` | UNACCOUNTED | **FAILED** — real header error in Fusion (`por_req_import_errors`, interface_id 19424) |
| Req Line `234_RQLN_100000443` (child of BADHDR) | UNACCOUNTED | **FAILED** by parent cascade — interface FLAG=FAILED, **no own error row** |
| Req Distribution `234_RQDIST_100165772` (child of BADHDR) | UNACCOUNTED | **FAILED** by parent cascade — interface FLAG=FAILED, **no own error row** |
| Req Header `10115RT-REQ-BADLINE` | UNACCOUNTED | **FAILED** — its child line has a real UOM error; the header itself has FLAG=FAILED with no header-level error row |
| Req Distribution `234_RQDIST_...` under BADDIST family / Header `10115RT-REQ-BADDIST` | UNACCOUNTED | **FAILED** — its child dist has a real Charge Account error; header FLAG=FAILED with no header-level error row |

**Owner's claim confirmed: none of the five is genuinely nowhere.** Every record is sitting in the Fusion interface tables with a real rejection process flag (ERROR or FAILED). None reached the base table (correctly — they are all bad-by-design). The DMT reconciler simply failed to *account* for them, leaving them UNACCOUNTED instead of FAILED. This is a reconciler-accounting gap, not missing data in Fusion.

**No GOOD row is at risk:** the two good headers `10115RT-REQ-001` (header_id 129006) and `10115RT-REQ-002` (header_id 129004) both reached `POR_REQUISITION_HEADERS_ALL` as APPROVED and are correctly LOADED in DMT.

---

## Per-record detail

Batch/partition mapping: BADHDR is in partition **7001** (queue_id 1446); BADLINE and BADDIST are in partition **7002** (queue_id 1447). Both partition queue rows are FAILED with "records unaccounted."

### 1. Req Header `10115RT-REQ-BADHDR` — key `234_RQHDR_100000395`
- **OUTCOME: FAILED (real Fusion header error).**
- Interface table `POR_REQ_HEADERS_INTERFACE_ALL`: `req_header_interface_id` = **19424**, `PROCESS_FLAG` = **ERROR**. Not in base table (verified absent).
- Real Fusion error source — `POR_REQ_IMPORT_ERRORS`, `interface_id = 19424`, INTERFACE_TYPE = HEADER (two rows):
  - `PREPARER_EMAIL_ADDR = NONEXISTENT_USER@fake.com` — "The preparer email isn't valid. It must be a valid email account associated with a worker with an active work relationship."
  - `APPROVER_EMAIL_ADDR = NONEXISTENT_USER@fake.com` — "The value of the attribute Approver isn't valid."
- **This matches the TFM ERROR_TEXT exactly** (the row already carries `[FUSION_ERROR] [HDR] PREPARER_EMAIL_ADDR=... | [HDR] APPROVER_EMAIL_ADDR=... | [UNACCOUNTED]`).
- **THE GAP (flagged):** this header has a real per-row Fusion error AND that error was already written into its TFM ERROR_TEXT, yet `TFM_STATUS` stayed **UNACCOUNTED** instead of flipping to **FAILED**. The error-detail pass matched it (wrote the message) but the header status-flip pass did not mark it FAILED. This is the "header-not-flipped-FAILED" bug.

### 2. Req Line `234_RQLN_100000443` (child of BADHDR)
- **OUTCOME: FAILED (parent-cascade rejection; no own Fusion error message).**
- Interface table `POR_REQ_LINES_INTERFACE_ALL`: `req_line_interface_id` = **16455**, `PROCESS_FLAG` = **FAILED**. Not in base table.
- `POR_REQ_IMPORT_ERRORS` for interface_id 16455: **zero rows.** Fusion rejected this line only because its parent header was invalid; it writes the diagnostic on the header, not the child. So there is no line-level message to surface — the correct classification is FAILED-because-parent-failed.

### 3. Req Distribution `234_RQDIST_100165772` (child of BADHDR line)
- **OUTCOME: FAILED (parent-cascade rejection; no own Fusion error message).**
- Interface table `POR_REQ_DISTS_INTERFACE_ALL`: `req_dist_interface_id` = **170808**, `PROCESS_FLAG` = **FAILED**. Not in base table.
- `POR_REQ_IMPORT_ERRORS` for interface_id 170808: **zero rows.** Same cascade situation as the line — rejected because the header failed, no distribution-level message written.

### 4. Req Header `10115RT-REQ-BADLINE` — key `234_RQHDR_100000397`
- **OUTCOME: FAILED (whole document rejected due to a real child-line error).**
- Interface header: `req_header_interface_id` = **19421**, `PROCESS_FLAG` = **FAILED**. Not in base table.
- The header has NO header-level error row in `POR_REQ_IMPORT_ERRORS`. The real error is on its child line (`234_RQLN_100000445`, interface_id **16453**, FLAG=ERROR): `UOM_CODE=ZZZ` — "The UOM isn't valid…". Because the line is invalid, Fusion rejects the entire requisition, so the header gets FLAG=FAILED with no header-specific message.
- In DMT the child line IS correctly marked FAILED (it has the UOM error), but the header stayed UNACCOUNTED — the reconciler didn't roll the child failure up to the header status.

### 5. Req Header `10115RT-REQ-BADDIST` — key `234_RQHDR_100000398`
- **OUTCOME: FAILED (whole document rejected due to a real child-distribution error).**
- Interface header: `req_header_interface_id` = **19422**, `PROCESS_FLAG` = **FAILED**. Not in base table.
- The header has NO header-level error row. The real error is on its child distribution (`234_RQDIST_100165775`, interface_id **170806**, FLAG=ERROR): `CODE_COMBINATION_ID` (Charge Account) — "The value of the attribute Charge Account isn't valid." The parent line `234_RQLN_100000446` (interface_id 170806-family, FLAG=FAILED) has no own error (it's fine; the dist is bad).
- In DMT the child dist IS correctly FAILED (Charge Account error), but the header stayed UNACCOUNTED — again, no child-to-header status roll-up.

---

## Root cause — where the reconciler drops these

The BIP reconciliation query (`bip/Requisitions/query.sql`) and the reconciler
(`db/packages/dmt_req_results_pkg.pkb.sql`) split work into two passes:

- **Header status pass (Step 1)** reads the UNION query. For each returned row it flips the
  header TFM_STATUS to LOADED (base-table hit) or FAILED (interface process_code in
  ERROR/REJECTED/FAILED/FAILURE), keyed on `INTERFACE_HEADER_KEY`.
- **Error-detail pass (Step 2)** reads `por_req_import_errors` and appends the message text to
  the matching header/line/dist row by interface key.
- **Cascade passes (Steps 3–4)** push FAILED down from a failed header to its children and push
  LOADED down from a loaded header to its children.

Three concrete gaps produce the four UNACCOUNTED rows:

1. **BADHDR header not flipped FAILED.** Its interface row is `PROCESS_FLAG = ERROR` and it has
   header error rows, so Step 1 *should* mark it FAILED and Step 2 *did* append its message —
   but its TFM_STATUS is still UNACCOUNTED. The status-flip for this header did not fire even
   though the error text was written. This is the primary "header-not-flipped-FAILED" bug: the
   error-detail pass and the status pass disagree for the same header.

2. **BADHDR's child line and dist have no own error rows.** Fusion writes the diagnostic only on
   the header for a header-level rejection. The child line (16455) and dist (170808) are
   `PROCESS_FLAG = FAILED` with zero rows in `por_req_import_errors`. The reconciler's
   error-detail pass finds nothing to attach, and because the header was never flipped FAILED
   (gap #1), the top-down FAILED cascade (Step 3/parent→child) never runs for this family. Both
   children fall through to UNACCOUNTED.

3. **BADLINE / BADDIST headers not rolled up from failed children.** The child line/dist carry
   the real error and ARE marked FAILED, but there is no bottom-up "if any child is FAILED, mark
   the header FAILED" step that also handles the header's own interface FLAG=FAILED with no
   header error row. Headers stay UNACCOUNTED.

### Join keys / where each error lives (for the fix)
- Header error: `por_req_import_errors.interface_id = por_req_headers_interface_all.req_header_interface_id`, `INTERFACE_TYPE='HEADER'` (+ `load_request_id` match). Present for BADHDR (19424).
- Line error: `...interface_id = por_req_lines_interface_all.req_line_interface_id`, `INTERFACE_TYPE='LINE'`. Present for BADLINE's line (16453).
- Dist error: `...interface_id = por_req_dists_interface_all.req_dist_interface_id`, `INTERFACE_TYPE='DISTRIBUTION'`. Present for BADDIST's dist (170806).
- Base-table confirmation: `por_requisition_headers_all.request_id = import ESS request id` (9774070 for run 234); good rows 129006 / 129004 present.
- **Header rejection with no header error row is normal Fusion behaviour** when the rejection is
  caused by a child line/dist. The reconciler must treat interface `PROCESS_FLAG` IN
  (ERROR, FAILED) as FAILED on its own, independent of whether a message row exists, and must
  cascade FAILED both down (header→children) and up (child→header).

## Fix roadmap (no change made here)
1. **Make interface PROCESS_FLAG authoritative for FAILED.** In Step 1, any header/line/dist
   interface row with `PROCESS_FLAG` IN (ERROR, REJECTED, FAILED, FAILURE) must set TFM_STATUS
   = FAILED even when no `por_req_import_errors` row exists. Confirm the BIP query actually
   returns the BADHDR header row for the batch (verify the `load_request_id = :P_BATCH_ID`
   filter is matching partition 7001's load request id) — the fact that BADHDR got its error
   text but not its FAILED status suggests the status pass and error pass are reading different
   row sets.
2. **Add a bottom-up cascade:** if any child line or dist is FAILED, mark its header FAILED and
   append a parent-context note (the code already has a top-down FAILED cascade in Step 3; the
   missing direction is child→header). This flips BADLINE and BADDIST headers.
3. **Account for message-less child rejections:** for children whose interface FLAG is FAILED but
   which have no error row (header-caused cascade, e.g. BADHDR's line 16455 / dist 170808), mark
   them FAILED with a "parent record rejected" note rather than leaving UNACCOUNTED.
4. After the fix, re-running reconciliation for run 234 (a separate, approved action) should turn
   all four UNACCOUNTED rows FAILED and let both partition queue rows report cleanly (3 loaded,
   the rest failed), with the object accounted.

---

## Evidence (all live, read-only)

Interface header state (exact run-234 keys, `por_req_headers_interface_all`):

| interface_header_key | req number | req_header_interface_id | PROCESS_FLAG |
|---|---|---|---|
| 234_RQHDR_100000394 | 10115RT-REQ-001 | 19425 | SUCCESS |
| 234_RQHDR_100000395 | 10115RT-REQ-BADHDR | 19424 | ERROR |
| 234_RQHDR_100000396 | 10115RT-REQ-002 | 19423 | SUCCESS |
| 234_RQHDR_100000397 | 10115RT-REQ-BADLINE | 19421 | FAILED |
| 234_RQHDR_100000398 | 10115RT-REQ-BADDIST | 19422 | FAILED |

Interface line / dist state (BADHDR children and the bad line/dist):

| key | interface_id | PROCESS_FLAG | own error row in por_req_import_errors |
|---|---|---|---|
| line 234_RQLN_100000443 (BADHDR child) | 16455 | FAILED | none |
| dist 234_RQDIST_100165772 (BADHDR child) | 170808 | FAILED | none |
| line 234_RQLN_100000445 (BADLINE child) | 16453 | ERROR | UOM_CODE=ZZZ: "The UOM isn't valid…" |
| dist 234_RQDIST_100165775 (BADDIST child) | 170806 | ERROR | CODE_COMBINATION_ID: "…Charge Account isn't valid." |

Base table `por_requisition_headers_all` (good rows only; bad rows verified absent):

| req number | requisition_header_id | document_status |
|---|---|---|
| 10115RT-REQ-001 | 129006 | APPROVED |
| 10115RT-REQ-002 | 129004 | APPROVED |
| 10115RT-REQ-BADHDR / BADLINE / BADDIST | — (not present) | — |

Requisitions ESS jobs for run 234 (all SUCCEEDED): load InterfaceLoader chain + two
`RequisitionImportJob` runs, import request_id 9774070.
