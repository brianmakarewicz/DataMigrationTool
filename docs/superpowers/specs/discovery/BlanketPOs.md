# BlanketPOs — three-source reconciliation, RUN_ID 132 (local Docker DMT DB)

Read-only discovery. Nothing was modified. All Docker figures are `SELECT`s against
`dmt_owner@//localhost:1523/FREEPDB1`; all Fusion figures were read live from the demo
instance via `python scripts/fusion_bip_query.py --cred fin_impl`.

## Object / tables / grain

- **Object:** BlanketPOs (Blanket Purchase Agreement, BPA). One FBDI zip, loaded by ESS job
  `ImportBPAJob`.
- **Grain:** header + line (no line-locations, no distributions in the BPA FBDI). RUN 132
  produced 2 headers and 1 line.
- **DMT tables (SHARED with PurchaseOrders and Contracts):**
  - Header STG `DMT_PO_HEADERS_INT_STG_TBL`, header TFM `DMT_PO_HEADERS_INT_TFM_TBL`.
  - Line STG `DMT_PO_LINES_INT_STG_TBL`, line TFM `DMT_PO_LINES_INT_TFM_TBL`.
  - The shared PO-family tables are separated by `DOCUMENT_TYPE_CODE`. **BlanketPOs = `'BLANKET'`.**
- **Fusion base tables:** `PO_HEADERS_ALL` (+ `PO_LINES_ALL`). Fusion id = `PO_HEADER_ID`
  (captured into `DMT_PO_HEADERS_INT_TFM_TBL.FUSION_PO_HEADER_ID`).
- **Run view:** `DMT_RUN_RECORDS_V` shows OBJECT_TYPE `BlanketPOs:US1 Business Unit`
  (grouped by BU). Only header rows surface in the view for this run (no `BlanketPOs.Line` row).

## STG total (count + money)

STG has no RUN_ID. The run's STG record set is reached from the run's TFM rows via
`STG_SEQUENCE_ID`, then filtered to `DOCUMENT_TYPE_CODE='BLANKET'`. The run's prefix is 93212.

```sql
-- STG headers belonging to RUN 132 BlanketPOs (via the run's TFM rows)
SELECT hs.document_num, hs.document_type_code
FROM   dmt_po_headers_int_tfm_tbl t
JOIN   dmt_po_headers_int_stg_tbl hs ON hs.stg_sequence_id = t.stg_sequence_id
WHERE  t.recon_key LIKE '93212%'
AND    t.document_type_code = 'BLANKET';

-- STG line money for those headers
SELECT SUM(ls.amount) AS stg_money
FROM   dmt_po_headers_int_tfm_tbl t
JOIN   dmt_po_headers_int_stg_tbl hs ON hs.stg_sequence_id = t.stg_sequence_id
JOIN   dmt_po_lines_int_stg_tbl  ls ON ls.interface_header_key = hs.interface_header_key
WHERE  t.recon_key LIKE '93212%'
AND    t.document_type_code = 'BLANKET';
```

**Result:** 2 STG headers (`RT-BPA-001`, `RT-BPA-BAD1`). STG line money is unreliable here — the
seed inserted the BPA-001 good line **twice** (STG_SEQUENCE_ID 100000938 and 100000942, both
`interface_line_key='RT-BPAL-G1'`, both AMOUNT 50000), so `SUM(ls.amount)` over STG double-counts
to 100,000. **The authoritative record set is the TFM**, which de-duplicated to one line
(AMOUNT 50000). Use TFM totals for balancing; the STG duplicate is a seed-data artifact, noted
in gotchas.

