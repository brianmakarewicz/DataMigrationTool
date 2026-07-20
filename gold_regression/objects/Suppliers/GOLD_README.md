# Suppliers — gold regression fixture

A standalone, reloadable FBDI fixture (2 good + 1 bad supplier) that loads
directly into Oracle Fusion via the ERP Integration SOAP service, with read-only
BIP verification against the base and interface tables. No DMT tool code, no DMT
database, is involved in the load path.

## The exact call

| Thing | Value |
|---|---|
| Endpoint | `{FUSION_URL}/fscmService/ErpIntegrationService` |
| Operation | `loadAndImportData` (SOAPAction `http://xmlns.oracle.com/apps/financials/commonModules/shared/model/erpIntegrationService/loadAndImportData`) |
| Auth | HTTP Basic, user `calvin.roth` (credential role `fin_impl` in connections.json) |
| UCM DocumentAccount | `prc/supplier/import` |
| ContentType | `ZIP` |
| `<typ:interfaceDetails>` | `24` (the Suppliers `SOURCE_ERP_OPTIONS_ID` from `db/seed/dmt_erp_interface_options_tbl.sql`) |
| `<erp:JobName>` | `/oracle/apps/ess/prc/poz/supplierImport,ImportSuppliers` |
| `<erp:ParameterList>` | `NEW,N` |
| `<typ:notificationCode>` | `10` |

Note on JobName: the seed stores the import job with a semicolon —
`/oracle/apps/ess/prc/poz/supplierImport;ImportSuppliers`. `loadAndImportData`
requires the last semicolon replaced with a comma, giving
`/oracle/apps/ess/prc/poz/supplierImport,ImportSuppliers`.

`loadAndImportData` returns the **Load ESS request id** in the `<result>`
element. Poll it with `getESSJobStatus` (same endpoint, SOAPAction
`.../getESSJobStatus`, `<typ:requestId>`) every 60s until terminal:
SUCCEEDED / WARNING / FAILED / ERROR / EXPIRED. The load request id is the
selection key for verification — `LOAD_REQUEST_ID` is stamped on every interface
row even when the chained import job errors.

## The FBDI artifact

- One CSV inside the zip: `PoSupplierImport.csv` (FBDI control-file name Fusion
  expects). **No header row; position-based per the CTL.** Layout taken byte-for-byte
  from the proven load `test/fbdi_zips/Suppliers_116.zip`.
- Three rows, all `IMPORT_ACTION=CREATE`:
  - GOOD-1 `${PREFIX}RT-SUP-G1`, org type `CORPORATION`
  - GOOD-2 `${PREFIX}RT-SUP-G2`, org type `CORPORATION`
  - BAD-1  `${PREFIX}RT-SUP-BAD1`, org type `INVALID_ORG_TYPE` (Fusion rejects this lookup code)
- `${PREFIX}` is stamped onto the natural keys `VENDOR_NAME` and `SEGMENT1`
  (6 tokens per file) so the same fixture reloads on any run without colliding
  with prior data.
- Templated source: `artifact/PoSupplierImport.csv`. Assembled zip:
  `Suppliers_gold.zip` (rebuilt by `harness/build_artifact.py Suppliers <prefix>`).

## Verification (read-only, via the ephemeral BIP relay)

Both queries run through `FBT_BIP_PKG.RUN_DATA_MODEL_EPHEMERAL` on ATP queryapp
(same mechanism as `scripts/fusion_bip_query.py`), credential role `fin_impl`.
The reconciliation query LEFT JOINs the interface table to the base table on the
Fusion vendor id, so one query proves both directions:

```sql
SELECT i.vendor_interface_id,
       b.vendor_id,
       i.vendor_name,
       i.segment1,
       CASE WHEN b.vendor_id IS NOT NULL THEN 'PROCESSED' ELSE 'REJECTED' END AS status,
       i.load_request_id,
       (SELECT LISTAGG(CASE WHEN r.attribute IS NOT NULL
                            THEN r.reject_lookup_code || ' [' || r.attribute || ']'
                            ELSE r.reject_lookup_code END, '; ')
               WITHIN GROUP (ORDER BY r.rejection_id)
        FROM   poz_supplier_int_rejections r
        WHERE  r.parent_table = 'POZ_SUPPLIERS_INT'
        AND    r.parent_id    = i.vendor_interface_id) AS error_message
FROM   poz_suppliers_int i
LEFT JOIN poz_suppliers b ON b.vendor_id = i.vendor_id
WHERE  i.load_request_id = :LOAD_REQUEST_ID;
```

- **Good rows → base table.** `STATUS=PROCESSED` with a real `VENDOR_ID` from
  `POZ_SUPPLIERS` (the base table). Both good SEGMENT1 keys must appear.
- **Bad row → interface error, absent from base.** `STATUS=REJECTED`,
  `VENDOR_ID` NULL (no base row), and a non-null `ERROR_MESSAGE` from
  `POZ_SUPPLIER_INT_REJECTIONS`.

Tables: interface `POZ_SUPPLIERS_INT`, base `POZ_SUPPLIERS`, rejections
`POZ_SUPPLIER_INT_REJECTIONS`. (These are the names the deployed, proven BIP data
model `bip/Suppliers/query.sql` uses — they supersede the conflicting name lists
flagged in `objects/Suppliers/README.md`.)

