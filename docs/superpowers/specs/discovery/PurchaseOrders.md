# PurchaseOrders — three-source reconciliation (RUN_ID 132, local Docker)

Read-only discovery proving STG total = Fusion successes + TFM errors for the
PurchaseOrders object on pipeline RUN_ID 132. All numbers below came from real
queries: the DMT side from the local Docker DB (`dmt_owner @ //localhost:1523/FREEPDB1`),
the Fusion side LIVE from the demo instance via `scripts/fusion_bip_query.py --cred fin_impl`.
Nothing was modified.

## Object / tables

- **Object grain:** the PO **header** (one object = one FBDI zip = one ImportSPOJob).
  RECON_KEY / segment1 = `93212RT-PO-001 / -002 / -BAD1`.
- **STG table (header):** `DMT_PO_HEADERS_INT_STG_TBL`
- **STG table (lines, money source):** `DMT_PO_LINES_INT_STG_TBL`
- **TFM table (header):** `DMT_PO_HEADERS_INT_TFM_TBL` (carries `RUN_ID`, `TFM_STATUS`,
  `RECON_KEY`, `FUSION_PO_HEADER_ID`, `ERROR_TEXT`, `DOCUMENT_TYPE_CODE`)
- **TFM table (lines, money source):** `DMT_PO_LINES_INT_TFM_TBL` (`AMOUNT`, `QUANTITY`, `UNIT_PRICE`)
- **Fusion base tables:** `PO_HEADERS_ALL` (grain / success flag), `PO_LINES_ALL` (money)
- **Fusion id column:** `PO_HEADERS_ALL.PO_HEADER_ID` = the DMT `FUSION_PO_HEADER_ID` captured at load.

**Critical scoping gotcha:** `DMT_PO_HEADERS_INT_TFM_TBL` is shared by THREE objects that
split on `DOCUMENT_TYPE_CODE`: PurchaseOrders (STANDARD), BlanketPOs (BLANKET), Contracts
(CONTRACT). RUN 132 has 7 header rows in that table. PurchaseOrders is **STANDARD only** —
every query below filters `NVL(DOCUMENT_TYPE_CODE,'STANDARD')='STANDARD'`. An unfiltered
count returns 7 and is wrong for this object.

## Chosen amount column + rationale

The PO **header** interface carries no amount. Money lives on the lines. For STANDARD POs
the extended line value is **`QUANTITY * UNIT_PRICE`** — the `AMOUNT` column is null on
STANDARD lines (it is populated for services/blanket amount-based lines, a different object).
So the comparable money is `SUM(QUANTITY * UNIT_PRICE)` over the lines of the run's STANDARD
headers, and on the Fusion side `SUM(pl.quantity * pl.unit_price)` over `PO_LINES_ALL` for
those headers. This is the total ordered value of the POs — the natural "did the money land"
figure. Count is at the object grain = number of PO headers.

## STG query + result

STG total = the records this run processed at the object (header) grain, with line money.
The STG tables have no `RUN_ID` (they are run-agnostic input); the run's records are the TFM
rows, joined back to lines for money.

```sql
SELECT COUNT(DISTINCT th.TFM_SEQUENCE_ID) HDR_CNT,
       SUM(tl.QUANTITY*tl.UNIT_PRICE)      SUM_QP
FROM   DMT_PO_HEADERS_INT_TFM_TBL th
LEFT JOIN DMT_PO_LINES_INT_TFM_TBL tl
       ON tl.INTERFACE_HEADER_KEY = th.INTERFACE_HEADER_KEY
      AND tl.RUN_ID = th.RUN_ID
WHERE  th.RUN_ID = 132
  AND  NVL(th.DOCUMENT_TYPE_CODE,'STANDARD') = 'STANDARD';
```

Result: **HDR_CNT = 3, SUM_QP = 2300.**

## TFM-error query + result

```sql
SELECT COUNT(DISTINCT th.TFM_SEQUENCE_ID) HDR_CNT,
       SUM(tl.QUANTITY*tl.UNIT_PRICE)      SUM_QP
FROM   DMT_PO_HEADERS_INT_TFM_TBL th
LEFT JOIN DMT_PO_LINES_INT_TFM_TBL tl
       ON tl.INTERFACE_HEADER_KEY = th.INTERFACE_HEADER_KEY
      AND tl.RUN_ID = th.RUN_ID
WHERE  th.RUN_ID = 132
  AND  NVL(th.DOCUMENT_TYPE_CODE,'STANDARD') = 'STANDARD'
  AND  th.TFM_STATUS = 'FAILED';
```

