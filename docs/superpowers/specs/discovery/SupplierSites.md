# SupplierSites — RUN 132 three-source reconciliation (READ-ONLY discovery)

## Object / tables / grain
- **Object / CEMLI:** `SupplierSites` (independent supplier object — own zip, ESS import, TFM table).
- **Grain:** one supplier site.
- **STG table:** `DMT_POZ_SUP_SITE_STG_TBL` (no RUN_ID column).
- **TFM table:** `DMT_POZ_SUP_SITE_TFM_TBL` (status column `TFM_STATUS`).
- **Fusion interface:** `POZ_SUPPLIER_SITES_INT` + rejections `POZ_SUPPLIER_INT_REJECTIONS`.
- **Fusion base table:** `POZ_SUPPLIER_SITES_ALL_M`, joined by business key `b.vendor_id = i.vendor_id AND b.vendor_site_code = i.vendor_site_code` (the interface leaves VENDOR_SITE_ID NULL even for PROCESSED rows, so the base row is resolved by business key — see README Known Issues).
- **Amount column: NONE — count-only.** No money; reconciliation is by record count.

## STG total (records this run processed)
```sql
SELECT COUNT(*) FROM dmt_run_records_v WHERE run_id = 132 AND cemli_code = 'SupplierSites';
```
**Result: 3** (2 LOADED + 1 FAILED, 0 unaccounted).

## TFM errors (FAILED records, each with real ERROR_TEXT)
```sql
SELECT dmt_reference, tfm_status, error_text
FROM   dmt_run_records_v
WHERE  run_id = 132 AND cemli_code = 'SupplierSites' AND tfm_status = 'FAILED';
```
**Result: 1 FAILED** — `DMT:132::103`
ERROR_TEXT: `[FUSION_ERROR] You must provide a valid value for either the VENDOR_ID or the VENDOR_NAME. [VENDOR_NAME]; A value is required. You must provide a value. [VENDOR_ID]` (real Fusion rejection).

## Fusion successes (queried LIVE from Fusion)
**Key path used: LOAD_ID** — `LOAD_REQUEST_ID = 10024125` (DMT_WORK_QUEUE_TBL.LOAD_ESS_JOB_ID for RUN 132 / SupplierSites). Reuses the deployed Contract-v1 base-table join from `bip/SupplierSites/SUP_SITE_DM.xdm`.
```sql
SELECT i.vendor_site_interface_id, b.vendor_site_id,
       CASE WHEN b.vendor_site_id IS NOT NULL THEN 'PROCESSED' ELSE 'REJECTED' END AS status
FROM   poz_supplier_sites_int i
LEFT JOIN poz_supplier_sites_all_m b
       ON b.vendor_id = i.vendor_id AND b.vendor_site_code = i.vendor_site_code
WHERE  i.load_request_id = 10024125;
```
Run via `python scripts/fusion_bip_query.py --cred fin_impl`.
**Result: 2 PROCESSED, 1 REJECTED.** Base-table VENDOR_SITE_IDs = `300000333906218`, `300000333906221` — both match the captured FUSION_VENDOR_SITE_ID on the two LOADED TFM rows exactly. The business-key join resolved a real base id for each, retiring the old "interface returned NULL vendor_site_id" residue.

## Balance check
Fusion successes (2) + TFM errors (1) = STG total (3). **BALANCED.**

## Gotchas
- STG has no RUN_ID — use the TFM rows for RUN 132.
- Key on LOAD_REQUEST_ID (DMT_WORK_QUEUE_TBL.LOAD_ESS_JOB_ID), never the prefix.
- **Do NOT join the base table on VENDOR_SITE_ID** — the interface leaves it NULL even for PROCESSED rows. Resolve the base row by business key (vendor_id + vendor_site_code) as the deployed data model does.
