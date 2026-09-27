# Grants — Three-Source Reconciliation Discovery (RUN_ID 132)

Read-only proof. RUN 132 result: **0 LOADED, 3 FAILED** — so the Fusion success side is DESIGNED
here, not confirmable in this run. Grants is known env-blocked on the demo pod; the FAILED rows carry
real Fusion errors. No DB objects modified.

## Object / tables / grain
- **Object:** Grants / award headers (ONE FBDI zip, ESS job `AwardMassImportJob`; 14 award sub-tables
  ride the one header import).
- **TFM table:** `DMT_GMS_AWD_HEADERS_TFM_TBL` (has `RUN_ID`, `RECON_KEY`, `TFM_STATUS`,
  `FUSION_AWARD_ID`, `FT_AMOUNT`, `ERROR_TEXT`).
- **Fusion base table:** `GMS_AWARD_HEADERS_B`.
- **Fusion key:** `FUSION_AWARD_ID` = `ID` (award id); run selector = `DC_REQUEST_ID` = the import ESS
  request id (VERIFIED convention: for `AWARD_SOURCE='FBDI'` rows `SUMMARY_REQUEST_ID` is NULL and
  `DC_REQUEST_ID` carries the real import ESS id).
- **Grain:** one row per award header. **Money:** `FT_AMOUNT` exists on TFM but is **NOT populated**
  for this run's rows (NULL) — effectively COUNT-ONLY for run 132.
- **Run prefix:** 93212. **Import ESS job id:** 10023979 (queue_id 849).

## STG total (count)
STG has no RUN_ID and holds duplicate seed rows; use the TFM run set. Note the run's TFM RECON_KEYs are
NULL (the transform did not stamp a key on the rejected pre-validation rows), so scope by RUN_ID only.
```sql
SELECT COUNT(*) AS stg_total, SUM(ft_amount) AS stg_money
FROM   dmt_gms_awd_headers_tfm_tbl
WHERE  run_id = 132;
```
**Result:** stg_total = **3**, stg_money = **NULL** (FT_AMOUNT not populated). Source AWARD_NUMBERs in
STG: RTGNT001, RTGNT002, RTGNT-BAD1.

## TFM errors (count + real ERROR_TEXT)
```sql
SELECT recon_key, tfm_status, error_text
FROM   dmt_gms_awd_headers_tfm_tbl
WHERE  run_id = 132 AND tfm_status = 'FAILED';
```
**Result:** 3 FAILED, all with real Fusion messages:
- `[FUSION_ERROR] The award contract can't be created because requisite setup steps haven't been completed.` (×2)
- `[FUSION_ERROR] You must provide a value for the Business Unit attribute.` (×1)

The first two are the demo-pod grants-setup blocker (documented env block); the third is a real
required-field rejection. All honest, reportable failures.

## Fusion successes — DESIGNED query (0 LOADED, not confirmable in run 132)
No award reached `GMS_AWARD_HEADERS_B` for this run. Designed positive-confirmation query (from the
Grants .xdm BASE tier), scoped by the import ESS id:
```sql
-- via scripts/fusion_bip_query.py --cred fin_impl
SELECT b.id                   AS ID,
       b.sponsor_award_number AS SPONSOR_AWARD_NUMBER,
       b.dc_request_id        AS DC_REQUEST_ID,
       b.award_source         AS AWARD_SOURCE
FROM   gms_award_headers_b b
WHERE  b.dc_request_id = 10023979    -- the run's import ESS job id (queue 849)
AND    b.award_source  = 'FBDI';
```
**Live result today:** 0 rows — confirms 0 LOADED, matches the reconciler. (The base table holds ~117
historical FBDI/UI awards from prior work, so the query SHAPE is proven; this run simply produced none.)

## Amount column + rationale
`FT_AMOUNT` (funding-total amount) is the closest award money on TFM, but it is not populated for this
run, so Grants is treated COUNT-ONLY here. If money reconciliation is ever needed, the funding total
lives across the award funding sub-tables, which have no persistent queryable Fusion table on this pod.

## Balance check
Fusion successes (0, designed) + TFM errors (3) = 3 = STG/run total (3). **BALANCED on count.**
0 LOADED in this run (env-blocked), so the success side is designed only; money not applicable.

## Gotchas
- **Interface purge:** Fusion purges `GMS_AWARD_HEADERS_INT` (and all award interface/error tables)
  immediately after every `AwardMassImportJob` run, on success AND reject. So per-award rejection
  messages survive ONLY in the Award Batch Import Report child ESS (`ImportAwardReportJob` /
  `AwardBatchImportReportDm`), parsed by `dmt_grants_results_pkg`. Do NOT trust interface-tier absence
  as LOADED — LOADED is confirmed ONLY by `GMS_AWARD_HEADERS_B`.
- Run scoping on the base table is `DC_REQUEST_ID` (not `SUMMARY_REQUEST_ID`, which is NULL for FBDI).
- Run TFM RECON_KEYs are NULL for run 132 (rejected pre-validation), so scope by RUN_ID.
- STG has no RUN_ID and holds duplicate seed rows — use the TFM run set.