**Authoritative STG-equivalent total (from TFM, the run's record set):**
count = 2 headers, money = **50,000** (the single BPA-001 line amount).

## TFM errors (count + money, real ERROR_TEXT)

```sql
SELECT recon_key, tfm_status, vendor_num
FROM   dmt_po_headers_int_tfm_tbl
WHERE  recon_key LIKE '93212%' AND document_type_code = 'BLANKET'
ORDER  BY recon_key;

-- real error text (run view)
SELECT recon_key, tfm_status, DBMS_LOB.SUBSTR(error_text,400,1) AS error_text
FROM   dmt_run_records_v
WHERE  run_id = 132 AND object_type LIKE 'BlanketPOs%' AND tfm_status = 'FAILED';
```

**Result:** 1 FAILED header — `93212RT-BPA-BAD1` (VENDOR_NUM `NOSUP-999`, no line, no
FUSION_PO_HEADER_ID). Real Fusion error captured:

> `[FUSION_ERROR] [HDR] VENDOR_NUM: The supplier isn't valid. Verify that the supplier is
> active and has a business relationship that's spend authorized. | VENDOR_SITE_CODE: The
> supplier site isn't valid ...`

**TFM error count = 1, error money = 0** (the BAD header has no line, so no line amount).

## Fusion successes (count + money, LIVE)

Key path: **import request id** from `DMT_WORK_QUEUE_TBL` — for RUN 132 BlanketPOs,
`IMPORT_ESS_JOB_ID = 10024172` — matched against `PO_HEADERS_ALL.REQUEST_ID` (same pattern PO
used), filtered to `TYPE_LOOKUP_CODE='BLANKET'`. This is the preferred path; the captured
`FUSION_PO_HEADER_ID = 679899` is the independent cross-check.

```sql
-- LIVE Fusion (fin_impl). Base header proof.
SELECT po_header_id, segment1, type_lookup_code
FROM   PO_HEADERS_ALL
WHERE  request_id = 10024172 AND type_lookup_code = 'BLANKET';

-- LIVE Fusion. Base line (money on the blanket line).
SELECT l.po_line_id, l.po_header_id, l.line_num,
       l.amount, l.quantity, l.unit_price
FROM   PO_LINES_ALL l
JOIN   PO_HEADERS_ALL h ON h.po_header_id = l.po_header_id
WHERE  l.request_id = 10024172 AND h.type_lookup_code = 'BLANKET';
```

**Result (live):** 1 header — `PO_HEADER_ID 679899`, segment1 `93212RT-BPA-001` (matches the
captured FUSION_PO_HEADER_ID). 1 line — `po_line_id 1295202`, unit_price 25, **AMOUNT and
QUANTITY NULL in the Fusion base**. Header amount columns (`AMOUNT_LIMIT`,
`BLANKET_TOTAL_AMOUNT`, `MIN_RELEASE_AMOUNT`) are all NULL.

**Fusion success count = 1.** Fusion money is **not queryable** for this blanket line: the
50,000 our pipeline carried does not round-trip to a populated money column on
`PO_LINES_ALL`/`PO_HEADERS_ALL` for a BLANKET line on this pod.

Independent failure cross-check (live):

```sql
SELECT interface_header_key, process_code, document_num
FROM   PO_HEADERS_INTERFACE
WHERE  load_request_id = 10024165                              -- LOAD_ESS_JOB_ID for BlanketPOs
AND    interface_header_key LIKE '132\_HDR\_%' ESCAPE '\'
AND    NVL(process_code,'X') <> 'ACCEPTED';
```

Returns 1 row: `132_HDR_100000150`, `process_code=REJECTED`, `document_num=93212RT-BPA-BAD1`
— confirms the FAILED count against Fusion, matching the TFM FAILED row.

## Fusion money column

Follow-up discovery (READ-ONLY, live `fin_impl`). We ALWAYS query Fusion for money, so this
re-checks the earlier "money does not round-trip" claim against the RIGHT columns before
accepting it. It holds up, and the reason is now known: **the blanket line was created in
Fusion as a quantity-based line, where a line-level AMOUNT is not a valid stored input.**

The DMT pipeline carried, on the single BPA line, `AMOUNT=50000, QUANTITY=NULL, UNIT_PRICE=25`
(verified in `DMT_PO_LINES_INT_STG_TBL`). In Fusion, only `UNIT_PRICE=25` round-tripped.

Live proof (BPA header `PO_HEADER_ID 679899`, line `PO_LINE_ID 1295202`):

```sql
-- Header money columns (the only four amount columns on PO_HEADERS_ALL) -- all NULL.
SELECT po_header_id, segment1, type_lookup_code,
       amount_limit, amount_released, blanket_total_amount, min_release_amount
FROM   po_headers_all
WHERE  po_header_id = 679899;
-- 679899 | 93212RT-BPA-001 | BLANKET | AMOUNT_LIMIT NULL | AMOUNT_RELEASED NULL
--        | BLANKET_TOTAL_AMOUNT NULL | MIN_RELEASE_AMOUNT NULL

-- The line was loaded QUANTITY-based, so AMOUNT is not stored; every line money
-- column is NULL except UNIT_PRICE.
SELECT line_num, order_type_lookup_code, purchase_basis, matching_basis,
       amount, quantity, unit_price,
       committed_amount, quantity_committed, min_release_amount,
       amount_released, not_to_exceed_price, max_retainage_amount
FROM   po_lines_all
WHERE  po_line_id = 1295202;
-- LINE 1 | ORDER_TYPE_LOOKUP_CODE=QUANTITY | PURCHASE_BASIS=GOODS | MATCHING_BASIS=QUANTITY
--        | AMOUNT NULL | QUANTITY NULL | UNIT_PRICE 25
--        | COMMITTED_AMOUNT NULL | QUANTITY_COMMITTED NULL | MIN_RELEASE_AMOUNT NULL
--        | AMOUNT_RELEASED NULL | NOT_TO_EXCEED_PRICE NULL | MAX_RETAINAGE_AMOUNT NULL

-- No line-locations exist for this BPA (nothing to sum there either).
SELECT COUNT(*) FROM po_line_locations_all WHERE po_header_id = 679899;   -- 0
```

**Conclusion: confirmed no queryable Fusion money amount for this blanket line as loaded.**
Every candidate Fusion money column (header `AMOUNT_LIMIT` / `AMOUNT_RELEASED` /
`BLANKET_TOTAL_AMOUNT` / `MIN_RELEASE_AMOUNT`; line `AMOUNT` / `QUANTITY` / `COMMITTED_AMOUNT`
/ `QUANTITY_COMMITTED` / `MIN_RELEASE_AMOUNT` / `AMOUNT_RELEASED` / `NOT_TO_EXCEED_PRICE` /
`MAX_RETAINAGE_AMOUNT`) is NULL on this pod; only `UNIT_PRICE=25` round-tripped. The 50,000
the DMT pipeline sent in the line AMOUNT column was silently dropped because Fusion created the
line as quantity-based (`ORDER_TYPE_LOOKUP_CODE=QUANTITY`), where AMOUNT is not a valid input.
Money for this object is therefore sourced DMT-side (TFM line AMOUNT = 50,000); Fusion proves
the row loaded (count + PO_HEADER_ID), not its money. (If the intent is an amount-based blanket
line, the FBDI would need to load the line as AMOUNT-type so Fusion persists AMOUNT — a
data/generator question, not a reconciliation-column question.)

## Amount column + rationale

- **Chosen amount = line-level `AMOUNT` from the STG/TFM line row (50,000).** A blanket line
  carries its value in `AMOUNT` directly (quantity is NULL, so quantity*unit_price is NULL and
  would be wrong here — this is the opposite of the STANDARD PO case where AMOUNT was NULL and
  we used quantity*unit_price).
- **Money is sourced DMT-side, not Fusion-side.** Fusion's base tables do not persist a
  queryable amount for the blanket line on this pod (AMOUNT/QUANTITY NULL on `PO_LINES_ALL`;
  blanket header amount columns NULL). So the money figure comes from the TFM line; Fusion
  proves the row *loaded* (count + PO_HEADER_ID), not its money.

## Balance check

Count balance (the reliable, LOADED-vs-FAILED accounting):

| Source | Headers |
|---|---|
| STG total (run's record set = TFM) | 2 |
| Fusion successes (LOADED) | 1 |
| TFM errors (FAILED, real Fusion error) | 1 |
| Successes + errors | 2 |

**BALANCED on count: 1 + 1 = 2 = STG total.**

Money: STG/TFM LOADED money = 50,000; FAILED money = 0. Total DMT money = 50,000. There is no
Fusion-side money figure to compare against (see rationale), so money reconciliation is
one-sided by design for blanket agreements — the 50,000 is carried through to a successfully
loaded document, and the failed document carried no money.

## Gotchas

- **Shared TFM table.** `DMT_PO_HEADERS_INT_TFM_TBL` / `..._LINES_INT_TFM_TBL` are shared by
  PurchaseOrders, BlanketPOs, and Contracts. ALWAYS filter by `DOCUMENT_TYPE_CODE`. BlanketPOs
  = `'BLANKET'`. Without the filter you pick up STANDARD and CONTRACT rows too (RUN 132 has 7
  PO-family header rows: 3 STANDARD, 2 BLANKET, 2 CONTRACT).
- **Run view OBJECT_TYPE is BU-suffixed:** `BlanketPOs:US1 Business Unit`, not `BlanketPOs`.
  Query `object_type LIKE 'BlanketPOs%'`.
- **STG has a duplicated good line** (seed artifact): `SUM(amount)` over STG lines double-counts
  to 100,000. Use the TFM as the record set (one line, 50,000).
- **STG.SOURCE_ID is a text business reference** (e.g. `RT-BPAL-G1`), not the numeric PK. Join
  STG↔TFM on `STG_SEQUENCE_ID`, never SOURCE_ID.
- **Blanket money does not round-trip to Fusion.** Do not expect a Fusion base-table amount for
  a blanket line; prove the load by count + PO_HEADER_ID, source money from the TFM line.
- Key path preference: `IMPORT_ESS_JOB_ID` (=10024172) → `PO_HEADERS_ALL.REQUEST_ID`. The
  captured `FUSION_PO_HEADER_ID` (679899) is the backup/cross-check. Never the prefix.
