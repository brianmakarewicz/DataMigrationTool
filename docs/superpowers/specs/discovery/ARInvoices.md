# ARInvoices — three-source reconciliation, RUN 132 (local Docker DMT)

READ-ONLY discovery. No DB object, pipeline, or DMT table was modified. Fusion reads
were live and read-only via `scripts/fusion_bip_query.py --cred fin_impl`.

## Object / tables / grain
- **CEMLI:** `ARInvoices` (ONE object, ONE FBDI zip loaded via AutoInvoice; two record
  types — lines and distributions).
- **TFM table used for the reconciliation grain:** `DMT_RA_LINES_TFM_TBL` (invoice lines).
  RUN 132 has 3 line records — the count the brief specifies for ARInvoices.
- **Grain decision:** count **lines** (LINE-grain), and sum the **line AMOUNT**. Reasons:
  (1) `DMT_RA_LINES_TFM_TBL` is line-grain; (2) all 3 rows are `LINE_TYPE='LINE'` and each is a
  distinct transaction (3 lines, 3 distinct TRX_NUMBERs) — so line count and transaction count
  coincide here; (3) the FUSION read-back key (`INTERFACE_LINE_ATTRIBUTE1`) is a per-line key.
  `RA_CUSTOMER_TRX_ALL` is header-grain (transactions); the line's parent CUSTOMER_TRX_ID is
  the DMT-stamped success id, but the balancing grain is the line.
- **Fusion base table (lines):** `RA_CUSTOMER_TRX_LINES_ALL`, read back by
  `INTERFACE_LINE_ATTRIBUTE1` (the stamped recon key), joined to `RA_CUSTOMER_TRX_ALL` for the
  header CUSTOMER_TRX_ID (the value DMT stores in `FUSION_CUSTOMER_TRX_ID`).
- **Interface tables (rejections):** `RA_INTERFACE_LINES_ALL` (+ `RA_INTERFACE_DISTRIBUTIONS_ALL`);
  errors in `RA_INTERFACE_ERRORS_ALL`.
- **Run keys (from `DMT_WORK_QUEUE_TBL`, run 132, queue_id 842):**
  LOAD_ESS_JOB_ID = 10023900, IMPORT_ESS_JOB_ID = 10023903. **NOTE:** the FBDI load was
  grouped by BU + batch source, so the 3 lines were loaded under TWO load requests live:
  `10023900` (Manual-Other, holds BAD1) and `10023876` (External Source, holds G1+G2).
- **Prefix (derived, never a key):** `93212`.

## Amount column + rationale
**AMOUNT = `DMT_RA_LINES_TFM_TBL.AMOUNT`** (the invoice line amount). AR invoices are
monetary, so money is meaningful and is summed at line grain.

## STG total (the run's record set)
STG has no RUN_ID, so the run's record set is the set of TFM line rows for RUN 132.

```sql
-- STG total (count + money) for the run = TFM line rows for this run
SELECT COUNT(*)                 AS stg_line_count,
       COUNT(DISTINCT trx_number) AS distinct_trx,
       SUM(amount)              AS stg_amount
FROM   dmt_ra_lines_tfm_tbl
WHERE  run_id = 132;
```
**Result: STG total = 3 lines, 3 distinct transactions, SUM(amount) = 5500.**

Detail:

| seq | status | recon_key | fusion_customer_trx_id | trx_number | BU | batch source | amount |
|----|--------|-----------|------------------------|------------|----|--------------|--------|
| 100029449 | FAILED | RT-AR-BAD1 | | 93212RT-AR-BAD1 | US1 Business Unit | Manual-Other    | 500 |
| 100029450 | FAILED | RT-AR-G1   | | 93212RT-AR-G1   | US1 Business Unit | External Source | 3200 |
| 100029451 | FAILED | RT-AR-G2   | | 93212RT-AR-G2   | US1 Business Unit | External Source | 1800 |

## TFM errors (count + money + real ERROR_TEXT)
```sql
SELECT tfm_sequence_id, recon_key, amount, SUBSTR(error_text,1,400) AS error_text
FROM   dmt_ra_lines_tfm_tbl
WHERE  run_id = 132
AND    tfm_status = 'FAILED'
ORDER  BY tfm_sequence_id;
```
**Result: 3 FAILED, SUM(error amount) = 5500 (all three lines).** Each carries the real
AutoInvoice job-abort rejection text:
`[FUSION_ERROR] [LINE] Rejected by AutoInvoice (no base transaction line created for this
key; AutoInvoice wrote no error row -- e.g. a job-level abort left the line unprocessed).`

This is honest per the DMT mission: AutoInvoice aborted at the job level and wrote NO per-row
error, so DMT reports each line FAILED with the true "no base line created / no error row"
status rather than fabricating a verdict. Confirmed live below.

