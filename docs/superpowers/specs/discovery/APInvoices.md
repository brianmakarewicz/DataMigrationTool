# AP Invoices — Three-Source Reconciliation (RUN_ID 132)

Read-only discovery proving the post-run comparison report for one object: **AP Invoices**,
pipeline **RUN_ID = 132** on the local Docker DMT DB (`dmt_owner @ //localhost:1523/FREEPDB1`).
Fusion successes are read **live** from the Fusion demo via `scripts/fusion_bip_query.py`.

Goal: prove `Fusion successes + TFM errors = STG total` (count and amount).

---

## 1. Object, tables, grain, money column

| Item | Value |
|---|---|
| CEMLI_CODE | `APInvoices` |
| Grain of this report | **Invoice HEADER** (one row = one invoice) |
| STG table | `DMT_AP_INVOICES_INT_STG_TBL` |
| TFM table | `DMT_AP_INVOICES_INT_TFM_TBL` |
| Fusion base table | `AP_INVOICES_ALL` (header) |
| Fusion id column | `INVOICE_ID` (captured back into TFM as `FUSION_INVOICE_ID`) |
| Money column | **`INVOICE_AMOUNT`** (header invoice amount) |

**Grain rationale.** AP invoices have a header/line grain (`ap_invoices_all` /
`ap_invoice_lines_all`; STG/TFM also have a separate lines table). The tool's per-record
accounting for this object is at the **header** level — the TFM header table carries `RUN_ID`,
`TFM_STATUS`, `FUSION_INVOICE_ID`, and `RECON_KEY` at header grain, and the FUSION_ID captured
at load is the header `INVOICE_ID`. So this reconciliation counts **headers** and sums the
**header `INVOICE_AMOUNT`**. Lines are a separate object/grain and are out of scope here.

**Money-column rationale.** `INVOICE_AMOUNT` is the invoice's total control amount and is the
only header-grain amount that is present and comparable in all three sources (STG, TFM, and
Fusion `ap_invoices_all.invoice_amount`). `CONTROL_AMOUNT` exists but is not consistently
populated; `INVOICE_AMOUNT` is the correct tie-out figure.

**Run linkage note.** The STG table has **no `RUN_ID` or `CEMLI` column**. STG rows are tied to
a run only through the TFM table: `TFM.STG_SEQUENCE_ID = STG.STG_SEQUENCE_ID` where
`TFM.RUN_ID = 132`. The STG query below therefore joins STG to TFM to scope the run.

---

## 2. STG total — records this run processed

```sql
SELECT COUNT(*)                    AS stg_count,
       NVL(SUM(s.invoice_amount),0) AS stg_amount
FROM   dmt_ap_invoices_int_stg_tbl s
JOIN   dmt_ap_invoices_int_tfm_tbl t
       ON t.stg_sequence_id = s.stg_sequence_id
WHERE  t.run_id = 132;
```

**Result:** `STG_COUNT = 4`, `STG_AMOUNT = 9250`.

(Cross-check: TFM total for the run is identical — 4 rows, 9250 — confirming every staged
record produced exactly one transform record, no fan-out at header grain.)

---

## 3. TFM errors — records this run failed

```sql
SELECT COUNT(*)                    AS fail_count,
       NVL(SUM(invoice_amount),0)  AS fail_amount
FROM   dmt_ap_invoices_int_tfm_tbl
WHERE  run_id = 132
AND    tfm_status = 'FAILED';
```

**Result:** `FAIL_COUNT = 2`, `FAIL_AMOUNT = 5000`.

Real `ERROR_TEXT` confirmed on both failed rows (not blank, not fabricated):

| INVOICE_NUM | INVOICE_AMOUNT | FUSION_INVOICE_ID | ERROR_TEXT (truncated) |
|---|---|---|---|
| `93212RT-APINV-BAD1` | 0 | (null) | `[FUSION_ERROR] [HDR] INVALID SUPPLIER` |
| `93212RT-1099-G1` | 5000 | (null) | `[FUSION_ERROR] [HDR] Rejected by Payables Import (status=REJECTED; no rejection row written -- e.g. header rejected pre-validation).` |

Both carry a real Fusion rejection message and neither has a `FUSION_INVOICE_ID`, consistent
with never landing in the base table.

---

## 4. Fusion successes — LIVE from Fusion base table

