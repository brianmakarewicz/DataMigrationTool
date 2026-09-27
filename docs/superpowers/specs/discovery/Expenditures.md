# Expenditures — Three-Source Reconciliation Discovery (RUN_ID 132)

Read-only proof. RUN 132 result: **2 LOADED, 6 FAILED**. No DB objects modified.

## Object / tables / grain
- **Object:** Expenditures / project costs (ONE FBDI zip `PjcTxnXfaceStageAll.csv`, ESS job
  "Import and Process Cost Transactions" — the NON-parallel `onestop,ImportAndProcessTxnsJob`, 10-arg).
- **TFM table:** `DMT_PJC_EXPENDITURES_TFM_TBL` (has `RUN_ID`, `WORK_QUEUE_ID`, `RECON_KEY`,
  `TFM_STATUS`, `FUSION_EXPENDITURE_ITEM_ID`, `QUANTITY`, `DENOM_RAW_COST`, `ERROR_TEXT`).
- **Fusion base table:** `PJC_EXP_ITEMS_ALL`.
- **Fusion key:** `FUSION_EXPENDITURE_ITEM_ID` = `EXPENDITURE_ITEM_ID`; run selector = prefix on
  `ORIG_TRANSACTION_REFERENCE` (the transform stamps the prefix onto it and it survives verbatim on base).
- **Grain:** one row per cost transaction. **Money = expenditure amount** (`DENOM_RAW_COST`), plus `QUANTITY`.
- **Run prefix:** 93212. This object DOES populate `WORK_QUEUE_ID` (values 866, 867 — the two
  partitions by transaction source/document). **Import ESS job ids:** 10023994 (queue 867), 10024001 (queue 866).

## STG total (count + money)
STG has no RUN_ID and holds duplicate seed rows; use the TFM run set.
```sql
SELECT COUNT(*) AS stg_total, SUM(denom_raw_cost) AS stg_money
FROM   dmt_pjc_expenditures_tfm_tbl
WHERE  run_id = 132;
```
**Result:** stg_total = **8**, stg_money = **12,499.99** (LOADED $4,000.00 + FAILED $8,499.99).

## TFM errors (count + money + real ERROR_TEXT)
```sql
SELECT recon_key, tfm_status, denom_raw_cost, error_text
FROM   dmt_pjc_expenditures_tfm_tbl
WHERE  run_id = 132 AND tfm_status = 'FAILED';
```
**Result:** 6 FAILED, money $8,499.99. All carry real Fusion cost-import errors:
- `93212RT-EXP-BAD1`   → `[FUSION_ERROR] PJC_EXP_TYPE_INVALID`
- `93212RT-EXP-E2DATE` → `[FUSION_ERROR] PJC_EX_PROJECT_DATE - The expenditure item date is outside the project dates...`
- `93212RT-EXP-E3RATE` → `[FUSION_ERROR] PJF_PRICE_NO_PERSON_RATE - No rate was found for the person.`
- `93212RT-EXP-E4DOC`  → `[FUSION_ERROR] PJC_TXN_DOC_NAME_IS_INVALID`
- `93212RT-EXP-E5ORG`  → `[FUSION_ERROR] PJC_TXN_EXPORG_NAME_IS_INVALID`
- `93212RT-EXP-E6AWARD`→ `[FUSION_ERROR] PJC_AWARD_NOT_PROVIDED`

## Fusion successes (count; LIVE FROM FUSION)
Key path: prefixed `ORIG_TRANSACTION_REFERENCE` (round-trips verbatim onto the base row).
FUSION_ID = `EXPENDITURE_ITEM_ID`.
```sql
-- via scripts/fusion_bip_query.py --cred fin_impl
SELECT expenditure_item_id        AS EXPENDITURE_ITEM_ID,
       orig_transaction_reference AS ORIG_TRANSACTION_REFERENCE,
       denom_raw_cost             AS DENOM_RAW_COST
FROM   pjc_exp_items_all
WHERE  orig_transaction_reference LIKE '93212%'
ORDER BY orig_transaction_reference;
```
**Result (LIVE, confirmed):** 2 rows.
- 756752 / 93212RT-EXP-PCS10080-2025-04-17 / DENOM_RAW_COST **2560** → matches TFM LOADED FID 756752.
- 756751 / 93212RT-EXP-PCS10080-2025-04-18 / DENOM_RAW_COST **1280** → matches TFM LOADED FID 756751.

Both LOADED TFM ids exist in the Fusion base table with the exact prefixed reference. Count balances.

## Amount column + rationale
`DENOM_RAW_COST` is the expenditure amount, but it is a **submitted** figure that Fusion RECOMPUTES on
import: the two LOADED rows were submitted at 2500 + 1500 = **4000**, but Fusion recorded 2560 + 1280 =
**3840** (cost is recomputed from `QUANTITY` × the person/rate schedule at import). So:
- Use `DENOM_RAW_COST` for STG/TFM-error money (submitted value).
- **The Expenditures money does NOT round-trip** — the base-table amount differs from the submitted amount.
  Therefore balance Expenditures on **COUNT** (money is submitted-only; the Fusion base amount is a
  recomputed, expected-to-differ value, not a reconciliation figure). `QUANTITY` (hours: 16 + 8) is the
  durable submitted quantity if a quantity check is wanted.

## Balance check
Fusion successes (2) + TFM errors (6) = 8 = STG/run total (8). **BALANCED on count.**
Money is not balanced across sources by design (Fusion recomputes raw cost) — flagged, not a defect.

## Gotchas
- `WORK_QUEUE_ID` (866/867) reflects the two source/document partitions, not a Fusion id. It does NOT
  round-trip into Fusion. The durable Fusion key is prefixed `ORIG_TRANSACTION_REFERENCE`; the captured
  FUSION_ID is `EXPENDITURE_ITEM_ID`. Import ESS job ids are in `DMT_WORK_QUEUE_TBL.IMPORT_ESS_JOB_ID`.
- Base-table `DENOM_RAW_COST` ≠ submitted `DENOM_RAW_COST` (Fusion recompute) — do not treat a money
  variance here as an accounting error.
- Cost interface `PJC_TXN_XFACE_STAGE_ALL` has no error-text column and `PJC_TXN_ERRORS` carries no
  `ORIG_TRANSACTION_REFERENCE`, so the real per-row message comes from the import report XML → TFM.ERROR_TEXT.
- STG has no RUN_ID and holds duplicate seed rows — use the TFM run set.
