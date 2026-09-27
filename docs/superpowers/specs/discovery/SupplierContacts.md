# SupplierContacts — RUN 132 three-source reconciliation (READ-ONLY discovery)

## Object / tables / grain
- **Object / CEMLI:** `SupplierContacts` (independent supplier object — own zip, ESS import, TFM table).
- **Grain:** one supplier contact (person party).
- **STG table:** `DMT_POZ_SUP_CONTACTS_STG_TBL` (no RUN_ID column).
- **TFM table:** `DMT_POZ_SUP_CONTACTS_TFM_TBL` (status column `TFM_STATUS`).
- **Fusion interface:** `POZ_SUP_CONTACTS_INT` + rejections `POZ_SUPPLIER_INT_REJECTIONS`.
- **Fusion base table:** `HZ_PARTIES`, joined `b.party_id = i.per_party_id AND b.party_type = 'PERSON'`.
- **Amount column: NONE — count-only.** No money; reconciliation is by record count.

## STG total (records this run processed)
```sql
SELECT COUNT(*) FROM dmt_run_records_v WHERE run_id = 132 AND cemli_code = 'SupplierContacts';
```
**Result: 3** (2 LOADED + 1 FAILED, 0 unaccounted).

## TFM errors (FAILED records, each with real ERROR_TEXT)
```sql
SELECT dmt_reference, tfm_status, error_text
FROM   dmt_run_records_v
WHERE  run_id = 132 AND cemli_code = 'SupplierContacts' AND tfm_status = 'FAILED';
```
**Result: 1 FAILED** — `DMT:132::103`
ERROR_TEXT: `[FUSION_ERROR] You must provide a valid value for either the VENDOR_ID or the VENDOR_NAME. [VENDOR_NAME]` (real Fusion rejection).

## Fusion successes (queried LIVE from Fusion)
**Key path used: LOAD_ID** — `LOAD_REQUEST_ID = 10024164` (DMT_WORK_QUEUE_TBL.LOAD_ESS_JOB_ID for RUN 132 / SupplierContacts). Reuses the deployed Contract-v1 base-table join from `bip/SupplierContacts/SUP_CONT_DM.xdm`.
```sql
SELECT i.contact_interface_id, b.party_id AS contact_id,
       CASE WHEN b.party_id IS NOT NULL THEN 'PROCESSED' ELSE 'REJECTED' END AS status
FROM   poz_sup_contacts_int i
LEFT JOIN hz_parties b ON b.party_id = i.per_party_id AND b.party_type = 'PERSON'
WHERE  i.load_request_id = 10024164;
```
Run via `python scripts/fusion_bip_query.py --cred fin_impl`.
**Result: 2 PROCESSED, 1 REJECTED.** Base-table PARTY_IDs = `300000333906309`, `300000333906323` — both match the captured FUSION_CONTACT_ID on the two LOADED TFM rows exactly.

## Balance check
Fusion successes (2) + TFM errors (1) = STG total (3). **BALANCED.**

## Gotchas
- STG has no RUN_ID — use the TFM rows for RUN 132.
- Key on LOAD_REQUEST_ID (DMT_WORK_QUEUE_TBL.LOAD_ESS_JOB_ID), never the prefix.
- Base table is HZ_PARTIES with PARTY_TYPE='PERSON' (the contact becomes a person party), joined on the interface-stamped per_party_id — not a POZ table.
