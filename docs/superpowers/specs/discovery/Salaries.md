# Salaries — three-source reconciliation (RUN_ID 132)

Read-only discovery. Local Docker DMT DB (`dmt_owner@//localhost:1523/FREEPDB1`); Fusion reads
via `scripts/fusion_bip_query.py --cred hcm_impl`. RUN 132 prefix = **93212**.

## Object / tables / grain
- **Loader:** HDL (Salary.dat). No FBDI import request id; no `IMPORT_ESS_JOB_ID`.
- **TFM table:** `DMT_SALARY_TFM_TBL` (`RUN_ID`, `RECON_KEY`, `TFM_STATUS`, `SALARY_AMOUNT`, `CURRENCY_CODE`, `FUSION_SALARY_ID`, `ERROR_TEXT`).
- **STG table:** `DMT_SALARY_STG_TBL` (no `RUN_ID`; joined via `TFM.STG_SEQUENCE_ID`).
- **Base table / id:** `CMP_SALARY.SALARY_ID`.
- **Grain:** one record = one salary assignment.

## STG total (count + money)
```sql
SELECT COUNT(*) AS stg_total, SUM(TO_NUMBER(SALARY_AMOUNT)) AS stg_amount
FROM   DMT_SALARY_STG_TBL s
WHERE  s.STG_SEQUENCE_ID IN (SELECT STG_SEQUENCE_ID FROM DMT_SALARY_TFM_TBL WHERE RUN_ID = 132);
```
**Result: 2 rows, total 155,000.** (75,000 GOOD + 80,000 BAD.)

## TFM errors (count + money + real ERROR_TEXT)
```sql
SELECT TFM_STATUS, RECON_KEY, SALARY_AMOUNT, FUSION_SALARY_ID,
       DBMS_LOB.SUBSTR(ERROR_TEXT,1000,1) AS error_text
FROM   DMT_SALARY_TFM_TBL
WHERE  RUN_ID = 132 AND TFM_STATUS = 'FAILED';
```
**Result: 1 FAILED, amount 80,000 —** `93212RT-WKR-BSAL_SAL`:
`[FUSION_ERROR] The record referenced by the AssignmentId foreign key attribute wasn't found. You need to either specify a valid foreign key or first create the referenced record.`
Real Fusion HDL rejection (the BAD salary references a worker/assignment that never loaded).

## Fusion successes (count + money — LIVE FROM FUSION)
**Key path (HDL tie-back).** `HRC_INTEGRATION_KEY_MAP` where `OBJECT_NAME = 'Salary'`;
`SOURCE_SYSTEM_ID` = TFM `RECON_KEY` (prefixed `PERSON_NUMBER || '_SAL'`); `SURROGATE_ID` =
`CMP_SALARY.SALARY_ID` = captured `FUSION_SALARY_ID`. Money is read from `CMP_SALARY.SALARY_AMOUNT`.

Live query (bind prefix = `93212`), aligned to `bip/Salaries/query.sql`:
```sql
SELECT m.source_system_id, m.surrogate_id AS salary_id,
       s.salary_amount, s.currency_code
FROM   hrc_integration_key_map m
JOIN   cmp_salary s ON s.salary_id = m.surrogate_id
WHERE  m.object_name = 'Salary'
AND    m.source_system_id LIKE '93212' || '%'
AND    m.source_system_id LIKE '%\_SAL' ESCAPE '\';
```
**Result (live, hcm_impl): 1 success, amount 75,000 USD.**
- `93212RT-WKR-G1_SAL  SURROGATE_ID 300000333896787`
- Confirmed in base: `CMP_SALARY.SALARY_ID = 300000333896787`, `SALARY_AMOUNT = 75000`, `CURRENCY_CODE = USD`.
- Matches captured `FUSION_SALARY_ID = 300000333896787` on the LOADED TFM row.

## Amount column + rationale
**`SALARY_AMOUNT`** — the migrated salary figure; the meaningful money grain for this object.
Currency is USD (derived from the salary basis; verified live on `CMP_SALARY`).

## Balance check
- **Count:** Fusion successes (1) + TFM errors (1) = 2 = STG total (2). **BALANCED.**
- **Money:** Fusion success 75,000 + TFM error 80,000 = 155,000 = STG total 155,000. **BALANCED.**

## Gotchas (HDL specifics)
- No import ESS request id for HDL; tie-back is the captured `FUSION_SALARY_ID` via `HRC_INTEGRATION_KEY_MAP`, not a request id.
- The `%\_SAL` filter is required: it scopes map rows to the Salary object's SourceSystemId shape within the prefix.
- The FAILED row's amount (80,000) still counts toward the STG money total — a rejected salary is honestly reported, not dropped.
- `SALARY_AMOUNT`/`CURRENCY_CODE` are `VARCHAR2` in TFM; `TO_NUMBER` for sums. `CURRENCY_CODE` is null in TFM (derived at Fusion), so read currency from `CMP_SALARY` live.
- Base table `CMP_SALARY` reads with the **hcm_impl** cred.
