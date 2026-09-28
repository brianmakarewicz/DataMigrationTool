# Assets (Fixed Assets) — Three-Source Reconciliation Discovery — RUN_ID 132

**Result: BALANCED.** Fusion successes (155,000) + TFM errors (1,000) = STG total (156,000).
Counts: 3 STG source records = 2 Fusion successes + 1 TFM error.

All numbers are read-only. Fusion successes were read LIVE from the demo instance
(`FA_ADDITIONS_B` / `FA_BOOKS`), never fabricated.

---

## Object / tables / grain

- **CEMLI:** `Assets` (Fixed Assets). Module Financials, FBDI `FaMassAdditions.xlsm`.
- **Header TFM:** `DMT_FA_ASSET_HDR_TFM_TBL` (one row per asset; carries `TFM_STATUS`,
  `FUSION_ASSET_ID`, `ERROR_TEXT`, `RECON_KEY`, `RUN_ID`, `WORK_QUEUE_ID`).
- **Book TFM (money):** `DMT_FA_ASSET_BOOK_TFM_TBL` — carries `COST`, one row per
  asset + `BOOK_TYPE_CODE`. **This is where the amount lives** (there is no cost column
  on the header table).
- **STG (source):** `DMT_FA_ASSET_HDR_STG_TBL` / `DMT_FA_ASSET_BOOK_STG_TBL`.
- **Grain:** the asset (one record = one asset). For RUN 132 there is exactly one book row
  per asset (`US CORP`), so asset grain and book grain coincide and the cost totals are clean.
- **Fusion base table:** `FA_ADDITIONS_B` (posted assets), joined to `FA_BOOKS` for cost.
  Confirmed from the deployed Contract-v1 data model `bip/Assets/DMT_FA_ASSET_RECON_DM.xdm`.
- **Fusion key path (recon anchor):** `ASSET_NUMBER`, prefixed. The pipeline supplies a
  prefixed asset number (`93212RT-ASSET-G1`); Fusion honors the supplied number so it
  survives to `FA_ADDITIONS_B`. `FUSION_ASSET_ID` = `FA_ADDITIONS_B.ASSET_ID`.
- **NOT the prefix as the key:** the anchor is the full prefixed `ASSET_NUMBER`, matched
  with `LIKE '93212%'` for the live read and 1:1 by value against the TFM `RECON_KEY`.

## RUN 132 facts

- Prefix `93212`, RUN_MODE `ALL`, scenario `RegressionTest2609231157`, run status
  `COMPLETED_ERRORS`.
- Assets ran as a single-book partition: parent queue row 845, child queue row
  **865** (`{"BOOK_TYPE_CODE":"US CORP"}`), WORK_STATUS DONE. Load ESS 10023891,
  Import (Prepare) ESS 10023897, Post ESS 10024014.
- 3 asset records: 2 LOADED (G1, G2), 1 FAILED (BAD1), 0 UNACCOUNTED.

## Amount column + rationale

**Amount = asset COST** (`DMT_FA_ASSET_BOOK_TFM_TBL.COST` on the DMT side;
`FA_BOOKS.COST` on the Fusion side). Cost is the money value of a fixed asset and is
carried on the book row, not the header. In RUN 132 each asset has exactly one book row
(`US CORP`), so summing book cost equals summing per-asset cost with no double count.

---

## 1. STG total (count + money) — 3 records, 156,000

STG carries no RUN_ID. The run's record set is the TFM rows for RUN 132; the STG source
rows behind them are matched by stripping the prefix from the TFM asset number
(`SUBSTR(asset_number, LENGTH(prefix)+1)`) and joining to the TRANSFORMED STG rows.

```sql
SELECT COUNT(*) AS stg_cnt, SUM(s.cost) AS stg_cost
FROM   dmt_fa_asset_book_tfm_tbl t
JOIN   dmt_fa_asset_book_stg_tbl s
  ON   s.asset_number   = SUBSTR(t.asset_number, LENGTH('93212') + 1)
 AND   s.book_type_code = t.book_type_code
 AND   s.stg_status     = 'TRANSFORMED'
WHERE  t.run_id = 132;
```

Result: `STG_CNT = 3`, `STG_COST = 156000`
(RT-ASSET-G1 120,000 + RT-ASSET-G2 35,000 + RT-ASSET-BAD1 1,000).

## 2. TFM errors (count + money, real ERROR_TEXT) — 1 record, 1,000

