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

## Production key resolution

The earlier balance matched on `SEGMENT1 LIKE '93212%'` — the run **test prefix** — which is
forbidden in production (a real client's project numbers are not prefixed by our run id). This
section resolves a production-valid key that selects exactly RUN 132's loaded projects.

**Step 1 — ESS request id on a Fusion column? NO.**
DMT_WORK_QUEUE_TBL for RUN 132 / Projects gives `LOAD_ESS_JOB_ID = 10023760`,
`IMPORT_ESS_JOB_ID = 10023769`. Neither lands on a queryable column:
- `PJF_PROJECTS_ALL_B.REQUEST_ID` is **NULL** for both loaded projects (Import does not stamp it).
- `PJF_PROJECTS_ALL_XFACE` (interface) returns **zero rows** for the run — accepted rows are
  purged after import, so `LOAD_REQUEST_ID` / `REQUEST_ID = 10023760/10023769` matches nothing.

Live proof (both empty / null):
```sql
-- via scripts/fusion_bip_query.py --cred fin_impl
-- base table: REQUEST_ID null for both loaded projects
SELECT TO_CHAR(project_id) AS PROJECT_ID, segment1 AS SEGMENT1,
       TO_CHAR(request_id) AS REQUEST_ID
FROM   pjf_projects_all_b
WHERE  project_id IN (300000333889358, 300000333889383);
-- -> REQUEST_ID is empty for both rows.

-- interface table: no rows for the run's ESS ids (purged)
SELECT project_number, TO_CHAR(load_request_id), TO_CHAR(request_id)
FROM   pjf_projects_all_xface
WHERE  load_request_id IN (10023760, 10023769)
   OR  request_id      IN (10023760, 10023769);
-- -> zero rows.
```

**Step 2 — A stamped source reference that round-trips? NO.**
Nothing was stamped to round-trip, and nothing survives on the base table:
- The DMT side sent no source reference: RUN 132 TFM rows have `SOURCE_APPLICATION_CODE`,
  `SOURCE_PROJECT_REFERENCE`, `ATTRIBUTE_CATEGORY`, `ATTRIBUTE1` all **NULL** (SOURCE_APPLICATION_CODE
  is deliberately blank — 'CONVERSION'/'EXTERNAL' are invalid on this demo pod; see README).
- On the Fusion base table, `PM_PROJECT_REFERENCE`, `INTEGRATED_PROJECT_REFERENCE` are **empty**
  for both loaded projects. `PM_PRODUCT_CODE = 'OPEN_INTERFACE'` is a constant on every
  interface-loaded project (not run-scoped). `LAST_UPDATE_LOGIN` / `CREATED_BY = FIN_IMPL` are
  session/user, not run-scoped. None isolates this run's records.

Live proof (all reference columns empty):
```sql
-- via scripts/fusion_bip_query.py --cred fin_impl
SELECT TO_CHAR(project_id) AS PROJECT_ID, segment1 AS SEGMENT1,
       pm_project_reference AS PM_PROJECT_REFERENCE,
       integrated_project_reference AS INTEGRATED_PROJECT_REFERENCE,
       pm_product_code AS PM_PRODUCT_CODE
FROM   pjf_projects_all_b
WHERE  project_id IN (300000333889358, 300000333889383);
-- -> PM_PROJECT_REFERENCE and INTEGRATED_PROJECT_REFERENCE empty;
--    PM_PRODUCT_CODE = OPEN_INTERFACE (constant, not run-specific).
```

**Step 3 — FALLBACK-TO-CAPTURED-IDS (the production key).**
No batch key round-trips. The production-valid key is the exact list of `FUSION_PROJECT_ID`
values DMT already captured on the LOADED TFM rows at import time. This is prefix-free and
identifies the run's records exactly, in production or test.

Captured ids (DMT_PJF_PROJECTS_TFM_TBL, RUN 132, TFM_STATUS='LOADED'):
`300000333889358`, `300000333889383`.

Live proof (returns exactly the run's 2 loaded projects, no others):
```sql
-- via scripts/fusion_bip_query.py --cred fin_impl
SELECT TO_CHAR(COUNT(*)) AS CNT,
       TO_CHAR(MIN(project_id)) AS MINID,
       TO_CHAR(MAX(project_id)) AS MAXID
FROM   pjf_projects_all_b
WHERE  project_id IN (300000333889358, 300000333889383);
-- -> CNT=2, MINID=300000333889358, MAXID=300000333889383 (LIVE, confirmed).
```
The id list is produced in production by DMT itself:
```sql
-- on the DMT DB, drives the Fusion IN-list above
SELECT fusion_project_id
FROM   dmt_pjf_projects_tfm_tbl
WHERE  run_id = 132 AND tfm_status = 'LOADED';
```

**Verdict: FALLBACK-TO-CAPTURED-IDS.** Count-only (Projects carries no money): 2 loaded =
2 base-table rows. Balanced with the 1 FAILED (BAD1) = 3 run total. The prefix-on-SEGMENT1
match in the "Fusion successes" section above is TEST-ONLY and must not be used in production.

## Gotchas
- No money on Projects — do not invent an amount.
- `SEGMENT1` (prefix) is the only durable base key; `REQUEST_ID`, `PM_PROJECT_REFERENCE`,
  `ATTRIBUTE1`, `ATTRIBUTE_CATEGORY` all come back empty on this pod.
- STG holds duplicate seed rows and no RUN_ID — never count STG directly for a run; use the TFM run set.
- The BAD row's real error lives only in the Import Report XML (interface has no error-text column);
  the reconciler harvests it into TFM.ERROR_TEXT (marker `#IMPORT_REPORT#` on the wire).
