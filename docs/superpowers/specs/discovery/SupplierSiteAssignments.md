# SupplierSiteAssignments — RUN 132 three-source reconciliation (READ-ONLY discovery)

## Object / tables / grain
- **Object / CEMLI:** `SupplierSiteAssignments` (independent supplier object — own zip, ESS import, TFM table).
- **Grain:** one supplier site assignment (site × business unit).
- **STG table:** `DMT_POZ_SUP_SITE_ASSN_STG_TBL` (no RUN_ID column).
- **TFM table:** `DMT_POZ_SUP_SITE_ASSN_TFM_TBL` (status column `TFM_STATUS`).
- **Fusion interface:** `POZ_SITE_ASSIGNMENTS_INT` + rejections `POZ_SUPPLIER_INT_REJECTIONS`.
- **Fusion base table:** `POZ_SITE_ASSIGNMENTS_ALL_M` (joined via `FUN_ALL_BUSINESS_UNITS_V`), resolved by business key `a.vendor_site_id = i.vendor_site_id AND b.bu_name = i.business_unit_name AND a.inactive_date IS NULL` (the interface leaves ASSIGNMENT_ID NULL even for PROCESSED rows).
- **Amount column: NONE — count-only.** No money; reconciliation is by record count.

## STG total (records this run processed)
```sql
SELECT COUNT(*) FROM dmt_run_records_v WHERE run_id = 132 AND cemli_code = 'SupplierSiteAssignments';
```
**Result: 3** (2 LOADED + 1 FAILED, 0 unaccounted).

## TFM errors (FAILED records, each with real ERROR_TEXT)
```sql
SELECT dmt_reference, tfm_status, error_text
FROM   dmt_run_records_v
WHERE  run_id = 132 AND cemli_code = 'SupplierSiteAssignments' AND tfm_status = 'FAILED';
```
**Result: 1 FAILED** — `DMT:132::103`
ERROR_TEXT: `[FUSION_ERROR] You must provide a valid value. [BUSINESS_UNIT_NAME]` (real Fusion rejection).

## Fusion successes (queried LIVE from Fusion)
**Key path used: LOAD_ID** — `LOAD_REQUEST_ID = 10024145` (DMT_WORK_QUEUE_TBL.LOAD_ESS_JOB_ID for RUN 132 / SupplierSiteAssignments). Reuses the deployed Contract-v1 correlated-subquery base-table resolution from `bip/SupplierSiteAssignments/SUP_SITE_ASSN_DM.xdm`.
```sql
SELECT i.assignment_interface_id,
       (SELECT MAX(a.assignment_id)
        FROM   poz_site_assignments_all_m a, fun_all_business_units_v b
        WHERE  a.vendor_site_id = i.vendor_site_id
        AND    b.bu_id = a.bu_id
        AND    b.bu_name = i.business_unit_name
        AND    a.inactive_date IS NULL) AS assignment_id,
       CASE WHEN (SELECT MAX(a.assignment_id)
                  FROM poz_site_assignments_all_m a, fun_all_business_units_v b
                  WHERE a.vendor_site_id = i.vendor_site_id
                  AND b.bu_id = a.bu_id AND b.bu_name = i.business_unit_name
                  AND a.inactive_date IS NULL) IS NOT NULL
            THEN 'PROCESSED' ELSE 'REJECTED' END AS status
FROM   poz_site_assignments_int i
WHERE  i.load_request_id = 10024145;
```
Run via `python scripts/fusion_bip_query.py --cred fin_impl`.
**Result: 2 PROCESSED, 1 REJECTED.** Base-table ASSIGNMENT_IDs = `300000333906264`, `300000333906266` — both match the captured FUSION_ASSIGNMENT_ID on the two LOADED TFM rows exactly.

## Balance check
Fusion successes (2) + TFM errors (1) = STG total (3). **BALANCED.**

## Gotchas
- STG has no RUN_ID — use the TFM rows for RUN 132.
- Key on LOAD_REQUEST_ID (DMT_WORK_QUEUE_TBL.LOAD_ESS_JOB_ID), never the prefix.
- **Do NOT join on ASSIGNMENT_ID** — the interface leaves it NULL even for PROCESSED rows. Resolve the base id by business key (vendor_site_id + business_unit_name via FUN_ALL_BUSINESS_UNITS_V, inactive_date IS NULL) exactly as the deployed data model does.
