# Contracts — three-source reconciliation, RUN_ID 132 (local Docker DMT DB)

Read-only discovery. Nothing was modified. All Docker figures are `SELECT`s against
`dmt_owner@//localhost:1523/FREEPDB1`; all Fusion figures were read live from the demo
instance via `python scripts/fusion_bip_query.py --cred fin_impl`.

## Object / tables / grain

- **Object:** Contracts (Contract Purchase Agreement, CPA). One FBDI zip, loaded by ESS job
  `ImportCPAJob`.
- **Grain:** **header only.** The CPA FBDI carries a header record type only — no lines, no
  line-locations, no distributions. Confirmed both in DMT (no CONTRACT line rows in the line
  TFM/STG) and in Fusion (0 rows in `PO_LINES_ALL` for the import request). RUN 132 produced
  2 headers.
- **DMT tables (SHARED with PurchaseOrders and BlanketPOs):**
  - Header STG `DMT_PO_HEADERS_INT_STG_TBL`, header TFM `DMT_PO_HEADERS_INT_TFM_TBL`.
  - The shared PO-family header table is separated by `DOCUMENT_TYPE_CODE`.
    **Contracts = `'CONTRACT'`.**
- **Fusion base table:** `PO_HEADERS_ALL`. Fusion id = `PO_HEADER_ID` (captured into
  `DMT_PO_HEADERS_INT_TFM_TBL.FUSION_PO_HEADER_ID`).
- **Run view:** `DMT_RUN_RECORDS_V` shows OBJECT_TYPE `Contracts:US1 Business Unit` (BU-grouped),
  2 header rows.

## STG total (count + money)

STG has no RUN_ID. The run's STG record set is reached from the run's TFM rows via
`STG_SEQUENCE_ID`, then filtered to `DOCUMENT_TYPE_CODE='CONTRACT'`. Run prefix is 93212.

```sql
SELECT hs.document_num, hs.document_type_code
FROM   dmt_po_headers_int_tfm_tbl t
JOIN   dmt_po_headers_int_stg_tbl hs ON hs.stg_sequence_id = t.stg_sequence_id
WHERE  t.recon_key LIKE '93212%'
AND    t.document_type_code = 'CONTRACT';
```

**Result:** 2 STG headers (`RT-CPA-001`, `RT-CPA-BAD1`).

**Money: none.** CPA is header-only and there is **no amount column anywhere in the DMT
pipeline** for it — the header STG and header TFM have no AMOUNT / AGREED / LIMIT column, and
there are no line rows. STG total: count = 2, money = **not applicable**.

## TFM errors (count + money, real ERROR_TEXT)

```sql
SELECT recon_key, tfm_status, vendor_num
FROM   dmt_po_headers_int_tfm_tbl
WHERE  recon_key LIKE '93212%' AND document_type_code = 'CONTRACT'
ORDER  BY recon_key;

-- real error text (run view)
SELECT recon_key, tfm_status, DBMS_LOB.SUBSTR(error_text,400,1) AS error_text
FROM   dmt_run_records_v
WHERE  run_id = 132 AND object_type LIKE 'Contracts%' AND tfm_status = 'FAILED';
```

**Result:** 1 FAILED header — `93212RT-CPA-BAD1` (VENDOR_NUM `NOSUP-999`, no
FUSION_PO_HEADER_ID). Real Fusion error captured:

> `[FUSION_ERROR] [HDR] VENDOR_NUM: The supplier isn't valid. Verify that the supplier is
> active and has a business relationship that's spend authorized. | VENDOR_SITE_CODE: The
> supplier site isn't valid ...`

**TFM error count = 1, error money = not applicable** (no amount grain for CPA).

## Fusion successes (count + money, LIVE)

Key path: **import request id** from `DMT_WORK_QUEUE_TBL` — for RUN 132 Contracts,
`IMPORT_ESS_JOB_ID = 10024188` — matched against `PO_HEADERS_ALL.REQUEST_ID`, filtered to
`TYPE_LOOKUP_CODE='CONTRACT'`. Captured `FUSION_PO_HEADER_ID = 679900` is the cross-check.

```sql
-- LIVE Fusion (fin_impl). Base header proof.
SELECT po_header_id, segment1, type_lookup_code,
       amount_limit, min_release_amount
FROM   PO_HEADERS_ALL
WHERE  request_id = 10024188 AND type_lookup_code = 'CONTRACT';

-- LIVE Fusion. Confirm header-only (expect 0).
SELECT COUNT(*)
FROM   PO_LINES_ALL l
JOIN   PO_HEADERS_ALL h ON h.po_header_id = l.po_header_id
WHERE  l.request_id = 10024188 AND h.type_lookup_code = 'CONTRACT';
```

