# SupplierSites — gold regression fixture

A standalone, reloadable FBDI fixture (2 good sites + 1 bad site) that loads
directly into Oracle Fusion via the ERP Integration SOAP service, with read-only
BIP verification against the base and interface tables. No DMT tool code, no DMT
database, is involved in the load path.

A supplier **site** is not a top-level record: it attaches to an **existing
supplier**, an **existing supplier address** (a party site), and a **procurement
business unit**. This fixture creates NEW sites (fresh site codes stamped with
`${PREFIX}`) but borrows all three references from data that already ships on the
target pod — discovered at load time — so it runs on any demo pod with no
dependency on suppliers or addresses we loaded earlier (portability rules 6-8).

## The exact call

| Thing | Value |
|---|---|
| Endpoint | `{FUSION_URL}/fscmService/ErpIntegrationService` |
| Operation | `loadAndImportData` (SOAPAction `.../erpIntegrationService/loadAndImportData`) |
| Auth | HTTP Basic, credential role `fin_impl` (connections.json). The seed's stored `FUSION_USERNAME` is `calvin.roth`, but this run uses `fin_impl` for both the SOAP load and the BIP relay. |
| UCM DocumentAccount | `prc/supplier/import` |
| ContentType | `ZIP` |
| `<typ:interfaceDetails>` | `25` (the Supplier Site `SOURCE_ERP_OPTIONS_ID` from `db/seed/dmt_erp_interface_options_tbl.sql`) |
| `<erp:JobName>` | `/oracle/apps/ess/prc/poz/supplierImport,ImportSupplierSites` |
| `<erp:ParameterList>` | `NEW,N` |
| `<typ:notificationCode>` | `10` |

Note on JobName: the seed stores the import job with a semicolon —
`/oracle/apps/ess/prc/poz/supplierImport;ImportSupplierSites`. `loadAndImportData`
requires the last semicolon replaced with a comma, giving
`/oracle/apps/ess/prc/poz/supplierImport,ImportSupplierSites`.

`loadAndImportData` returns the **Load ESS request id** in the `<result>`
element. Poll it with `getESSJobStatus` (same endpoint, SOAPAction
`.../getESSJobStatus`, `<typ:requestId>`) every 60s until terminal:
SUCCEEDED / WARNING / FAILED / ERROR / EXPIRED. `LOAD_REQUEST_ID` is stamped on
every `POZ_SUPPLIER_SITES_INT` row even when a row is rejected, so it is the
selection key for interface/rejection verification.

## ESS orchestration (jobs in order)

1. **Load File to Interface Tables** and **Import Supplier Sites**
   (`ImportSupplierSites`) run as the single chained `loadAndImportData` call
   above. The returned request id is the LOAD request; the import runs as its
   chained child. When that request reaches `SUCCEEDED`, good rows are in the
   base table and rejected rows carry their errors — no separate downstream job
   is needed. `downstream_jobs` is empty for this object.

## Discovery (portability — run at load time on the TARGET pod)

One read-only BIP query finds a real, already-present supplier that has an
existing address under a real procurement BU, so the new sites have something to
attach to:

```sql
SELECT * FROM (
  SELECT sv.vendor_name    AS VNAME,
         sv.vendor_id       AS VID,
         bu.bu_name         AS BUNAME,
         bu.bu_id           AS BUID,
         ps.party_site_name AS PSN,
         ss.party_site_id   AS PSID
  FROM   poz_supplier_sites_all_m ss
  JOIN   poz_suppliers_v          sv ON sv.vendor_id      = ss.vendor_id
  JOIN   fun_all_business_units_v bu ON bu.bu_id          = ss.prc_bu_id
  JOIN   hz_party_sites           ps ON ps.party_site_id  = ss.party_site_id
  WHERE  NVL(ss.inactive_date, SYSDATE+1) > SYSDATE
  AND    ps.party_site_name IS NOT NULL
  AND    sv.vendor_name NOT LIKE '%RT %'
  AND    sv.vendor_name NOT LIKE '%RT-%'
  AND    bu.bu_name = 'US1 Business Unit'
  ORDER  BY ps.party_site_name
) WHERE ROWNUM = 1;
```

