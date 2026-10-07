# Run 238: Requisitions and Purchase Orders UNACCOUNTED investigation (READ-ONLY)

Run 238 (scenario 222, prefix `93294`, full regression), local Docker DMT2, with run 236
(prefix `93292`) used for comparison. Requisitions ran as two partition children:
queue **1585** (BATCH_ID 7001, load ESS 10070894, RequisitionImportJob 10070899) and queue
**1584** (BATCH_ID 7002, load 10070901, import 10070907). PurchaseOrders ran as queue **1540**
(load 10070913, ImportSPOJob 10070920). BlanketPOs (queue 1541) and Contracts (queue 1542)
are both DONE with nothing unaccounted.

Everything here was read-only. Live Fusion was queried through
`scripts/fusion_bip_query.py --cred fin_impl`, and local DMT through `connect()` from
`scripts/dmt_regression_run.py` (SELECT only). No code or data was changed, and nothing was
re-run, reset or reconciled. The local working tree is at `2f14195`. `origin/main` is ahead
(#588 to #594), but none of those commits touches the Requisitions, PurchaseOrders, BlanketPOs
or Contracts DMs or results packages, so the analysis below also holds for current main.

## Per-row table: where each UNACCOUNTED row is, why we miss it, and the fix

None of the nine UNACCOUNTED rows in run 238 is missing from Fusion. Every one is sitting in
its Fusion interface table with a terminal reject status (`PROCESS_FLAG=FAILED` for
requisitions, `PROCESS_CODE=REJECTED` for purchase orders). None has an error row of its own,
because Fusion rejected each of them only because another record in the **same document** had
a real error, and that real error is recorded in Fusion. Run 236 shows exactly the same nine
rows with the same statuses (keys `236_*`, prefix `93292`).

All import ESS jobs for these objects in run 238 **SUCCEEDED** (state 12 in `DMT_ESS_JOB_TBL`),
so there is no job-level failure.

| # | DMT row (run 238) | (a) Where it is in Fusion right now | (b) Why our reconciler misses it | (c) Fix |
|---|---|---|---|---|
| 1 | Req **Header** `93294RT-REQ-BADLINE` (TFM 100000325, queue 1584) | `POR_REQ_HEADERS_INTERFACE_ALL` req_header_interface_id **31429**, key `238_RQHDR_100000148`, **PROCESS_FLAG=FAILED**, load 10070901 / request 10070907. It has no HEADER row in `POR_REQ_IMPORT_ERRORS` and is not in `POR_REQUISITION_HEADERS_ALL`. The real error is on its child line `238_RQLN_100000196` (iface 30429, `ERROR`): error 164669 `UOM_CODE=ZZZ: The UOM isn't valid…`. Requisition Import rejects the whole requisition. | The DM header INTERFACE tier **does** return the row (`DMT_REQ_RECON_DM.xdm:165-194`, record_key = REQUISITION_NUMBER, which matches the TFM RECON_KEY). Its ERROR_MESSAGE is `CASE WHEN he.error_message IS NOT NULL …` (`:171-172`), and `he` only joins HEADER-type errors on the row's own key (`:178-192`), so the message is NULL. `dmt_req_results_pkg.pkb.sql:189-190` marks FAILED only when ERROR_MESSAGE IS NOT NULL, so the row stays GENERATED and `SWEEP_UNACCOUNTED` (`dmt_queue_worker_pkg.pkb.sql:321-357`) stamps it UNACCOUNTED. | **Code (DM V2):** for an interface row with a reject flag and no error of its own, emit a document-scoped message built from the real errors of the same requisition, e.g. `Not created: Requisition Import set this header to FAILED with no error of its own. Requisition 93294RT-REQ-BADLINE was rejected for: [LINE 238_RQLN_100000196] UOM_CODE=ZZZ: The UOM isn't valid…`. Result: FAILED. |
| 2 | Req **Header** `93294RT-REQ-BADDIST` (100000329, queue 1584) | Iface **31431**, `238_RQHDR_100000149`, **FAILED**, no header error, not in base. The real error is on its distribution `238_RQDIST_100165526` (iface 186806, `ERROR`): error 164670 `CODE_COMBINATION_ID: The value of the attribute Charge Account isn't valid.` | Same as row 1 (`DM:171-172`, `pkb:189-190`, then swept). | Same DM fix. The message quotes the `[DIST]` Charge Account error. |
| 3 | Req **Line** `238_RQLN_100000194` (100000375, queue 1585), child of BADHDR | `POR_REQ_LINES_INTERFACE_ALL` iface **30427**, **FAILED**, load 10070894, with zero `POR_REQ_IMPORT_ERRORS` rows. Its header `238_RQHDR_100000146` (iface 31428, `ERROR`) has errors 164667/164668: `PREPARER_EMAIL_ADDR=NONEXISTENT_USER@fake.com: The preparer email isn't valid…` and `APPROVER_EMAIL_ADDR=…: The value of the attribute Approver isn't valid.` Not in `POR_REQUISITION_LINES_ALL`. | The line INTERFACE tier returns it (`DM:199-224`, key matches TFM RECON_KEY), but the message is NULL because there is no LINE error on its own key (`:205-206`). It is skipped at `pkb:265-266` and then swept. | Same DM fix. The message quotes the `[HDR]` preparer and approver errors. |
| 4 | Req **Line** `238_RQLN_100000197` (100000377, queue 1584), the line under BADDIST | Iface **30430**, **FAILED**, no own error, not in base. It was rejected because its own distribution 186806 has the Charge Account error. | Same as row 3 (`DM:205-206`, `pkb:265-266`). | Same DM fix. The message quotes the `[DIST]` error, so this is a child-to-parent roll-up within the document. |
| 5 | Req **Dist** `238_RQLN_100000194:DIST:1` (iface key `238_RQDIST_100165523`, TFM 100111984, queue 1585), under BADHDR | `POR_REQ_DISTS_INTERFACE_ALL` iface **186803**, **FAILED**, no own error, not in `POR_REQ_DISTRIBUTIONS_ALL`. Header BADHDR carries the real errors. | The dist INTERFACE tier returns it (`DM:233-258`), but the message is NULL (`:239-240`). It is skipped at `pkb:341-342` and then swept. | Same DM fix, quoting the `[HDR]` errors. |
| 6 | Req **Dist** `238_RQLN_100000196:DIST:1` (`238_RQDIST_100165525`, 100111987, queue 1584), under BADLINE | Iface **186807**, **FAILED**, no own error, not in base. Its parent line 30429 carries the real UOM error. | Same as row 5. | Same DM fix, quoting the `[LINE]` UOM error. |
| 7 | PO **Line** `93294RT-PO-BAD1:LN:1` (TFM 100000374, iface key `238_LN_100000974`, queue 1540) | `PO_LINES_INTERFACE` interface_line_id **999016**, **PROCESS_CODE=REJECTED**, load 10070913, with zero `PO_INTERFACE_ERRORS` rows. Its header `238_HDR_100000213` (iface 831811, REJECTED) has errors 532310 `VENDOR_NUM: The supplier isn't valid…` and 532311 `VENDOR_SITE_CODE: The supplier site isn't valid…` (request 10070920). `93294RT-PO-BAD1` is not in `PO_HEADERS_ALL`, so there is no base line. | The line INTERFACE tier returns it (`DMT_PO_RECON_DM.xdm:237-265`). FETCH_ROWS returned 12 rows (8 BASE + 4 INTERFACE). ERROR_MESSAGE is NULL because `le` only holds line-level errors on its own `interface_line_id` (`:243-244`, `:252-262`). `dmt_po_results_pkg.pkb.sql:253-255` requires a non-null message, so the row is swept. | **Code (DM V2):** for a REJECTED row with no error of its own, emit `Not created: Import Orders set this line to REJECTED with no error of its own. Purchase order 93294RT-PO-BAD1 was rejected for: [HDR] VENDOR_NUM: The supplier isn't valid… \| VENDOR_SITE_CODE: …`, built from `PO_INTERFACE_ERRORS` for the document's `interface_header_id`. Result: FAILED. |
| 8 | PO **Line Location** `93294RT-PO-BAD1:LN:1:LOC:1` (100000276, `238_LOC_100000113`) | `PO_LINE_LOCATIONS_INTERFACE` **701496**, **REJECTED**, no own error, not in base. | Same as row 7 (`DM:277-305`, message `:284-285`, `pkb:330-332`). | Same DM fix. |
| 9 | PO **Distribution** `93294RT-PO-BAD1:LN:1:LOC:1:DIST:1` (100000276, `238_DIST_100000171`) | `PO_DISTRIBUTIONS_INTERFACE` **1006734**, **REJECTED**, no own error, not in base. | Same as row 7 (`DM:317-346`, message `:325-326`, `pkb:407-409`). | Same DM fix. |

**BlanketPOs / Contracts:** there are no UNACCOUNTED rows. `93294RT-BPA-BAD1` and
`93294RT-CPA-BAD1` are REJECTED headers with their own `PO_INTERFACE_ERRORS` rows (533292-533295),
so they are correctly FAILED. BPA-BAD1 has no line and Contracts are header-only, so neither
object has a message-less child today. The BlanketPOs line tier has the same NULL-message
shape, though (`DMT_BLANKET_PO_RECON_DM.xdm:146`), so it is a **latent** instance of this bug:
a BAD blanket with a line would produce an UNACCOUNTED line.

## Summary counts (run 238; run 236 is identical)

| Object / record type | LOADED | FAILED (real own error) | UNACCOUNTED | Genuinely absent from Fusion |
|---|---|---|---|---|
| Requisitions / headers | 2 | 1 (BADHDR) | 2 (BADLINE, BADDIST) | 0 |
| Requisitions / lines | 2 | 1 (BADLINE UOM) | 2 | 0 |
| Requisitions / distributions | 2 | 1 (BADDIST charge account) | 2 | 0 |
| PurchaseOrders / headers | 2 | 1 (BAD1 supplier) | 0 | 0 |
| PurchaseOrders / lines, locations, distributions | 2 + 2 + 2 | 0 | 1 + 1 + 1 | 0 |
| BlanketPOs, Contracts | 1 hdr + 1 line, 1 hdr | 1, 1 | 0 | 0 |

## Root cause (one defect, a code regression)

### R1. PR #574 removed the per-row verdict for reject-cascaded rows, and nothing replaced it (code-fix)

Requisition Import and Import Orders are **all-or-nothing per document**. When any header,
line or distribution of a requisition or PO has an error, Fusion sets every interface row of
that document to `FAILED`/`REJECTED`, but writes an error row only for the record that actually
failed. That gives two kinds of message-less row:

- **Downward cascade:** the header failed, so its lines and distributions are rejected
  (Req rows 3 and 5, PO rows 7 to 9).
- **Upward or sideways cascade:** a line or distribution failed, so its header and sibling
  records are rejected (Req rows 1, 2, 4 and 6).

The data models **do** return every one of these rows. This is not the Items request-id
problem: FETCH_ROWS logged 6 rows for queue 1585, 15 for queue 1584 and 12 for queue 1540,
which is exactly the BASE rows plus every non-SUCCESS or non-ACCEPTED interface row. The data
models just give each such row a NULL ERROR_MESSAGE, because each tier joins only errors whose
key equals the row's own key, and the results packages discard a NULL-message ERROR row.

**This is a regression with a precise date.** The Contract-v1 DMs (#335/#340, 2026-09-20) used
`'[LINE] ' || NVL(le.error_message, 'Rejected by Requisition Import (process_flag=…; line not
created in base table).')` (and `'Rejected by Import Orders (process_code=…)'` for POs), so these
rows landed FAILED. Commit `88a7301` (#574, 2026-10-05 14:19, "Stop fabricating FAILED
verdicts") replaced that with `CASE WHEN own_error IS NOT NULL THEN … END`. The local history
shows the flip exactly:

| Run | Started | Requisitions | PurchaseOrders |
|---|---|---|---|
| 225 | 2026-10-03 | 6 LOADED, 9 FAILED, **0 UNACCOUNTED** | 9 LOADED, 4 FAILED, **0** |
| 227 | 2026-10-05 15:28 | 6 / 9 / **0** | 9 / 4 / **0** |
| 229 | 2026-10-05 18:46 (after #574) | 6 / 3 / **6** | 9 / 1 / **3** |
| 236, 238 | 2026-10-06 | 6 / 3 / **6** | 9 / 1 / **3** |

#574 was right that "Rejected … (process_flag=FAILED)" is a composed sentence with no real Fusion
reason in it. It was wrong to leave nothing in its place. A `FAILED`/`REJECTED` flag is a
terminal, committal Fusion verdict (unlike the Customers `W` hold or a pending `P`), and the real
reason for it **is** in Fusion, on the sibling record in the same document. The owner-sanctioned
pattern since then (#589 Customers V3 "Parent records not created: … rejected (status E): <real
text>", #592 `[PARENT_FAILED]` naming the parent and quoting its Fusion error) is exactly what
these two DMs need. It also matches the standing error-attribution rule: own errors go on the
row that failed, and records rejected with that row carry a cascade naming the real error.

**Fix (code, two new DM versions, no results-package change):**

1. `DMT_REQ_RECON_V2_DM.xdm` (deployed alongside, never overwriting; repoint
   `DMT_BIP_REPORT_TBL` 100000009; mirror in `bip/Requisitions/query.sql`). On each of the three
   INTERFACE tiers keep the own-error message first. When it is NULL and `PROCESS_FLAG IN
   ('FAILED','ERROR')`, emit `Not created: Requisition Import set this <tier> to <flag> with no
   error of its own. Requisition <REQUISITION_NUMBER> was rejected for: <list>`. Build `<list>`
   from `POR_REQ_IMPORT_ERRORS` for every interface row of the same document: the header key, the
   lines whose `INTERFACE_HEADER_KEY` matches, and the dists whose `INTERFACE_LINE_KEY` belongs to
   those lines. Prefix each item with `[HDR]`/`[LINE <key>]`/`[DIST <key>]`. If the document has no
   error anywhere, use the Customers-V3 case-3 wording (`… recorded no error for it or any record
   of requisition X`).
2. `DMT_PO_RECON_V2_DM.xdm` (repoint `DMT_BIP_REPORT_TBL` 100000003; mirror in `query.sql`). Same
   shape on all four INTERFACE tiers, gated on `PROCESS_CODE='REJECTED'`, with `<list>` taken
   from `PO_INTERFACE_ERRORS WHERE interface_header_id = <document's interface_header_id>`
   (every tier's errors for that document carry the header id) and, for safety, `request_id =
   :P_IMPORT_ESS_ID`.
3. Apply the same change to the BlanketPOs line tier (`DMT_BLANKET_PO_RECON_DM.xdm:146`) to close
   the latent case. Contracts is header-only and needs no change.

The results packages already mark FAILED on any non-null real message (`dmt_req_results_pkg.pkb.sql:189/265/341`,
`dmt_po_results_pkg.pkb.sql:176/253/330/407`), so once the V2 DMs are deployed all nine rows land
FAILED with a message quoting the real Fusion error. The run-238 rows would come out as follows:
BADLINE header, BADDIST header and BADDIST line FAILED quoting the real `[LINE]`/`[DIST]` error;
the BADHDR line and dist FAILED quoting the `[HDR]` preparer/approver errors; the BADLINE dist
FAILED quoting the `[LINE]` UOM error; and the PO-BAD1 line, location and distribution FAILED
quoting `[HDR] VENDOR_NUM`/`VENDOR_SITE_CODE`.

**No seed fix and no environment block.** Every BAD row is bad by design and is correctly
rejected by Fusion with a real message. Every GOOD row (REQ-001/002, PO-001/002, BPA-001,
CPA-001) is in its base table and LOADED. The children of a BAD document will always be
message-less cascades, so the seed cannot (and should not) avoid this case. The reconciler has
to handle it.

## The prior investigation (`run234_Requisitions.md`) and whether its fix landed

Run 234 (2026-07-21, the pre-Contract-v1 reconciler) found five Requisitions rows UNACCOUNTED,
none genuinely absent, and named three gaps:

1. **BADHDR header not flipped to FAILED** even though its error text was written. **Fixed,
   and it stays fixed.** The Contract-v1 rewrite (#335/#364, 2026-09-20) keys the header INTERFACE
   tier on `REQUISITION_NUMBER`, which equals the TFM RECON_KEY, so BADHDR is FAILED with its
   real `[HDR]` text in runs 225 to 238.
2. **Message-less child rows of a failed header** (BADHDR's line and dist). **Landed, then
   reverted.** Contract-v1's composed `Rejected by Requisition Import (process_flag=…)` fallback
   made them FAILED (runs 225 and 227 had 0 UNACCOUNTED). #574 removed the fallback on 2026-10-05,
   and they have been UNACCOUNTED since run 229 (rows 3 and 5 above).
3. **No bottom-up roll-up** (the BADLINE and BADDIST headers). **Landed, then reverted**, by the
   same mechanism. The composed fallback covered any non-SUCCESS interface row, and #574 took it
   away (rows 1, 2, 4 and 6 above).

That document's recommended fix was "make PROCESS_FLAG authoritative for FAILED with a
parent-rejected note". #574 has since established that a composed note on its own is not
acceptable. The R1 fix above satisfies both positions: the verdict comes from Fusion's terminal
flag, and the message text is Fusion's own error from the record that caused the rejection.

## Is this the Customers/Items pattern?

Partly. It is the same family as **Customers R1**: Fusion left the row in the interface with a
real non-success status but no error row of its own, the DM emitted a NULL message for it, and
the results package discarded it into the sweep. The fix has the same shape, a cascade message
built only from real Fusion rows in the same load/document. It is **not** the Items R2 pattern
(the wrong request id meant the DM never returned the rows): here every row is returned. The
difference from Customers is the cause. Customers had a batch-wide LISTAGG from the start,
whereas Reqs/POs worked until #574 deliberately removed the fallback without adding a
real-error cascade.

## Other observations (logged, not fixed)

- #574 changed `DMT_REQ_RECON_DM.xdm` and `DMT_PO_RECON_DM.xdm` **in place** at the same
  `/Custom/DMT2/...` catalog paths that `DMT_BIP_REPORT_TBL` 100000009/100000003 still point to.
  That breaks the never-overwrite-BIP-objects rule (deploy V2 alongside). The deployed copies are
  evidently the post-#574 SQL: the BADHDR header got its real `[HDR]` text while every
  message-less row came back NULL, which the pre-#574 SQL cannot produce.
- `dmt_record_detail_v` shows the blanket line `93294RT-BPA-001:LN:1` (shared
  `DMT_PO_LINES_INT_TFM_TBL`, WORK_QUEUE_ID NULL) under **PurchaseOrders / PO Lines**. The
  PurchaseOrders accounting gate does not count it (8 loaded + 1 errored + 3 unaccounted = 12), so
  only the detail view is affected. This is a cosmetic attribution issue in the view.
- The Requisitions parent splitter queue rows (1486, 1539) read DONE while both partition children
  (1584, 1585 / 1525, 1526) are FAILED for unaccounted rows. This was not investigated further. It
  may be intended splitter semantics, but it is worth confirming that the run-level roll-up does
  not read the parent's DONE.
- The Req DM error joins (`DM:178-192`, `:212-222`, `:246-256`) are keyed only by
  `interface_key`, without `request_id`. That is safe today because keys are run-scoped
  (`<run_id>_RQ…`). It would be unsafe if a run id were ever reused against the same pod (for
  example the frozen stack or a rebuilt local DB restarting its run sequence). Adding
  `e.request_id IN (import ids)` or an `e.creation_date` window in V2 would make the joins robust.

## Evidence appendix (all read-only)

- Local `dmt_work_queue_tbl` run 238: 1584 Req 7002 load 10070901 / import 10070907 "4 unaccounted (3 loaded, 2 errored)"; 1585 Req 7001 load 10070894 / import 10070899 "2 unaccounted (3 loaded, 1 errored)"; 1540 PO load 10070913 / import 10070920 "3 unaccounted (8 loaded, 1 errored)"; 1541 BlanketPOs DONE; 1542 Contracts DONE. Run 236: 1525/1526/1487 have the same messages.
- Local `dmt_ess_job_tbl` run 238: InterfaceLoaderController/SqlldrImport and RequisitionImportJob 10070899 and 10070907, ImportSPOJob 10070920, ImportBPAJob 10070877, ImportCPAJob 10070886, all state 12 SUCCEEDED.
- Local `dmt_log_tbl` run 238: `FETCH_ROWS … Requisitions … LoadReqId: 10070894 … rows 6` → `headers 1/1, lines 1/0, dists 1/0`; `LoadReqId: 10070901 … rows 15` → `headers 1/0, lines 1/1, dists 1/1`; `PurchaseOrders … LoadReqId: 10070913 … rows 12` → `headers 2/1, lines 2/0, locs 2/0, dists 2/0`.
- Local TFM RECON_KEYs (run 238) equal the DM record keys: headers `93294RT-REQ-*`; lines `238_RQLN_1000001{93..97}`; dists `238_RQLN_…:DIST:1`; PO `93294RT-PO-BAD1:LN:1[:LOC:1[:DIST:1]]`.
- Fusion `POR_REQ_HEADERS_INTERFACE_ALL` run 238: 31427 REQ-001 SUCCESS; 31428 BADHDR ERROR; 31430 REQ-002 SUCCESS; 31429 BADLINE FAILED; 31431 BADDIST FAILED.
- Fusion `POR_REQ_LINES_INTERFACE_ALL` run 238: 30426 (193) SUCCESS; 30427 (194) FAILED; 30428 (195) SUCCESS; 30429 (196) ERROR; 30430 (197) FAILED.
- Fusion `POR_REQ_DISTS_INTERFACE_ALL` run 238: 186804 (522) SUCCESS; 186803 (523) FAILED; 186805 (524) SUCCESS; 186807 (525) FAILED; 186806 (526) ERROR.
- Fusion `POR_REQ_IMPORT_ERRORS` for `238_RQ%`: 164667/164668 HEADER `238_RQHDR_100000146` (preparer, approver); 164669 LINE `238_RQLN_100000196` (UOM_CODE=ZZZ); 164670 DISTRIBUTION `238_RQDIST_100165526` (CODE_COMBINATION_ID). There are no other rows.
- Fusion base: `POR_REQUISITION_HEADERS_ALL` 93294RT-REQ-001 (142991) and -002 (142993) APPROVED only; `POR_REQUISITION_LINES_ALL` 238_RQLN_193 (150256) and _195 (150260) only. `PO_HEADERS_ALL` 93294RT-PO-001 (686881), PO-002 (686882), BPA-001 (687869) and CPA-001 (687870) only.
- Fusion `PO_*_INTERFACE` run 238: header 831811 PO-BAD1 REJECTED; line 999016, location 701496 and distribution 1006734 REJECTED; all other PO rows ACCEPTED. `PO_INTERFACE_ERRORS`: 532310/532311 (header 831811 only); 533292-533295 (BPA-BAD1 832805, CPA-BAD1 832807 headers). Nothing for 999016, 701496 or 1006734.
- Run 236 (Fusion): req lines 174/177 and dists 503/505 FAILED with 0 errors; line 176 and dist 506 ERROR with 1 error each. PO line 958, location 101 and distribution 159 REJECTED with 0 errors. This is the same pattern.
- Local history: Req/PO UNACCOUNTED counts are 0/0 in runs 225 and 227, and 6/3 in runs 229, 236 and 238. Runs 225/227 line ERROR_TEXT read `[FUSION_ERROR] [LINE] Rejected by Requisition Import (process_flag=FAILED; …)` and `… Rejected by Import Orders (process_code=REJECTED; …)`.