**Key path chosen:** the **import request id** (LOAD_ID) from the work queue — the most reliable
key. It is not the prefix and not the unreliable record-view `WORK_QUEUE_ID`.

Import request id lookup (local DB):

```sql
SELECT queue_id, cemli_code, work_status,
       load_ess_job_id, import_ess_job_id
FROM   dmt_work_queue_tbl
WHERE  run_id = 132
AND    cemli_code = 'APInvoices';
-- -> QUEUE_ID 839, WORK_STATUS DONE, LOAD_ESS_JOB_ID 10024195, IMPORT_ESS_JOB_ID 10024200
```

**Import request id (Payables Import ESS job) = `10024200`** → this is `ap_invoices_all.REQUEST_ID`.

### Live Fusion query (via `scripts/fusion_bip_query.py --cred fin_impl`)

Primary — keyed on the import request id:

```sql
SELECT COUNT(*) cnt, SUM(invoice_amount) total
FROM   ap_invoices_all
WHERE  request_id = 10024200
```

**Live result:** `CNT = 2`, `TOTAL = 4250`.

Corroboration — keyed on the two `FUSION_INVOICE_ID`s captured at load:

```sql
SELECT invoice_id, invoice_num, invoice_amount, request_id
FROM   ap_invoices_all
WHERE  invoice_id IN (1559400, 1559401)
```

**Live result:**

| INVOICE_ID | INVOICE_NUM | INVOICE_AMOUNT | REQUEST_ID |
|---|---|---|---|
| 1559400 | `93212RT-APINV-G2` | 2750 | 10024200 |
| 1559401 | `93212RT-APINV-G1` | 1500 | 10024200 |

Both paths agree: 2 headers, 2750 + 1500 = **4250**, all under REQUEST_ID 10024200. The two
Fusion `INVOICE_ID`s match the `FUSION_INVOICE_ID`s recorded on the two LOADED TFM rows, and the
`INVOICE_NUM`s match. Fusion data confirmed live (BIP data model executed against the demo pod).

**Chosen amount column:** `AP_INVOICES_ALL.INVOICE_AMOUNT`, matching the STG/TFM
`INVOICE_AMOUNT` — same header-grain figure across all three sources.

---

## 5. Balance check

| Source | Count | Amount |
|---|---|---|
| STG total (processed) | 4 | 9250 |
| Fusion successes (live) | 2 | 4250 |
| TFM errors (failed) | 2 | 5000 |
| **Fusion + TFM errors** | **4** | **9250** |

Equation: `Fusion successes + TFM errors = STG total`
- Count: `2 + 2 = 4` = `4` ✓
- Amount: `4250 + 5000 = 9250` = `9250` ✓

**BALANCED.** Exact tie on both count and amount. 0 unaccounted.

---

## 6. Gotchas / notes for building the report

- **STG has no RUN_ID/CEMLI.** Scope STG to a run only by joining STG→TFM on
  `STG_SEQUENCE_ID` where `TFM.RUN_ID = :run`. Do not attempt to filter STG by prefix or by a
  run column — neither exists.
- **Grain must be stated.** This is header grain. AP invoice **lines** are a separate object
  (`DMT_AP_INVOICE_LINES_INT_*` / `ap_invoice_lines_all`) with their own accounting; do not mix.
- **Key the Fusion query on the import request id (`10024200`) or the captured
  `FUSION_INVOICE_ID`s — never on the prefix.** `DMT_WORK_QUEUE_TBL.IMPORT_ESS_JOB_ID` is the
  request id; it maps to `ap_invoices_all.REQUEST_ID`. The record-view `WORK_QUEUE_ID` is not
  reliably populated and was not used.
- **Failed rows have no FUSION_INVOICE_ID** and carry a real `[FUSION_ERROR]` message — that is
  the intended "honest accounting" shape (attempted, rejected, error captured), not a defect.
- **FUSION_INVOICE_ID vs FUSION_ID.** In the TFM table the column is `FUSION_INVOICE_ID`; the
  generic per-record view `DMT_RUN_RECORDS_V` exposes it as `FUSION_ID`.
- Fusion query tool: `scripts/fusion_bip_query.py --cred fin_impl --cols <ALIASES> "<SELECT>"`.
  Alias every output column to a simple upper-case identifier and pass those to `--cols` in order.
```
```

