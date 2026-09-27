# SupplierAddresses — RUN 132 three-source reconciliation (READ-ONLY discovery)

## Object / tables / grain
- **Object / CEMLI:** `SupplierAddresses` (independent supplier object — own zip, ESS import, TFM table).
- **Grain:** one supplier address (party site).
- **STG table:** `DMT_POZ_SUP_ADDR_STG_TBL` (no RUN_ID column).
- **TFM table:** `DMT_POZ_SUP_ADDR_TFM_TBL` (status column `TFM_STATUS`).
- **Fusion interface:** `POZ_SUP_ADDRESSES_INT` + rejections `POZ_SUPPLIER_INT_REJECTIONS`.
- **Fusion base table:** `HZ_PARTY_SITES`, joined `b.party_site_id = i.party_site_id`.
- **Amount column: NONE — count-only.** No money; reconciliation is by record count.

## STG total (records this run processed)
```sql
SELECT COUNT(*) FROM dmt_run_records_v WHERE run_id = 132 AND cemli_code = 'SupplierAddresses';
```
**Result: 3** (2 LOADED + 1 FAILED, 0 unaccounted).

## TFM errors (FAILED records, each with real ERROR_TEXT)
```sql
SELECT dmt_reference, tfm_status, error_text
FROM   dmt_run_records_v
WHERE  run_id = 132 AND cemli_code = 'SupplierAddresses' AND tfm_status = 'FAILED';
```
**Result: 1 FAILED** — `DMT:132::123`
ERROR_TEXT: `[FUSION_ERROR] You must provide a valid value for either the VENDOR_ID or the VENDOR_NAME. [VENDOR_NAME]` (real Fusion rejection).

## Fusion successes (queried LIVE from Fusion)
**Key path used: LOAD_ID** — `LOAD_REQUEST_ID = 10023955` (DMT_WORK_QUEUE_TBL.LOAD_ESS_JOB_ID for RUN 132 / SupplierAddresses). Reuses the deployed Contract-v1 base-table join from `bip/SupplierAddresses/SUP_ADDR_DM.xdm`.
```sql
SELECT i.address_interface_id, b.party_site_id,
       CASE WHEN b.party_site_id IS NOT NULL THEN 'PROCESSED' ELSE 'REJECTED' END AS status
FROM   poz_sup_addresses_int i
LEFT JOIN hz_party_sites b ON b.party_site_id = i.party_site_id
WHERE  i.load_request_id = 10023955;
```
Run via `python scripts/fusion_bip_query.py --cred fin_impl`.
**Result: 2 PROCESSED, 1 REJECTED.** Base-table PARTY_SITE_IDs = `300000333906031`, `300000333906037` — both match the captured FUSION_PARTY_SITE_ID on the two LOADED TFM rows exactly.

## Balance check
Fusion successes (2) + TFM errors (1) = STG total (3). **BALANCED.**

## Gotchas
- STG has no RUN_ID — use the TFM rows for RUN 132.
- Key on LOAD_REQUEST_ID (DMT_WORK_QUEUE_TBL.LOAD_ESS_JOB_ID), never the prefix.
- Base table is HZ_PARTY_SITES (TCA party site), not a POZ table — addresses become party sites.