Result: **HDR_CNT = 1, SUM_QP = 50** (RECON_KEY `93212RT-PO-BAD1`).

Real error confirmed on that FAILED row:
```
[FUSION_ERROR] [HDR] VENDOR_NUM: The supplier isn't valid. Verify that the supplier is
active, has a business relationship that's spend authorized, and has at least one active
purchasing site associated to the procurement business unit. | VENDOR_SITE_CODE: The
supplier site isn't valid. ...
```
This is a genuine Fusion PO-import rejection (invalid supplier), not a placeholder.

## Fusion success query + result (LIVE)

**Key path used: LOAD_ID / import request id** = `PO_HEADERS_ALL.REQUEST_ID = 10024267`,
taken from `DMT_WORK_QUEUE_TBL.IMPORT_ESS_JOB_ID` (RUN_ID 132, CEMLI_CODE 'PurchaseOrders',
QUEUE_ID 836, WORK_STATUS DONE). This is the production-valid key — it ties Fusion rows to the
exact import ESS request this run submitted. (Cross-checked: both loaded headers also carry
`request_id = 10024267`, and `PO_HEADER_ID` 679901/679902 match the DMT captured
`FUSION_PO_HEADER_ID`.) The prefix was NOT used as a key.

Header count (success grain), live:
```sql
SELECT COUNT(*) HDR_CNT, request_id REQID
FROM   PO_HEADERS_ALL
WHERE  request_id = 10024267
  AND  type_lookup_code = 'STANDARD'
GROUP BY request_id;
```
Result: **HDR_CNT = 2** (REQID 10024267).

Money (extended line value), live:
```sql
SELECT COUNT(*) LINE_CNT, SUM(pl.quantity*pl.unit_price) SUM_QP
FROM   PO_LINES_ALL pl
WHERE  pl.po_header_id IN (
         SELECT po_header_id FROM PO_HEADERS_ALL
         WHERE request_id = 10024267 AND type_lookup_code = 'STANDARD');
```
Result: **LINE_CNT = 2, SUM_QP = 2250.**

Invocation (exact):
```
python scripts/fusion_bip_query.py --cred fin_impl --cols HDR_CNT,REQID "<query above>"
python scripts/fusion_bip_query.py --cred fin_impl --cols LINE_CNT,SUM_QP "<query above>"
```

Per-header cross-check (live): 679901 = `93212RT-PO-001`, 679902 = `93212RT-PO-002`, both
STANDARD, both request_id 10024267. DMT per-header money: 679901 = 1000, 679902 = 1250.

## Balance check

| Source | Count | Money (SUM qty*price) |
|---|---|---|
| STG total | 3 | 2300 |
| Fusion successes (live) | 2 | 2250 |
| TFM errors | 1 | 50 |
| Fusion + errors | **3** | **2300** |

**BALANCED** — both count (2 + 1 = 3 = STG 3) and money (2250 + 50 = 2300 = STG 2300) tie
exactly, against a LIVE Fusion read.

## Gotchas (for the report builder)

1. **Shared TFM table, must filter DOCUMENT_TYPE_CODE.** PurchaseOrders = STANDARD only;
   BlanketPOs = BLANKET; Contracts = CONTRACT all live in `DMT_PO_HEADERS_INT_TFM_TBL`.
   RUN 132 has all three (7 rows total). Never count that table without the STANDARD filter.
2. **STG tables have no RUN_ID.** They are run-agnostic input. Use the TFM rows (which carry
   RUN_ID) as the run's record set; join to STG/TFM lines by INTERFACE_HEADER_KEY + RUN_ID.
3. **Money is on lines, not the header, and STANDARD lines use QUANTITY*UNIT_PRICE, not AMOUNT.**
   `AMOUNT` is null for STANDARD lines (it is the amount-based/blanket column). Summing AMOUNT
   for STANDARD returns null.
4. **Import request id is the reliable Fusion key.** `DMT_RUN_RECORDS_V.WORK_QUEUE_ID` is
   empty for these rows, so do not key off it. Use `DMT_WORK_QUEUE_TBL.IMPORT_ESS_JOB_ID`
   (join RUN_ID + CEMLI_CODE); its PK column is `QUEUE_ID`, not WORK_QUEUE_ID.
5. **fusion_bip_query.py output** is BIP XML — read values from the `<COL>value</COL>` tags,
   not a tabular grid.
```
