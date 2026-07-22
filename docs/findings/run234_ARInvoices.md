# Run 234 — ARInvoices — Fusion Outcome Investigation (READ-ONLY)

Prefix 10115. Regression run 234, pipeline O2C. All reads are read-only:
`scripts/fusion_bip_query.py` (fin_impl BIP) against live Fusion, the local DMT database
(`dmt_owner @ //localhost:1523/FREEPDB1`), and the AutoInvoice ESS logs fetched via
`DMT_ESS_UTIL_PKG.GET_ESS_OUTPUT_TEXT` (fin_impl SOAP, same endpoint DMT uses). No code,
pipeline, or reconciliation was changed.

> **Correction to the first version of this document.** The first pass concluded the 3 rows
> were "stuck in interface, no verdict" because the work-queue row for ARInvoices has NULL
> ESS job ids. That was wrong. The NULL job ids are misleading — DMT *did* record the real
> ESS jobs in `DMT_ESS_JOB_TBL`, and AutoInvoice *did* run, twice, and **errored both times**.
> The real Fusion error is in those ERRORED jobs' logs and is quoted below. The correct
> verdict for all 3 records is **FAILED with a real, job-level Fusion error**, not unaccounted.

## Summary counts

| Outcome | Count | Records |
|---|---|---|
| LOADED (base table) | 0 | — |
| **FAILED — real AutoInvoice job-level error** | **3** | RT-AR-G1, RT-AR-G2, RT-AR-BAD1 |
| GENUINELY ABSENT (nowhere in Fusion) | 0 | — |

**The owner is right — none are genuinely nowhere, and there IS a real Fusion error.**
AutoInvoice ran and aborted at the job level (before it ever evaluated individual lines),
so the rows remain physically in `RA_INTERFACE_LINES_ALL` and no per-line interface-error
row was written — but the ESS job log carries the actual, quotable Fusion rejection reason.
There are **two different** errors, one per batch source.

## What actually happened — the ESS job chain (from DMT_ESS_JOB_TBL, run 234)

The AutoInvoice load ran twice (an initial attempt and a retry). Both attempts loaded the
interface table successfully and then failed at the AutoInvoice import step:

| request_id | job | state | ended | batch source |
|---|---|---|---|---|
| 9773724 | InterfaceLoaderController | 12 SUCCEEDED | 21:44:03 | (loads interface) |
| 9773725 | InterfaceLoaderAsyncJob | 12 SUCCEEDED | 21:43:53 | |
| 9773726 | InterfaceLoaderSqlldrImport | 12 SUCCEEDED | 21:44:00 | |
| **9773727** | **AutoInvoiceImportEss** | **10 ERROR** | 21:44:24 | External Source (G1, G2) |
| 9773800 | InterfaceLoaderController | 12 SUCCEEDED | 21:49:17 | (retry, loads interface) |
| 9773801 | InterfaceLoaderAsyncJob | 12 SUCCEEDED | 21:49:07 | |
| 9773802 | InterfaceLoaderSqlldrImport | 12 SUCCEEDED | 21:49:14 | |
| **9773803** | **AutoInvoiceImportEss** | **10 ERROR** | 21:49:37 | Manual-Other (BAD1) |

Neither errored AutoInvoice request spawned a child request. Confirmed by querying live
Fusion `ess_request_history` for `parentrequestid IN (9773727, 9773803)` — zero rows. So
there is no separate AutoInvoice Execution Report to read; both jobs aborted before line
selection, and the job log itself is the source of the error.

## THE REAL FUSION ERRORS (quoted from the ESS job logs)

### Error A — External Source batch (records RT-AR-G1, RT-AR-G2)
Source: AutoInvoiceImportEss **request 9773727** ESS log.

> **The invoices couldn't be imported because consolidated billing is enabled. Run the
> Import Receivables Transactions Using AutoInvoice process instead.**

Context from the same log: the batch source "External Source" has
`Consolidation Billing Enabled Y`; AutoInvoice logs `raamai_main()+ gib.cons_bat_src IS FALSE`
then `Run AI from Master!!!` and aborts. This is the exact known consolidated-billing abort
noted in `objects/ARInvoices/README.md`: the direct `AutoInvoiceImportEss` (RAXTRX) job will
not import a consolidated-billing batch source; it must be submitted through
`AutoInvoiceMasterEss` (RAXMTR) — "Import Receivables Transactions Using AutoInvoice."

### Error B — Manual-Other batch (record RT-AR-BAD1)
Source: AutoInvoiceImportEss **request 9773803** ESS log.

> **The transaction source isn't valid for the business unit based on reference set
> association.**

Context from the same log: batch source "Manual-Other", Org Id 300000046987012
(US1 Business Unit). AutoInvoice fails inside `raagbo()` with
`Error calling raagbo().` → `Error calling raaini().` The batch source "Manual-Other" is not
associated with the reference set tied to that business unit, so AutoInvoice rejects the whole
run before touching any line. This is a real setup/data error, correctly attributable to the
BAD1 record's batch source choice.

Note: the earlier "stale 2025-06-15 date" hypothesis was **wrong**. Both ESS logs show
`Default Date ::: 2026-07-21` — DMT passed today's date as the AutoInvoice default date. The
2025-06-15 value on the interface row is only the transaction/GL date carried on the data; it
was not the cause. The cause is the two job-level errors above.

## Per-record outcome