## How to run it

```bash
cd gold_regression/harness
python build_artifact.py Suppliers <PREFIX>              # -> objects/Suppliers/Suppliers_gold.zip
python load_fbdi.py Suppliers ../objects/Suppliers/Suppliers_gold.zip   # -> load request id + terminal status
python verify.py  Suppliers <LOAD_REQUEST_ID> <PREFIX>   # -> good_in_base / bad_in_interface / pass
```

## Live evidence

**2026-07-19 — LIVE-PROVEN. PASS.**

Standalone load path only (no DMT database, no DMT code in the load path);
verification via the read-only BIP relay only.

| Field | Value |
|---|---|
| Date | 2026-07-19 |
| Prefix | `93107` |
| Load ESS request id | `9762785` |
| Terminal status | `SUCCEEDED` (getESSJobStatus, terminal at 60s) |
| Credential role | `fin_impl` (SOAP load and BIP relay) |
| Interface rows seen | 3 (all accounted for, 0 anomalies) |

**Good rows → base table `POZ_SUPPLIERS` (2/2 PROCESSED):**

| SEGMENT1 | VENDOR_NAME | VENDOR_ID |
|---|---|---|
| `93107RT-SUP-G1` | `93107RT Supplier Good-1` | `300000331542172` |
| `93107RT-SUP-G2` | `93107RT Supplier Good-2` | `300000331542179` |

**Bad row → interface rejection, absent from base (1/1 REJECTED):**

| SEGMENT1 | VENDOR_NAME | Rejection error |
|---|---|---|
| `93107RT-SUP-BAD1` | `93107RT Supplier Bad-1` | `You must provide a valid tax organization type. [ORGANIZATION_TYPE_LOOKUP_CODE]` |

The bad row (org type `INVALID_ORG_TYPE`) landed in `POZ_SUPPLIERS_INT` with the
above `POZ_SUPPLIER_INT_REJECTIONS` error and `VENDOR_ID` NULL — no row in
`POZ_SUPPLIERS`. The final gold zip `Suppliers_gold.zip` (prefix 93107) is kept
in this directory.

Note: the harness uses credential role `fin_impl` (Fusion user `fin_impl`) for
both the SOAP load and the BIP relay; the earlier "user `calvin.roth`" note in
the table above is the seed's stored auth user and is not what this run used.

### Second independent live proof — 2026-07-19 (prefix 71991)

A separate run confirmed the load path again on the same day. Same result:
two good suppliers in the base table, one bad supplier rejected and absent.

| Field | Value |
|---|---|
| Date | 2026-07-19 |
| Prefix | `71991` |
| Load ESS request id (`loadAndImportData` result) | `9762798` |
| Chained Import Suppliers child request id | `9762801` |
| Terminal status (`getESSJobStatus` on 9762798) | **SUCCEEDED** |
| Credential role | `fin_impl` |

Good rows — present in `POZ_SUPPLIERS` (direct base-table read by SEGMENT1):

| SEGMENT1 | VENDOR_ID | Interface STATUS |
|---|---|---|
| `71991RT-SUP-G1` | `300000331542217` | PROCESSED |
| `71991RT-SUP-G2` | `300000331542224` | PROCESSED |

Bad row — rejected, absent from `POZ_SUPPLIERS`:

- `71991RT-SUP-BAD1` (vendor_interface_id 16013): interface `STATUS=REJECTED`,
  `VENDOR_ID` NULL. A direct `POZ_SUPPLIERS` read for the three prefixed keys
  returned only the two good rows — the bad key is not in the base table.
- Rejection in `POZ_SUPPLIER_INT_REJECTIONS`
  (parent_table `POZ_SUPPLIERS_INT`, request_id 9762801):
  **"You must provide a valid tax organization type."**
  (attribute `ORGANIZATION_TYPE_LOOKUP_CODE`, value `INVALID_ORG_TYPE`).

**Harness caveat found on this run (verifier false-negative — worth fixing).**
On the 71991 run, `verify.py` flagged GOOD-2 as an anomaly ("good key not
PROCESSED/no base id") and returned `pass: false`, even though GOOD-2 really did
load (interface `STATUS=PROCESSED`, base-table `VENDOR_ID` 300000331542224).
Two causes in `objects.json` `recon_query` / `verify.py`:

1. The reconciliation query selects `b.vendor_id` from
   `LEFT JOIN poz_suppliers b ON b.vendor_id = i.vendor_id`. Through the ephemeral
   BIP relay that join returned NULL for GOOD-2 even though the base row exists.
   Read the interface table's own `VENDOR_ID`/`STATUS` (or select `i.vendor_id`)
   rather than re-deriving presence from the base-table join.
2. The rejection subquery keys only on `parent_table = 'POZ_SUPPLIERS_INT'` and
   `parent_id`. But `vendor_interface_id` values are reused as `parent_id` across
   the sibling supplier interface tables and across prior loads, so the subquery
   can miss or mis-attribute rejections. Also filter
   `r.request_id = <import child request id>` (here 9762801).

The load itself is proven live on both runs; only the verifier's reporting needs
these two fixes so its `pass` flag matches ground truth.