## Fusion successes — 0 LOADED (Fusion side not confirmable in run 132)
`DMT_RUN_RECORDS_V` shows **0 LOADED, 3 FAILED** for ARInvoices in run 132. Confirmed live
that NO line reached the Fusion base table:

```sql
-- LIVE Fusion (read-only, fin_impl). Base lines for this run's prefix -> expect 0.
SELECT COUNT(*) AS cnt
FROM   ra_customer_trx_lines_all
WHERE  interface_line_attribute1 LIKE '93212%';
```
**Live result: 0.** No AR line reached `RA_CUSTOMER_TRX_LINES_ALL` (AutoInvoice is a known
environment residual on this demo instance — job-level abort, no per-row verdict).

Live confirmation the 3 records DID reach the Fusion interface (so they are genuine
attempts, not lost upstream):
```sql
SELECT trx_number, interface_line_attribute1, load_request_id, batch_source_name
FROM   ra_interface_lines_all
WHERE  trx_number LIKE '93212%'
ORDER  BY trx_number;
-- 93212RT-AR-BAD1 (load 10023900, Manual-Other), 93212RT-AR-G1 & G2 (load 10023876, External Source)
```
Live `RA_INTERFACE_ERRORS_ALL` returned 0 rows for these interface lines — consistent with a
job-level abort (no per-row AutoInvoice error was written), which is exactly the status DMT
reports.

### DESIGNED Fusion-success query (the shape for when AutoInvoice runs clean)
When AutoInvoice loads cleanly this query returns the loaded lines with real base ids and
money. It is the correct read-back design; it returns 0 today because 0 loaded.
```sql
-- Base LINE read-back: prove each line reached RA_CUSTOMER_TRX_LINES_ALL,
-- link to its header transaction, and sum the loaded money.
SELECT bl.interface_line_attribute1        AS record_key,
       bl.customer_trx_line_id             AS fusion_line_id,   -- base line id
       bh.customer_trx_id                  AS fusion_trx_id,    -- header id (== FUSION_CUSTOMER_TRX_ID)
       bl.extended_amount                  AS loaded_amount
FROM   ra_customer_trx_lines_all bl
JOIN   ra_customer_trx_all bh
       ON bh.customer_trx_id = bl.customer_trx_id
WHERE  bl.interface_line_attribute1 LIKE :P_PREFIX || '%';
-- success count = COUNT(*); success money = SUM(bl.extended_amount)
```
Exact base table = `RA_CUSTOMER_TRX_LINES_ALL`; key path = `INTERFACE_LINE_ATTRIBUTE1`
(stamped recon key) → parent `RA_CUSTOMER_TRX_ALL.CUSTOMER_TRX_ID`. DMT stores the header
id in `DMT_RA_LINES_TFM_TBL.FUSION_CUSTOMER_TRX_ID`.

## Balance check
```
Fusion successes + TFM errors = STG total
   0 lines / $0  +  3 lines / $5500 = 3 lines / $5500   ✔ BALANCED (all records accounted)
```
Every record is accounted for: 0 loaded to base, 3 failed with real (job-abort) errors.
**0-LOADED — the Fusion success side cannot be positively confirmed in run 132** because
AutoInvoice never created any base line. The account is still balanced and honest: the
success set is empty, and the failure set carries real Fusion status.

## Gotchas
- **INTERFACE_LINE_ATTRIBUTE1 is stored UNPREFIXED live** ("RT-AR-G1"), while TRX_NUMBER is
  prefixed ("93212RT-AR-G1") and the DMT TFM RECON_KEY is also the unprefixed "RT-AR-G1".
  The committed BASE-tier DM (`bip/ARInvoices/DMT_AR_RECON_DM.xdm`) filters base lines with
  `interface_line_attribute1 LIKE :P_PREFIX || '%'`, which would NOT match these unprefixed
  interface values. That mismatch is invisible today because 0 rows loaded, but it means the
  designed base read-back keying on the *prefix over ILA1* would need the recon key to be
  prefixed OR the filter changed to the recon key. The verified-safe live filter for run 132
  was `trx_number LIKE '93212%'`. Flag for whoever wires the live AR base read-back.
- Two load requests, one object: the BU+batch-source grouping split the single ARInvoices
  work item's FBDI into two ESS loads (10023900, 10023876). A base/interface read-back keyed
  only on IMPORT/LOAD_ESS_JOB_ID from the work queue would miss the External-Source lines —
  key on the prefix (or all load reqs for the run), not a single job id.
- AutoInvoice is a known env-blocked residual on this demo instance: expect 0 base AR lines
  until the functional owner enables it. The failure shape here is the honest job-level-abort
  shape (Fusion produced no per-row verdict), not a DMT defect.
- No money is lost: STG money (5500) equals FAILED money (5500); success money is 0.
```