```sql
SELECT t.asset_number, t.book_type_code, t.cost, t.tfm_status,
       DBMS_LOB.SUBSTR(t.error_text, 3000, 1) AS error_text
FROM   dmt_fa_asset_book_tfm_tbl t
WHERE  t.run_id = 132
AND    t.tfm_status = 'FAILED';
```

Result: 1 row.
- `93212RT-ASSET-BAD1`, US CORP, COST 1,000, TFM_STATUS FAILED.
- ERROR_TEXT (real Fusion rejection):
  `[FUSION_ERROR]The parent record has the following Fusion error: [FUSION_ERROR] [ASSET] You must enter a valid expense account ID. The current expense acco...`

TFM error total: **count 1, money 1,000.**

## 3. Fusion successes (count + money, LIVE FROM FUSION) — 2 records, 155,000

Read live from the demo instance via BIP (`scripts/fusion_bip_query.py --cred fin_impl`),
against the base table `FA_ADDITIONS_B` joined to `FA_BOOKS` for cost, matched by the
prefixed asset number.

```sql
SELECT a.asset_number, a.asset_id, bk.book_type_code, bk.cost
FROM   fa_additions_b a
JOIN   fa_books bk
  ON   bk.asset_id = a.asset_id
 AND   bk.transaction_header_id_out IS NULL      -- current (active) book row
WHERE  a.asset_number LIKE '93212%'
ORDER BY a.asset_number;
```

Live result (from Fusion, 2026-09-27):

| ASSET_NUMBER      | ASSET_ID (FUSION_ID) | BOOK_TYPE_CODE | COST    |
|-------------------|----------------------|----------------|---------|
| 93212RT-ASSET-G1  | 574152               | US CORP        | 120000  |
| 93212RT-ASSET-G2  | 574153               | US CORP        | 35000   |

Fusion success total: **count 2, money 155,000.** `93212RT-ASSET-BAD1` is absent from
`FA_ADDITIONS_B` (correctly rejected). The Fusion ASSET_IDs match the `FUSION_ASSET_ID`
stamped on the LOADED TFM rows (574152, 574153).

## Balance check

| Source                | Count | Money   |
|-----------------------|-------|---------|
| STG total             | 3     | 156,000 |
| Fusion successes (live)| 2    | 155,000 |
| TFM errors            | 1     | 1,000   |
| Fusion + TFM errors   | 3     | 156,000 |

Fusion successes + TFM errors = STG total, on **both count and money**. **BALANCED**,
0 unaccounted.

## Production key resolution

**BATCH-KEY-FOUND.** The prefix (`ASSET_NUMBER LIKE '93212%'`) is a test-only anchor and is
forbidden in production. A real, production-valid batch key round-trips: the DMT **load ESS
request id** lands on `FA_MASS_ADDITIONS.LOAD_REQUEST_ID`, and the posted asset's base-table id
lands on `FA_MASS_ADDITIONS.ASSET_ID`.

**Resolved production key: `FA_MASS_ADDITIONS.LOAD_REQUEST_ID = <LOAD_ESS_JOB_ID>`**, filtered to
`POSTING_STATUS = 'POSTED'` for the successes. For RUN 132 the value is **`10023891`** — this is
`DMT_WORK_QUEUE_TBL.LOAD_ESS_JOB_ID` for the Assets child (QUEUE_ID 865, RUN_ID 132). Source of the
value (read-only, on the DMT DB):

```sql
SELECT load_ess_job_id, import_ess_job_id, postrun_ess_job_id
FROM   dmt_work_queue_tbl
WHERE  run_id = 132 AND cemli_code = 'Assets' AND parent_queue_id IS NOT NULL;
-- LOAD_ESS_JOB_ID = 10023891, IMPORT_ESS_JOB_ID = 10023897, POSTRUN_ESS_JOB_ID = 10024014
```

**Which Fusion column carries what (verified live, 2026-09-27):**

| DMT value (queue 865)          | Fusion column                         | Value     |
|--------------------------------|---------------------------------------|-----------|
| LOAD_ESS_JOB_ID   = 10023891   | `FA_MASS_ADDITIONS.LOAD_REQUEST_ID`   | 10023891  |
| POSTRUN_ESS_JOB_ID = 10024014  | `FA_MASS_ADDITIONS.REQUEST_ID`        | 10024014  |
| POSTRUN_ESS_JOB_ID = 10024014  | `FA_MASS_ADDITIONS.POST_BATCH_ID` (posted rows only) | 10024014  |
| (posted asset id)              | `FA_MASS_ADDITIONS.ASSET_ID`          | 574152 / 574153 |