Discovered tokens stamped into the fixture:

| Token | Meaning | Example (prefix 79717) |
|---|---|---|
| `${SUPPLIER_NAME}` | existing supplier the site attaches to | `ABC Bank` |
| `${PROC_BU}` | procurement business unit (by name) | `US1 Business Unit` |
| `${PARTY_SITE_NAME}` | existing supplier address the site sits on | `ABC Bank US1` |
| `${SUPPLIER_VENDOR_ID}`, `${PROC_BU_ID}`, `${PARTY_SITE_ID}` | ids (documentary; not written into the FBDI) | — |

## The FBDI artifact

- One CSV inside the zip: `PozSupplierSitesInt.csv` (FBDI control-file name
  Fusion expects). **No header row; position-based, 199 columns per the CTL.**
  Layout taken byte-for-byte from the proven load `test/fbdi_zips/SupplierSites_116.zip`.
- Meaningful positions:

  | Col | Field | Value |
  |---|---|---|
  | 1 | IMPORT_ACTION | `CREATE` |
  | 2 | SUPPLIER_NAME | `${SUPPLIER_NAME}` (good) / `${PREFIX}NO SUCH SUPPLIER` (bad) |
  | 3 | PROCUREMENT_BU | `${PROC_BU}` |
  | 4 | PARTY_SITE_NAME (existing address) | `${PARTY_SITE_NAME}` |
  | 5 | VENDOR_SITE_CODE (the new site's key) | `${PREFIX}RT-SITE-G1` / `-G2` / `-BAD` |
  | 9 | PAY_SITE_FLAG | `Y` |
  | 11 | PURCHASING_SITE_FLAG | `Y` |

- Three rows, all `IMPORT_ACTION=CREATE`:
  - GOOD-1 site code `${PREFIX}RT-SITE-G1` on the discovered supplier + address + BU
  - GOOD-2 site code `${PREFIX}RT-SITE-G2` on the same supplier + address + BU
  - BAD-1  site code `${PREFIX}RT-SITE-BAD`, SUPPLIER_NAME `${PREFIX}NO SUCH SUPPLIER`
    (no such supplier exists → deterministic Fusion rejection: invalid supplier reference)
- `${PREFIX}` stamps the site codes and the bad supplier name so the same fixture
  reloads on any run without colliding.
- Templated source: `artifact/PozSupplierSitesInt.csv`. Assembled zip:
  `SupplierSites_gold.zip` (rebuilt by `harness/build_artifact.py SupplierSites <prefix>`,
  or by the one-shot `harness/run_object.py SupplierSites`).

## Verification (read-only, via the ephemeral BIP relay)

Independent single-table reads (never a relayed multi-table join). Credential
role `fin_impl`.

**Good rows → base table `POZ_SUPPLIER_SITES_ALL_M`** — direct read by site code:

```sql
SELECT vendor_site_code, vendor_site_id, vendor_id
FROM   poz_supplier_sites_all_m
WHERE  vendor_site_code LIKE :PREFIX || 'RT-SITE-%';
```

Both good site codes must be present with a real `VENDOR_SITE_ID`.

**Bad row → interface error, absent from base** — direct read of the interface
table by load request id, joined to the rejections table:

```sql
SELECT i.vendor_site_code,
       i.vendor_site_interface_id,
       i.status,
       (SELECT LISTAGG(CASE WHEN r.attribute IS NOT NULL
                            THEN r.reject_lookup_code || ' [' || r.attribute || ']'
                            ELSE r.reject_lookup_code END, '; ')
               WITHIN GROUP (ORDER BY r.rejection_id)
        FROM   poz_supplier_int_rejections r
        WHERE  r.parent_table = 'POZ_SUPPLIER_SITES_INT'
        AND    r.parent_id    = i.vendor_site_interface_id) AS error_message
FROM   poz_supplier_sites_int i
WHERE  i.load_request_id = :LRID;
```

The bad site code must appear with `STATUS=REJECTED` and a non-null
`error_message`, and must be absent from the base read above.

Tables: interface `POZ_SUPPLIER_SITES_INT` (PK `VENDOR_SITE_INTERFACE_ID` — note:
NOT `SITE_INTERFACE_ID`, which the frozen-stack BIP query mis-named), base
`POZ_SUPPLIER_SITES_ALL_M`, rejections `POZ_SUPPLIER_INT_REJECTIONS`
(parent_table `POZ_SUPPLIER_SITES_INT`).

### Known issue — NULL vendor_site_id on the interface

`POZ_SUPPLIER_SITES_INT` can report a site `STATUS=PROCESSED` while leaving its own
`VENDOR_SITE_ID` NULL, so verifying "good" from the interface row is unreliable.
This fixture sidesteps that entirely: it reads the **base** table directly by
`vendor_site_code` and takes the base `vendor_site_id`. On the live proof below
the base read returned real ids for both good sites, so the NULL-interface-id
issue did not affect the verdict.

## How to run it

```bash
cd gold_regression/harness
python run_object.py SupplierSites            # discover -> build -> load -> verify (fresh prefix)
# or step by step:
python build_artifact.py SupplierSites <PREFIX>
python load_fbdi.py SupplierSites ../objects/SupplierSites/SupplierSites_gold.zip
python verify.py  SupplierSites <LOAD_REQUEST_ID> <PREFIX>
```

## Live evidence

**2026-07-19 — LIVE-PROVEN. PASS.**

Standalone load path only (no DMT database, no DMT code in the load path);
verification via the read-only BIP relay only.

| Field | Value |
|---|---|
| Date | 2026-07-19 |
| Prefix | `79717` |
| Load ESS request id (`loadAndImportData` result) | `9763210` |
| Terminal status (`getESSJobStatus`) | `SUCCEEDED` (terminal at 60s) |
| Credential role | `fin_impl` (SOAP load and BIP relay) |
| Discovered supplier / address / BU | `ABC Bank` / `ABC Bank US1` / `US1 Business Unit` (vendor_id 300000175345137) |

**Good sites → base table `POZ_SUPPLIER_SITES_ALL_M` (2/2):**

| VENDOR_SITE_CODE | VENDOR_SITE_ID | VENDOR_ID |
|---|---|---|
| `79717RT-SITE-G1` | `300000331544937` | `300000175345137` |
| `79717RT-SITE-G2` | `300000331544940` | `300000175345137` |

**Bad site → interface rejection, absent from base (1/1 REJECTED):**

| VENDOR_SITE_CODE | Rejection error |
|---|---|
| `79717RT-SITE-BAD` | `You must provide a valid value for either the VENDOR_ID or the VENDOR_NAME. [VENDOR_NAME]; A value is required. You must provide a value. [VENDOR_ID]` |

The bad row (SUPPLIER_NAME `79717NO SUCH SUPPLIER`, a supplier that does not
exist) landed in `POZ_SUPPLIER_SITES_INT` with `STATUS=REJECTED` and the above
`POZ_SUPPLIER_INT_REJECTIONS` error, and no row in `POZ_SUPPLIER_SITES_ALL_M`.
The final gold zip `SupplierSites_gold.zip` (prefix 79717) is kept in this directory.

### Field note that made the good rows pass (worth keeping)

A first run (prefix 25110, req 9763187) rejected BOTH good rows with:
"The address doesn't exist for the supplier. [PARTY_SITE_NAME]" and (for the
supplier first chosen, Lee Supplies) "This supplier profile is locked for editing
as a profile change request is pending approval." Two lessons baked into the
recipe: (1) column 4 is **PARTY_SITE_NAME**, an *existing* supplier address the
new site attaches to — it is not a free-text label; discover a real one. (2) A
supplier with a pending profile change request is locked and cannot take a new
site; the discovery query orders by `party_site_name` and the chosen supplier
(ABC Bank) was not locked. If a future pod returns a locked supplier first,
add an approval-state filter or reorder discovery.
