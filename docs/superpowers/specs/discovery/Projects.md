# Projects — Three-Source Reconciliation Discovery (RUN_ID 132)

Read-only proof against the local Docker DMT DB (`dmt_owner@//localhost:1523/FREEPDB1`)
and the live Fusion demo instance. No DB objects modified.

## Object / tables / grain
- **Object:** Projects (ONE FBDI zip, one Import ESS job `ImportProjectJobDef`, four record-type CSVs).
- **This spec reconciles the Projects record type only** (the header project). Tasks / TeamMembers /
  TxnControls are other tiers of the same object; RUN 132 loaded only the 3 project headers.
- **TFM table:** `DMT_PJF_PROJECTS_TFM_TBL` (has `RUN_ID`, `RECON_KEY`, `TFM_STATUS`, `FUSION_PROJECT_ID`, `ERROR_TEXT`).
- **Fusion base table:** `PJF_PROJECTS_ALL_VL` (queryable VL over `PJF_PROJECTS_ALL_B`).
- **Fusion key:** `FUSION_PROJECT_ID` = `PROJECT_ID`; run selector = prefix on `SEGMENT1` (project number).
- **Grain:** one row per project. **Money: NONE** — Projects carries no reconcilable amount
  (only an unrelated `OPPORTUNITY_AMT` sales field, not populated for migration). COUNT-ONLY. Confirmed.
- **Run prefix:** 93212 (`DMT_PIPELINE_RUN_TBL.PREFIX`, RUN_MODE=ALL).

## STG total (count; no money)
STG has no RUN_ID and holds duplicate scenario-seed rows (each business key appears twice across runs),
so the authoritative run record set is the TFM rows for RUN 132.

```sql
-- Run record set (authoritative STG-equivalent count for the run)
SELECT COUNT(*) AS stg_total
FROM   dmt_pjf_projects_tfm_tbl
WHERE  run_id = 132;
```
**Result:** stg_total = **3** (RECON_KEYs: 93212RTPRJ001, 93212RTPRJ002, 93212RTPRJ-BAD1).

## TFM errors (count + real ERROR_TEXT)
```sql
SELECT recon_key, tfm_status, error_text
FROM   dmt_pjf_projects_tfm_tbl
WHERE  run_id = 132 AND tfm_status = 'FAILED';
```
**Result:** 1 FAILED.
- `93212RTPRJ-BAD1` → `[IMPORT_REPORT] The project status isn't valid. Enter a valid project status,
  load the data, and resubmit the import process.` (real Fusion import-report message).

## Fusion successes (count; LIVE FROM FUSION)
Key path: the run prefix stamped into `SEGMENT1` (README DB-17; `PJF_PROJECTS_ALL_B.REQUEST_ID` is NULL
after import on this pod, so prefix is the only reliable base identity). FUSION_ID = `PROJECT_ID`.

```sql
-- via scripts/fusion_bip_query.py --cred fin_impl
SELECT project_id AS PROJECT_ID, segment1 AS SEGMENT1, name AS NAME
FROM   pjf_projects_all_vl
WHERE  segment1 LIKE '93212%'
ORDER BY segment1;
```
**Result (LIVE, confirmed):** 2 rows.
- 300000333889358 / 93212RTPRJ001 / "93212RT Project Good-1" → matches TFM LOADED FUSION_PROJECT_ID 300000333889358.
- 300000333889383 / 93212RTPRJ002 / "93212RT Project Good-2" → matches TFM LOADED FUSION_PROJECT_ID 300000333889383.

Both LOADED TFM ids are present in the Fusion base table with the exact prefixed project number.

## Balance check
Fusion successes (2) + TFM errors (1) = 3 = STG/run total (3). **BALANCED** (count-only).

## Gotchas
- No money on Projects — do not invent an amount.
- `SEGMENT1` (prefix) is the only durable base key; `REQUEST_ID`, `PM_PROJECT_REFERENCE`,
  `ATTRIBUTE1`, `ATTRIBUTE_CATEGORY` all come back empty on this pod.
- STG holds duplicate seed rows and no RUN_ID — never count STG directly for a run; use the TFM run set.
- The BAD row's real error lives only in the Import Report XML (interface has no error-text column);
  the reconciler harvests it into TFM.ERROR_TEXT (marker `#IMPORT_REPORT#` on the wire).
