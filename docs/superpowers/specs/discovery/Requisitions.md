# Requisitions — three-source reconciliation discovery (RUN_ID = 132)

Read-only proof that, for the Requisitions object in DMT run 132, the records that
succeeded in Fusion plus the records Fusion rejected add up exactly to what we staged.
No DB object, pipeline, or DMT table was modified. All Fusion numbers are read live.

## Result (headline)

| Source | Records | Money (USD) |
|---|---:|---:|
| STG total (the run's record set) | 5 | 1190 |
| Fusion successes (LIVE from Fusion base tables) | 2 | 490 |
| TFM errors (FAILED with real ERROR_TEXT) | 3 | 700 |
| **Fusion successes + TFM errors** | **5** | **1190** |

**BALANCED** — 2 + 3 = 5 records, and 490 + 700 = 1190 money. Exact, zero variance,
zero unaccounted.

## Object / tables / grain

- CEMLI code: `Requisitions`. Auth user for the import: `calvin.roth`.
- One FBDI zip carrying three record types: headers, lines, distributions.
- DMT tables (this run reports at the **header grain** — one accounted record per requisition header):
  - Header STG `DMT_POR_REQ_HEADERS_STG_TBL`, TFM `DMT_POR_REQ_HEADERS_TFM_TBL`
    (status column `TFM_STATUS`, Fusion id column `FUSION_REQUISITION_HEADER_ID`,
    business key `REQUISITION_NUMBER` / `RECON_KEY`, batch link `INTERFACE_HEADER_KEY`).
  - Line STG `DMT_POR_REQ_LINES_STG_TBL`, TFM `DMT_POR_REQ_LINES_TFM_TBL`
    (money columns `QUANTITY`, `CURRENCY_UNIT_PRICE`, `CURRENCY_AMOUNT`;
    header link `INTERFACE_HEADER_KEY`; own key `INTERFACE_LINE_KEY`).
  - Dist STG/TFM `DMT_POR_REQ_DISTS_{STG,TFM}_TBL` (not needed for header-grain money).
- `DMT_RUN_RECORDS_V` reports Requisitions from the **header** TFM table only
  (OBJECT_TYPE = 'Requisitions', FUSION_ID = FUSION_REQUISITION_HEADER_ID). So the
  run's record set = the 5 header TFM rows for RUN_ID 132.
- Fusion base tables (confirmed from `bip/Requisitions/DMT_REQ_RECON_DM.xdm`):
  - Headers: `POR_REQUISITION_HEADERS_ALL`, key `REQUISITION_HEADER_ID`.
  - Lines:   `POR_REQUISITION_LINES_ALL`, key `REQUISITION_LINE_ID`; carries our
             stamped `INTERFACE_LINE_KEY` verbatim (the read-back key).
  - Dists:   `POR_REQ_DISTRIBUTIONS_ALL`.

## Amount column + rationale

Requisition headers carry **no** amount column (verified in the STG/TFM header DDL).
The money lives on the **lines**. Each run-132 header has exactly one line. The amount
basis is **QUANTITY × CURRENCY_UNIT_PRICE** (extended line amount):

- `CURRENCY_AMOUNT` is NULL on every run-132 line in DMT, and both `currency_amount`
  and `amount` are NULL on the Fusion base line too, so an amount cannot come from
  those columns. Quantity × unit_price is the only populated, consistent basis and it
  matches on all three sources.

Header money = SUM over that header's lines of `NVL(CURRENCY_AMOUNT, QUANTITY*CURRENCY_UNIT_PRICE)`.

Per-header money (run 132):

| Requisition | Status | Qty × Price | Amount |
|---|---|---|---:|
| 93212RT-REQ-001  | LOADED | 10 × 25 | 250 |
| 93212RT-REQ-002  | LOADED |  8 × 30 | 240 |
| 93212RT-REQ-BADDIST | FAILED | 2 × 75 | 150 |
| 93212RT-REQ-BADHDR  | FAILED | 5 × 50 | 250 |
| 93212RT-REQ-BADLINE | FAILED | 3 × 100 | 300 |

## Key path from DMT to Fusion (how the loaded rows are found LIVE)

- The two LOADED header TFM rows carry the captured Fusion id in
  `FUSION_REQUISITION_HEADER_ID`: **136030** (REQ-001) and **136033** (REQ-002).
  These are the live handles; NEVER the prefix (93212) or the work-queue id.
- Each loaded line's DMT `INTERFACE_LINE_KEY` (`132_RQLN_<seq>`) is persisted verbatim
  on `POR_REQUISITION_LINES_ALL.INTERFACE_LINE_KEY`, so the line round-trips too.
- Work-queue note: this run has **two** batches (`DMT_WORK_QUEUE_TBL.QUEUE_ID` 868 and
  869), each with its own import ESS job (`IMPORT_ESS_JOB_ID` 10024235 and 10024228).
  A single import ess id therefore does not select the whole run — the reliable
  run-scoped selectors are the captured FUSION_REQUISITION_HEADER_ID list and the
  `132_RQLN_%` interface-line-key prefix. (The prompt's "WORK_QUEUE_ID 869" is only one
  of the two batches.)

## STG total query + result

STG has no RUN_ID. The staged data was seeded twice (a NEW copy still sits alongside
the run-132 copy), so joining STG by the raw `INTERFACE_HEADER_KEY` double-counts. The
correct run-scoped anchor is the STG_SEQUENCE_ID that this run's TFM rows point to.

```sql
-- Record count = the run's header record set (5)
SELECT COUNT(*) AS hdr_count
FROM   DMT_POR_REQ_HEADERS_STG_TBL s
WHERE  s.stg_sequence_id IN (
         SELECT stg_sequence_id FROM DMT_POR_REQ_HEADERS_TFM_TBL WHERE run_id = 132);

-- Money = SUM over the exact STG lines this run transformed
SELECT COUNT(*) AS line_count,
       SUM(NVL(ls.currency_amount, ls.quantity * ls.currency_unit_price)) AS stg_total_amount
FROM   DMT_POR_REQ_LINES_STG_TBL ls
WHERE  ls.stg_sequence_id IN (
         SELECT stg_sequence_id FROM DMT_POR_REQ_LINES_TFM_TBL WHERE run_id = 132);
```

Result: `hdr_count = 5`; `line_count = 5`, `stg_total_amount = 1190`.

## TFM-error query + result (real ERROR_TEXT confirmed)

```sql
SELECT h.requisition_number,
       h.tfm_status,
       SUM(NVL(l.currency_amount, l.quantity * l.currency_unit_price)) AS amount,
       DBMS_LOB.SUBSTR(h.error_text, 300, 1) AS error_text
FROM   DMT_POR_REQ_HEADERS_TFM_TBL h
LEFT   JOIN DMT_POR_REQ_LINES_TFM_TBL l
       ON l.run_id = h.run_id
      AND l.interface_header_key = h.interface_header_key
WHERE  h.run_id = 132
AND    h.tfm_status = 'FAILED'
GROUP  BY h.requisition_number, h.tfm_status,
          DBMS_LOB.SUBSTR(h.error_text, 300, 1)
ORDER  BY h.requisition_number;
```

Result — 3 FAILED headers, money 150 + 250 + 300 = **700**, each with real ERROR_TEXT:

- `93212RT-REQ-BADDIST` — 150 — `[FUSION_ERROR] [HDR] Rejected by Requisition Import (process_flag=FAILED; no error row written -- e.g. header rejected pre-validation).`
- `93212RT-REQ-BADLINE` — 300 — same shape (header rejected because its child line/dist failed pre-validation, no error row written).
- `93212RT-REQ-BADHDR`  — 250 — `[FUSION_ERROR] [HDR] PREPARER_EMAIL_ADDR=NONEXISTENT_USER@fake.com: The preparer email isn't valid. It must be a valid email account associated with a worker with an active work relationship. | APPROV...`

The BADHDR message is a genuine Fusion rejection string. The two "no error row written"
messages are the honest header-tier result documented in `objects/Requisitions/README.md`
and the recon data model: when a child line/dist is invalid, Fusion rejects the header
with `process_flag = FAILED` and writes no `por_req_import_errors` header row, so the
data model substitutes this explicit rejection text rather than inventing a verdict.

## Fusion success query + result (LIVE from Fusion)

Run read-only against the live demo instance:
`python scripts/fusion_bip_query.py --cred fin_impl`

```sql
SELECT h.requisition_header_id  AS hdrid,
       h.requisition_number     AS reqnum,
       h.document_status        AS docstatus,
       l.interface_line_key     AS linekey,
       l.quantity               AS qty,
       l.unit_price             AS price
FROM   por_requisition_headers_all h
JOIN   por_requisition_lines_all   l
       ON l.requisition_header_id = h.requisition_header_id
WHERE  h.requisition_header_id IN (136030, 136033);
```

Live result (both present, both APPROVED, DMT line key round-tripped):

| HDRID | REQNUM | DOCSTATUS | LINEKEY | QTY | PRICE | Amount |
|---|---|---|---|---:|---:|---:|
| 136030 | 93212RT-REQ-001 | APPROVED | 132_RQLN_100000147 | 10 | 25 | 250 |
| 136033 | 93212RT-REQ-002 | APPROVED | 132_RQLN_100000149 |  8 | 30 | 240 |

Fusion successes: **2 records, money 490**. (`currency_amount` / `amount` are NULL on
the base line, so amount = quantity × unit_price, matching the STG source exactly.)

A run-scoped alternative selector that does not need the id list:
`WHERE l.interface_line_key LIKE '132\_RQLN\_%' ESCAPE '\'` on `por_requisition_lines_all`.

## Balance check

```
Fusion successes  (2, 490) + TFM errors (3, 700) = 5 records, 1190
STG total                                        = 5 records, 1190
-> BALANCED (0 record variance, 0 money variance, 0 unaccounted)
```

## Gotchas

- **STG has no RUN_ID and the seed data is staged more than once.** Joining STG by the
  raw `INTERFACE_HEADER_KEY`/`INTERFACE_LINE_KEY` double-counts (returned 10 lines / 2380
  here). Always scope STG through the run's TFM `STG_SEQUENCE_ID` pointers.
- **No money column on the header.** Amount must be rolled up from the lines as
  QUANTITY × CURRENCY_UNIT_PRICE; `CURRENCY_AMOUNT` is NULL in this run.
- **Header grain only.** `DMT_RUN_RECORDS_V` and this reconciliation account Requisitions
  at the header. Lines/dists are the money detail and the Fusion round-trip proof, not
  separate accounted records here.
- **Two batches, two import ESS ids.** Do not select the run by a single
  `IMPORT_ESS_JOB_ID`. Use the captured `FUSION_REQUISITION_HEADER_ID` list or the
  `132_RQLN_%` line-key prefix.
- **Header-tier FAILED rows may lack a Fusion error row.** When the rejection is on a
  child line/dist, Fusion writes no header error row; the honest recorded text says so
  explicitly rather than fabricating a per-row Fusion message. This is expected, not a gap.
- **BADHDR carries a true Fusion rejection** (invalid preparer email) — proof the FAILED
  path surfaces real Fusion errors, not placeholders.
```
