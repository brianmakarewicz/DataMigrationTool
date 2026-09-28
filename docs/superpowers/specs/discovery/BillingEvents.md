# BillingEvents — Three-Source Reconciliation Discovery (RUN_ID 132)

Read-only proof. RUN 132 result: **2 LOADED, 1 FAILED**. No DB objects modified.

## Object / tables / grain
- **Object:** BillingEvents / project billing (ONE FBDI zip `PjbBillingEventsXface.csv`, ESS job
  `ImportBillingEventJob`).
- **TFM table:** `DMT_PJB_BILL_EVENTS_TFM_TBL` (has `RUN_ID`, `RECON_KEY`, `TFM_STATUS`,
  `FUSION_EVENT_ID`, `BILL_TRNS_AMOUNT`, `SOURCEREF`, `ERROR_TEXT`).
- **Fusion base table:** `PJB_BILLING_EVENTS`.
- **Fusion key:** `FUSION_EVENT_ID` = `EVENT_ID`; run selector = prefix on `SOURCEREF` (transform stamps
  the prefix onto it; survives verbatim on base).
- **Grain:** one row per billing event. **Money = event/bill amount** (`BILL_TRNS_AMOUNT`).
- **Run prefix:** 93212. **Import ESS job id:** 10023972 (queue_id 847).

## STG total (count + money)
STG has no RUN_ID and holds duplicate seed rows; use the TFM run set.
```sql
SELECT COUNT(*) AS stg_total, SUM(bill_trns_amount) AS stg_money
FROM   dmt_pjb_bill_events_tfm_tbl
WHERE  run_id = 132;
```
**Result:** stg_total = **3**, stg_money = **1,002.00** (RECON_KEYs: RT-BE-G1, RT-BE-G2, RT-BE-BAD1).

## TFM errors (count + money + real ERROR_TEXT)
```sql
SELECT recon_key, tfm_status, bill_trns_amount, error_text
FROM   dmt_pjb_bill_events_tfm_tbl
WHERE  run_id = 132 AND tfm_status = 'FAILED';
```
**Result:** 1 FAILED, money $1,000.00.
- `93212RT-BE-BAD1` → `[FUSION_ERROR] FND_CMN_CMPLT_FLDS: You must complete the required fields.`
  (real Fusion required-field rejection — the intended BAD row).

## Fusion successes (count + money; LIVE FROM FUSION)
Key path: prefixed `SOURCEREF` (round-trips verbatim onto the base row). FUSION_ID = `EVENT_ID`.
```sql
-- via scripts/fusion_bip_query.py --cred fin_impl
SELECT event_id         AS EVENT_ID,
       sourceref        AS SOURCEREF,
       bill_trns_amount AS BILL_TRNS_AMOUNT
FROM   pjb_billing_events
WHERE  sourceref LIKE '93212%'
ORDER BY sourceref;
```
**Result (LIVE, confirmed):** 2 rows.
- 100002648903286 / 93212RT-BE-G1 / BILL_TRNS_AMOUNT **1** → matches TFM LOADED FID 100002648903286.
- 100002648903292 / 93212RT-BE-G2 / BILL_TRNS_AMOUNT **1** → matches TFM LOADED FID 100002648903292.

Fusion success money = $2.00 = TFM LOADED money ($1 + $1). Money round-trips exactly here.

## Amount column + rationale
`BILL_TRNS_AMOUNT` is the billing-event transaction amount, at the event grain, carried on TFM and
persisted verbatim on the base row. It round-trips (unlike Expenditures), so it balances on money.
The two GOOD rows are deliberately loaded at $1 each (per the object README, copy-a-known-good-event
strategy re-submitted for a nominal amount).

## Balance check
Fusion successes (2, $2.00) + TFM errors (1, $1,000.00) = 3 rows / $1,002.00 = STG/run total.
**BALANCED on count and money.**

## Gotchas
- Interface table `PJB_BILLING_EVENTS_INT` is ALWAYS purged after import (MOS 2534525.1) and has no
  error-text column, so the interface tier normally returns zero rows; the real per-row message comes
  from the `ImportBillingEventReportJob` output XML (wire marker `#IMPORT_REPORT#`) → TFM.ERROR_TEXT.
- `SOURCEREF` (prefixed) is the durable base key; base `REQUEST_ID` is present but the prefix is the
  reliable selector. Base `ATTRIBUTE1` (DMT_REFERENCE) is NULL until the DFF segment is deployed — honest.
- STG has no RUN_ID and holds duplicate seed rows — use the TFM run set.