Fusion key = `INTERFACE_LINE_CONTEXT='LEGACY'` + `INTERFACE_LINE_ATTRIBUTE1` shown. All three
sit in `RA_INTERFACE_LINES_ALL` (interface_status NULL, request_id NULL) because their
AutoInvoice run aborted at the job level.

- **10115RT-AR-G1** (Fusion key RT-AR-G1, batch External Source) | OUTCOME: **FAILED**.
  Real error: "The invoices couldn't be imported because consolidated billing is enabled.
  Run the Import Receivables Transactions Using AutoInvoice process instead." Source:
  AutoInvoiceImportEss request 9773727 ESS log. interface_line_id 100002550114512.

- **10115RT-AR-G2** (Fusion key RT-AR-G2, batch External Source) | OUTCOME: **FAILED**.
  Same error and source as G1 (same batch, same aborted request 9773727).
  interface_line_id 100002550114513.

- **10115RT-AR-BAD1** (Fusion key RT-AR-BAD1, batch Manual-Other) | OUTCOME: **FAILED**.
  Real error: "The transaction source isn't valid for the business unit based on reference
  set association." Source: AutoInvoiceImportEss request 9773803 ESS log.
  interface_line_id 100002550114574.

## The reconciliation-key gotcha (still relevant for matching)

DMT's run keys are `10115RT-AR-BAD1 / -G1 / -G2` (the `TRX_NUMBER` on the TFM row), but the
value written to the Fusion reconciliation column `RA_INTERFACE_LINES_ALL.INTERFACE_LINE_ATTRIBUTE1`
is the key **without the numeric prefix** (`RT-AR-BAD1 / RT-AR-G1 / RT-AR-G2`), with
`INTERFACE_LINE_CONTEXT = 'LEGACY'`. That value is not run-unique (every prior AR run reused
it), so a base/interface lookup by key alone cannot isolate this run's rows — disambiguate by
`creation_date` within the run window, or (better) write a run-unique value. `RECON_KEY` on the
TFM row is currently NULL for all three.

## Fix roadmap — where the reconciler must read each outcome

The core reconciler defect for AR: it only looks at base tables and the interface-error table,
and when both are empty it declares "unaccounted." It never inspects the **AutoInvoice ESS job
state**. Because both AutoInvoice jobs aborted at the job level, they wrote **no** interface-error
row — so the real error is invisible to a base/interface-only reconciler. Fix:

1. **Detect the AutoInvoiceImportEss ERROR for the run.** For ARInvoices, read
   `DMT_ESS_JOB_TBL` for `run_id` + `cemli_code='ARInvoices'` + `job_short_name='AutoInvoiceImportEss'`.
   Any row in `state = 10` (ERROR) means the import failed. Do NOT trust the work-queue row's
   `IMPORT_ESS_JOB_ID` (it was NULL here even though the jobs exist).

2. **Read that job's ESS log and extract the message.** Call
   `DMT_ESS_UTIL_PKG.GET_ESS_OUTPUT_TEXT(<request_id>)` (or DOWNLOAD_ESS_FILE) for the errored
   AutoInvoiceImportEss request(s). The human-readable failure line is near the end of the log,
   after the `raamai_main`/`raagbo` trace. Capture it as the ERROR_TEXT.

3. **Attribute the job-level error to the right rows.** AutoInvoice runs per batch source, and
   the error is per batch source. Map each errored AutoInvoiceImportEss request to its batch
   source (in the log's `Batch Source Name` argument), then attribute that error to every TFM
   row whose `BATCH_SOURCE_NAME` matches. Here: request 9773727 → "External Source" → G1, G2;
   request 9773803 → "Manual-Other" → BAD1. Mark those rows **FAILED** (not UNACCOUNTED) with
   the quoted message.

4. **Only if AutoInvoice succeeded should the reconciler fall through to per-line reads:**
   base success in `RA_CUSTOMER_TRX_LINES_ALL` (join `RA_CUSTOMER_TRX_ALL`) on
   `interface_line_context` + `interface_line_attribute1` → `customer_trx_id`; per-line
   rejects in `RA_INTERFACE_ERRORS_ALL` joined by `interface_line_id` → `message_text`. (Column
   `invalid_line` is not queryable via this BIP path — ORA-00904; use `interface_line_id` +
   `message_text` only.) These are empty this run precisely because AutoInvoice never got that far.

5. **Upstream data/config fixes so AR can actually load** (separate from the reconciler fix):
   (a) For consolidated-billing batch sources like "External Source", submit through
   `AutoInvoiceMasterEss` (RAXMTR), not the direct `AutoInvoiceImportEss` — matching the
   README's documented two-job flow. (b) For "Manual-Other", associate that batch source with
   the reference set for US1 Business Unit (or use a batch source that is), or treat the BAD1
   row as an intentionally-bad record whose expected outcome is exactly this reference-set error.

## Evidence appendix

Interface rows for run 234 (RA_INTERFACE_LINES_ALL): 100002550114512 (G1), 100002550114513
(G2), 100002550114574 (BAD1) — all interface_status NULL, request_id NULL.
Base table RA_CUSTOMER_TRX_LINES_ALL: 0 rows for these keys.
Interface-error table RA_INTERFACE_ERRORS_ALL: 0 rows for these interface_line_ids.
AutoInvoiceImportEss ERROR requests: 9773727 (External Source), 9773803 (Manual-Other).
Child requests of those: none (ess_request_history parentrequestid lookup returned zero).