`POSTING_STATUS` is `POSTED` for the 2 successes and `ERROR` for BAD1. `ASSET_ID` is populated on
the posted rows (= `FA_ADDITIONS_B.ASSET_ID`) and NULL on the ERROR row.

**Live proof — successes by batch key, no prefix** (`python scripts/fusion_bip_query.py --cred fin_impl`):

```sql
SELECT a.asset_id, a.asset_number, bk.book_type_code, bk.cost
FROM   fa_mass_additions ma
JOIN   fa_additions_b a  ON a.asset_id = ma.asset_id
JOIN   fa_books bk       ON bk.asset_id = a.asset_id
                       AND bk.transaction_header_id_out IS NULL
WHERE  ma.load_request_id = 10023891
AND    ma.posting_status  = 'POSTED'
ORDER BY a.asset_number;
```

Live result (2026-09-27): exactly 2 rows — `574152 / 93212RT-ASSET-G1 / US CORP / 120000` and
`574153 / 93212RT-ASSET-G2 / US CORP / 35000`. Rollup `COUNT(*) = 2`, `SUM(FA_BOOKS.COST) = 155000`.
`SELECT COUNT(*) FROM fa_mass_additions WHERE load_request_id = 10023891` returns 3 across a single
asset-number prefix — the key is isolated to this run and does not bleed into neighbor test loads.

**Notes / corrections:**
- The old object README claim that "PostMassAdditions purges FA_MASS_ADDITIONS after posting" does
  NOT hold on this demo instance — the interface rows (including the request/batch columns) survive,
  which is what makes this batch key usable. Do not rely on absence-from-interface as a signal here.
- `FA_ADDITIONS_B` and `FA_BOOKS` carry **no** REQUEST_ID / LOAD_REQUEST_ID / BATCH column, and
  `FA_ADDITIONS_B.ATTRIBUTE1/ATTRIBUTE2` are empty — we stamp nothing onto the base row itself. The
  request-id round-trip lives only on `FA_MASS_ADDITIONS`, so the base-table success read must join
  through `FA_MASS_ADDITIONS.ASSET_ID` (join `ma.asset_id = a.asset_id`, NOT `ma.mass_addition_id`).
- **Fallback (only if the interface is ever purged):** query `FA_ADDITIONS_B` by the exact
  `FUSION_ASSET_ID` list DMT already captured on the LOADED header TFM rows
  (`DMT_FA_ASSET_HDR_TFM_TBL.FUSION_ASSET_ID` = 574152, 574153 for RUN 132). Production-valid but
  it is a captured-id list, not a batch key.

## Gotchas

- **Money is on the book table, not the header.** `DMT_FA_ASSET_HDR_TFM_TBL` has no cost
  column; sum `COST` from `DMT_FA_ASSET_BOOK_TFM_TBL` (and `FA_BOOKS.COST` on Fusion).
- **Prefix is applied at transform, not at stage.** STG `ASSET_NUMBER` is un-prefixed
  (`RT-ASSET-G1`); TFM `ASSET_NUMBER` / `RECON_KEY` carry the prefix (`93212RT-ASSET-G1`).
  Scope STG to a run by stripping the prefix off the TFM key — STG's own `SCENARIO_ID`
  (21/61 here) is the write-once seed id, **not** the run id, so do not scope STG by run id
  or by `LIKE '93212%'` on the STG table (returns 0 rows).
- **All-or-nothing at Post, per-row at SqlLdr (from the object README).** For RUN 132 this
  did not force an all-or-nothing outcome: the good rows posted individually and BAD1 was
  rejected per-record at PrepareMassAdditions with a real expense-account error. If a whole
  book ever fails at Post, expect the entire book's assets to come back unaccounted together
  rather than one bad row — check that case before assuming per-row semantics.
- **`transaction_header_id_out IS NULL`** selects the current (active) `FA_BOOKS` row. An
  asset can carry a corporate book plus tax books; here only `US CORP` exists, but the
  recon DM deliberately uses a `ROWNUM=1` scalar subquery for the book label to keep the
  base tier one row per asset (avoids fanning the keyset and dropping rows at page
  boundaries).
- **WORK_QUEUE_ID 865** identifies the Assets child (US CORP partition) of RUN 132; the
  Fusion import request id is available on `DMT_WORK_QUEUE_TBL` (IMPORT ESS 10023897,
  Post ESS 10024014) if an ESS-request-scoped read is ever needed. For the success read
  the prefixed `ASSET_NUMBER` is the reliable anchor because Post purges the interface.
```
