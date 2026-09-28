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

## Production key resolution
**BATCH-KEY-FOUND** — the durable, production-valid batch key is the **import ESS request id**,
which DMT already captures. Every loaded row on the Fusion base table carries `REQUEST_ID` equal
to the import job id, and DMT stores that same id in `DMT_WORK_QUEUE_TBL.IMPORT_ESS_JOB_ID`.

- The earlier `ORIG_TRANSACTION_REFERENCE LIKE '93212%'` match used the test PREFIX (forbidden).
- The prior "WORK_QUEUE_ID 866/867" candidate is only a source-partition id. It DOES stamp into
  Fusion as `USER_BATCH_NAME` (base rows show `USER_BATCH_NAME = 867`), but that is the DMT queue
  id, not a durable production key across reruns. Do not key on it.
- The right key is `PJC_EXP_ITEMS_ALL.REQUEST_ID` = the import ESS job id. For RUN_ID 132 the two
  loaded rows sit on work queue 867, whose `IMPORT_ESS_JOB_ID` is **10023994**, and both base rows
  carry `REQUEST_ID = 10023994`. It round-trips exactly.

DMT-side key (Docker DMT DB):
```sql
-- the import ESS request id DMT captured for the queue that holds the loaded rows
SELECT queue_id, import_ess_job_id
FROM   dmt_work_queue_tbl
WHERE  run_id = 132 AND cemli_code = 'Expenditures' AND import_ess_job_id IS NOT NULL;
-- 866 -> 10024001 ; 867 -> 10023994  (RUN 132 loaded both rows under queue 867)
```

Fusion-side proof (LIVE, via scripts/fusion_bip_query.py --cred fin_impl):
```sql
SELECT expenditure_item_id, orig_transaction_reference, request_id, user_batch_name
FROM   pjc_exp_items_all
WHERE  request_id = 10023994
ORDER  BY expenditure_item_id;
-- 756751 / 93212RT-EXP-PCS10080-2025-04-18 / 10023994 / 867
-- 756752 / 93212RT-EXP-PCS10080-2025-04-17 / 10023994 / 867
```
Count check (LIVE): `SELECT COUNT(*) FROM pjc_exp_items_all WHERE request_id = 10023994` returns
**2** — exactly the two LOADED items (756752, 756751). BATCH-KEY-FOUND, no prefix, no fallback needed.

Captured-id fallback (if a run ever splits loaded rows across multiple import jobs, key by the
exact captured FUSION_EXPENDITURE_ITEM_ID list instead — always available on LOADED TFM rows):
```sql
SELECT ... FROM pjc_exp_items_all
WHERE  expenditure_item_id IN ( /* DMT_..._TFM_TBL.FUSION_EXPENDITURE_ITEM_ID for LOADED rows */ );
```

## Fusion money column
**Chosen column: `DENOM_RAW_COST`** — the loaded expenditure amount as Fusion recorded it. We ALWAYS
report Fusion's actual value, so the report shows Fusion's recomputed cost, not the submitted STG figure.

LIVE sum for RUN 132's 2 loaded items (via the batch key `request_id = 10023994`):
```sql
SELECT COUNT(*) AS cnt, SUM(denom_raw_cost) AS fusion_money, SUM(quantity) AS fusion_qty
FROM   pjc_exp_items_all
WHERE  request_id = 10023994;
-- cnt = 2 ; fusion_money = 3840 ; fusion_qty = 24
```
Per item (LIVE): 756752 = 2560 (16 hrs x 160/hr), 756751 = 1280 (8 hrs x 160/hr). Sum = **3840.00**.

Why DENOM_RAW_COST and why it differs from STG: Fusion recomputes cost at import as
`QUANTITY x person raw_cost_rate` (160/hr on this pod), overriding the submitted `DENOM_RAW_COST`.
STG submitted 2500 + 1500 = 4000; Fusion recorded 2560 + 1280 = 3840. On these rows every Fusion cost
column agrees (`DENOM_RAW_COST = PROJECT_RAW_COST = PROJFUNC_RAW_COST = DENOM_BURDENED_COST = 3840`,
burden multiplier 1.0), so `DENOM_RAW_COST` is unambiguously the right success amount to report.
**The report shows Fusion's 3840, not STG's 4000.** That 4000 vs 3840 gap is a real, meaningful
variance (submitted-vs-recomputed cost), not a reconciliation defect — surface it, do not hide it.
(`raw_cost` does NOT exist on this table — only `denom_raw_cost` and the project/projfunc/denom-burdened
variants; do not reference `raw_cost`.)

## Amount column + rationale
`DENOM_RAW_COST` is the expenditure amount, but it is a **submitted** figure that Fusion RECOMPUTES on
import: the two LOADED rows were submitted at 2500 + 1500 = **4000**, but Fusion recorded 2560 + 1280 =
**3840** (cost is recomputed from `QUANTITY` × the person/rate schedule at import). So:
- Use `DENOM_RAW_COST` for STG/TFM-error money (submitted value).
- **SUPERSEDED (see "Fusion money column" above):** the base amount differs from submitted BY DESIGN
  (Fusion recomputes cost = quantity x rate). We report Fusion's actual `DENOM_RAW_COST` (live 3840)
  as the success amount and show the STG-vs-Fusion gap (4000 vs 3840) as a real variance. Count still
  balances (2 loaded + 6 failed = 8); money is reported from Fusion, not asserted to equal STG.

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
