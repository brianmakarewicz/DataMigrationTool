# Suppliers — RUN 132 three-source reconciliation (READ-ONLY discovery)

## Object / tables / grain
- **Object / CEMLI:** `Suppliers` (one of five independent supplier objects — its own zip, ESS import, TFM table).
- **Grain:** one supplier (vendor).
- **STG table:** `DMT_POZ_SUPPLIERS_STG_TBL` (no RUN_ID column).
- **TFM table:** `DMT_POZ_SUPPLIERS_TFM_TBL` (status column `TFM_STATUS`).
- **Fusion interface:** `POZ_SUPPLIERS_INT` + rejections `POZ_SUPPLIER_INT_REJECTIONS`.
- **Fusion base table:** `POZ_SUPPLIERS`, joined `b.vendor_id = i.vendor_id`.
- **Amount column: NONE — count-only.** Suppliers carry no money; reconciliation is by record count.

## STG total (records this run processed)
STG has no RUN_ID; the run's record set = the object's TFM rows for RUN 132 (record view).
```sql
SELECT COUNT(*) FROM dmt_run_records_v WHERE run_id = 132 AND cemli_code = 'Suppliers';
```
**Result: 3** (2 LOADED + 1 FAILED, 0 unaccounted).

## TFM errors (FAILED records, each with real ERROR_TEXT)
```sql
SELECT dmt_reference, tfm_status, error_text
FROM   dmt_run_records_v
WHERE  run_id = 132 AND cemli_code = 'Suppliers' AND tfm_status = 'FAILED';
```
**Result: 1 FAILED** — `DMT:132::123`
ERROR_TEXT: `[FUSION_ERROR] You must provide a valid tax organization type. [ORGANIZATION_TYPE_LOOKUP_CODE]` (real Fusion rejection).

## Fusion successes (queried LIVE from Fusion)
**Key path used: LOAD_ID** — `LOAD_REQUEST_ID = 10023694` (DMT_WORK_QUEUE_TBL.LOAD_ESS_JOB_ID for RUN 132 / Suppliers). Reuses the deployed Contract-v1 base-table join from `bip/Suppliers/SUP_DM.xdm`.
```sql
SELECT i.vendor_interface_id, b.vendor_id,
       CASE WHEN b.vendor_id IS NOT NULL THEN 'PROCESSED' ELSE 'REJECTED' END AS status
FROM   poz_suppliers_int i
LEFT JOIN poz_suppliers b ON b.vendor_id = i.vendor_id
WHERE  i.load_request_id = 10023694;
```
Run via `python scripts/fusion_bip_query.py --cred fin_impl`.
**Result: 2 PROCESSED, 1 REJECTED.** Base-table VENDOR_IDs = `300000333904539`, `300000333905546` — both match the captured FUSION_VENDOR_ID on the two LOADED TFM rows exactly.

## Balance check
Fusion successes (2) + TFM errors (1) = STG total (3). **BALANCED.**

## Gotchas
- STG tables have no RUN_ID — the run's record set is the object's TFM rows for RUN 132.
- Key the Fusion query on LOAD_REQUEST_ID, never the prefix. IMPORT_REQUEST_ID can be NULL when the import job errors; LOAD_REQUEST_ID is always populated.
- LOAD_REQUEST_ID for the Fusion base-table filter = DMT_WORK_QUEUE_TBL.LOAD_ESS_JOB_ID (join on RUN_ID + CEMLI_CODE).