**Result (live):** 1 header — `PO_HEADER_ID 679900`, segment1 `93212RT-CPA-001` (matches the
captured FUSION_PO_HEADER_ID). `AMOUNT_LIMIT` and `MIN_RELEASE_AMOUNT` NULL. `PO_LINES_ALL`
count = 0 (confirms header-only).

**Fusion success count = 1.** No Fusion money figure (header-only CPA, amount columns NULL).

Independent failure cross-check (live):

```sql
SELECT interface_header_key, process_code, document_num
FROM   PO_HEADERS_INTERFACE
WHERE  load_request_id = 10024181                              -- LOAD_ESS_JOB_ID for Contracts
AND    interface_header_key LIKE '132\_HDR\_%' ESCAPE '\'
AND    NVL(process_code,'X') <> 'ACCEPTED';
```

Returns 1 row: `132_HDR_100000152`, `process_code=REJECTED`, `document_num=93212RT-CPA-BAD1`
— confirms the FAILED count against Fusion, matching the TFM FAILED row.

## Fusion money column

Follow-up discovery (READ-ONLY, live `fin_impl`). We ALWAYS query Fusion for money, so this
re-checks whether a Contract Purchase Agreement (CPA) carries an agreed amount in Fusion
against every money column that exists on the base header table — before accepting "no money."

`PO_HEADERS_ALL` has exactly four amount columns: `AMOUNT_LIMIT`, `AMOUNT_RELEASED`,
`BLANKET_TOTAL_AMOUNT`, `MIN_RELEASE_AMOUNT`. All four are NULL on the loaded CPA header. A CPA
is header-only, so there are no line/location/distribution rows to carry money either.

Live proof (CPA header `PO_HEADER_ID 679900`):

```sql
-- All four money columns on PO_HEADERS_ALL for the loaded CPA header -- all NULL.
SELECT po_header_id, segment1, type_lookup_code,
       amount_limit, amount_released, blanket_total_amount, min_release_amount
FROM   po_headers_all
WHERE  po_header_id = 679900;
-- 679900 | 93212RT-CPA-001 | CONTRACT | AMOUNT_LIMIT NULL | AMOUNT_RELEASED NULL
--        | BLANKET_TOTAL_AMOUNT NULL | MIN_RELEASE_AMOUNT NULL

-- Header-only: no lines exist for a CPA (nothing to sum below the header).
SELECT COUNT(*) FROM po_lines_all WHERE po_header_id = 679900;   -- 0
```

**Conclusion: confirmed no money amount in Fusion for this document type.** A Contract Purchase
Agreement carries no monetary amount on this pod — every base-header amount column is NULL and
the document is header-only with no line grain. Contracts reconcile on **count only**; money
is genuinely not applicable, and this is now proven live (not assumed). The DMT pipeline also
carries no amount column for CPA, so this is consistent on both sides.

## Amount column + rationale

- **No amount column exists.** Contract Purchase Agreements are header-only with no line grain
  and no header amount field in the DMT pipeline, and the Fusion base header amount columns
  (`AMOUNT_LIMIT`, `MIN_RELEASE_AMOUNT`) are NULL for this document on this pod. Contracts
  reconcile on **count only** — money reconciliation is not applicable for this object.

## Balance check

| Source | Headers |
|---|---|
| STG total (run's record set = TFM) | 2 |
| Fusion successes (LOADED) | 1 |
| TFM errors (FAILED, real Fusion error) | 1 |
| Successes + errors | 2 |

**BALANCED on count: 1 + 1 = 2 = STG total.** Money not applicable (no amount grain).

## Gotchas

- **Shared TFM table.** `DMT_PO_HEADERS_INT_TFM_TBL` is shared by PurchaseOrders, BlanketPOs,
  and Contracts. ALWAYS filter by `DOCUMENT_TYPE_CODE`. Contracts = `'CONTRACT'`. RUN 132 has 7
  PO-family header rows total (3 STANDARD, 2 BLANKET, 2 CONTRACT).
- **Header-only object.** No line/location/distribution tiers. Do not join to the line tables
  for CPA — there are no rows, and expecting money there is wrong.
- **No money grain at all.** Unlike BlanketPOs (which carries a line AMOUNT) and STANDARD POs
  (quantity*unit_price), Contracts has no amount to sum. Report money as "not applicable,"
  never as 0 that could be mistaken for a real figure.
- **Run view OBJECT_TYPE is BU-suffixed:** `Contracts:US1 Business Unit`. Query
  `object_type LIKE 'Contracts%'`.
- **STG.SOURCE_ID is a text business reference**, not the numeric PK. Join STG↔TFM on
  `STG_SEQUENCE_ID`.
- Key path preference: `IMPORT_ESS_JOB_ID` (=10024188) → `PO_HEADERS_ALL.REQUEST_ID`. The
  captured `FUSION_PO_HEADER_ID` (679900) is the backup/cross-check. Never the prefix.
