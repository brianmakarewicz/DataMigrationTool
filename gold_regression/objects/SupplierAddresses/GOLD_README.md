# SupplierAddresses — gold regression fixture

A standalone, reloadable FBDI fixture (2 good + 1 bad supplier address) that loads
directly into Oracle Fusion via the ERP Integration SOAP service, with read-only
BIP verification against the base and interface tables. No DMT tool code, no DMT
database, is involved in the load path.

A supplier address attaches to an **existing** supplier. This fixture creates NO
supplier of its own and references NO supplier we loaded earlier. At load time it
discovers, via read-only BIP on the target pod, an existing active **and unlocked**
supplier and attaches two brand-new addresses (prefixed party-site names) to it.

## The exact call

| Thing | Value |
|---|---|
| Endpoint | `{FUSION_URL}/fscmService/ErpIntegrationService` |
| Operation | `loadAndImportData` (SOAPAction `http://xmlns.oracle.com/apps/financials/commonModules/shared/model/erpIntegrationService/loadAndImportData`) |
| Auth | HTTP Basic, credential role `fin_impl` in connections.json (the seed's stored auth user is `calvin.roth`, but `calvin.roth` gets a 401 on this SOAP service, so the harness authenticates as `fin_impl`) |
| UCM DocumentAccount | `prc/supplier/import` |
| ContentType | `ZIP` |
| `<typ:interfaceDetails>` | `56` (the SupplierAddresses `SOURCE_ERP_OPTIONS_ID` from `db/seed/dmt_erp_interface_options_tbl.sql`, business object "Supplier Address") |
| `<erp:JobName>` | `/oracle/apps/ess/prc/poz/supplierImport,ImportSupplierAddresses` |
| `<erp:ParameterList>` | `NEW,N` (same as the whole supplier import family: import mode NEW, purge=N) |
| `<typ:notificationCode>` | `10` |

Note on JobName: the seed stores the import job with a semicolon —
`/oracle/apps/ess/prc/poz/supplierImport;ImportSupplierAddresses`. `loadAndImportData`
requires the last semicolon replaced with a comma, giving
`/oracle/apps/ess/prc/poz/supplierImport,ImportSupplierAddresses`.

## ESS orchestration (jobs in order)

1. **loadAndImportData** (one SOAP call) does three things: base64-uploads the FBDI
   zip to UCM under `prc/supplier/import`, runs "Load File to Interface Tables" to
   unpack `PozSupAddressesInt.csv` into interface table `POZ_SUP_ADDRESSES_INT`, and
   chains the import job **Import Supplier Addresses** (`ImportSupplierAddresses`)
   with ParameterList `NEW,N`. The `<result>` element returns the **Load ESS
   request id**.
2. **Poll** the Load ESS request id with `getESSJobStatus` every 60 s until terminal
   (SUCCEEDED / WARNING / FAILED / ERROR / EXPIRED). It reached **SUCCEEDED** at 60 s
   on the live run.
3. The chained **Import Supplier Addresses** child request runs under its own request
   id (stamped on every interface row as `REQUEST_ID`). No further downstream program
   is required before verification — processed rows are already in the base table.

## Discovery (portability rules 6-8)

One read-only BIP discovery step, run against the target pod at load time:

- **EXISTING_SUPPLIER** — pick the lowest-numbered active, **unlocked** supplier that
  is not one of our own `RT` test suppliers:

  ```sql
  SELECT * FROM (
    SELECT sv.vendor_name AS VNAME, sv.segment1 AS VNUM, sv.party_id AS PID
    FROM   poz_suppliers_v sv
    WHERE  NVL(sv.enabled_flag,'Y') = 'Y'
    AND    NVL(sv.supplier_locked_flag,'N') = 'N'
    AND    REGEXP_LIKE(sv.segment1,'^[0-9]+$')
    AND    sv.vendor_name NOT LIKE '%RT %'
    AND    sv.vendor_name NOT LIKE '%RT-%'
    AND    sv.vendor_type_lookup_code IS NOT NULL
    ORDER BY TO_NUMBER(sv.segment1)
  ) WHERE ROWNUM = 1;
  ```

  It binds `${VENDOR_NAME}` (matched to the existing supplier in the CSV),
  `${VENDOR_NUM}`, and `${SUPPLIER_PARTY_ID}` (used only by the verify base read to
  scope party sites to that supplier's party).

  **Why `supplier_locked_flag = 'N'` matters (learned on the first live run):** if the
  chosen supplier has a pending profile change request, `POZ_SUPPLIERS_V.SUPPLIER_LOCKED_FLAG`
  is `'Y'` and every address for it is rejected with *"This supplier profile is locked
  for editing as a profile change request is pending approval."* On this demo pod the
  lowest-numbered supplier, "Lee Supplies" (1252), is locked. Filtering the flag makes
  discovery skip it and pick the next unlocked supplier ("Staffing Services", 1253),
  which is what lets the good rows reach the base table. This is a portable filter, not
  a hardcoded id.

## The FBDI artifact

- One CSV inside the zip: `PozSupAddressesInt.csv` (the FBDI control-file name Fusion
  expects). **No header row; 109 position-based columns per `db/seed/dmt_upload_fbdi_metadata.sql`
  object code `POZ_SUP_ADDR`.**
- Three rows, all `IMPORT_ACTION=CREATE`, attached to the discovered supplier via
  `VENDOR_NAME` (position 2):

  | Row | Party site name (pos 3) | COUNTRY (pos 5) | Purpose flag |
  |---|---|---|---|
  | GOOD-1 | `${PREFIX}RT-ADDR-G1` | `US` | `ORDERING_PURPOSE_FLAG=Y` (pos 36) |
  | GOOD-2 | `${PREFIX}RT-ADDR-G2` | `US` | `ORDERING_PURPOSE_FLAG=Y` (pos 36) |
  | BAD-1  | `${PREFIX}RT-ADDR-BAD1` | *(blank — the deterministic error)* | `ORDERING_PURPOSE_FLAG=Y` (pos 36) |

  Populated positions: 1 `IMPORT_ACTION`=CREATE, 2 `VENDOR_NAME`=`${VENDOR_NAME}`,
  3 `PARTY_SITE_NAME`=the new site name, 5 `COUNTRY`, 6 `ADDRESS_LINE1`, 18 `CITY`,
  19 `STATE`, 22 `POSTAL_CODE`, 36 `ORDERING_PURPOSE_FLAG`=Y.

- **CREATE semantics learned from the first live run** (Fusion told us in the rejections):
  - On a CREATE, the new site name goes in **`PARTY_SITE_NAME` (position 3)**.
    `PARTY_SITE_NAME_NEW` (position 4) **must be blank** on CREATE (it is the rename
    target for an UPDATE) — a value there gives *"The attribute must be blank when the
    action is create."*
  - **At least one purpose flag must be `Y`**: one of `RFQ_OR_BIDDING_PURPOSE_FLAG`
    (35), `ORDERING_PURPOSE_FLAG` (36), `REMIT_TO_PURPOSE_FLAG` (37). Omitting all three
    rejects the row.
- `${PREFIX}` is stamped onto the three `PARTY_SITE_NAME` values so the same fixture
  reloads on any run without colliding. The supplier `${VENDOR_NAME}` is discovered.
- Templated source: `artifact/PozSupAddressesInt.csv`. Assembled zip:
  `SupplierAddresses_gold.zip` (rebuilt by `harness/build_artifact.py SupplierAddresses <prefix>`
  or the whole run by `harness/run_object.py SupplierAddresses`).

## The BAD row and its deterministic Fusion rejection

BAD-1 is a well-formed CREATE against the same valid, unlocked supplier, with valid
site name and a purpose flag — the **only** thing wrong is a missing required
`COUNTRY`. It parses into `POZ_SUP_ADDRESSES_INT` and is rejected there by the
import job with exactly one rejection in `POZ_SUPPLIER_INT_REJECTIONS`:

> **A value is required. You must provide a value.**  `[COUNTRY]`

It is absent from the base table (`PARTY_SITE_ID` NULL, no `HZ_PARTY_SITES` row).

## Verification (read-only, via the ephemeral BIP relay)

Two INDEPENDENT single-table reads (no relayed multi-table join), credential role
`fin_impl`.

**Good rows → base table `HZ_PARTY_SITES`** (a supplier address is a party site on the
supplier's party). Scoped to the discovered supplier's party and this run's prefix:

```sql
SELECT ps.party_site_name, ps.party_site_id
FROM   hz_party_sites ps
WHERE  ps.party_id = <discovered SUPPLIER_PARTY_ID>
AND    ps.party_site_name LIKE '<PREFIX>' || 'RT-ADDR-%';
```
A row present with a real `PARTY_SITE_ID` for each good key = pass.

**Bad row → interface rejection, absent from base** (by the Load request id, with the
rejection joined on both `parent_id` and the child `request_id` so it can't pick up a
stale rejection from a prior load that reused the same interface id):

```sql
SELECT NVL(i.party_site_name, i.party_site_name_new) AS party_site_name,
       i.address_interface_id,
       (SELECT LISTAGG(CASE WHEN r.attribute IS NOT NULL
                            THEN r.reject_lookup_code || ' [' || r.attribute || ']'
                            ELSE r.reject_lookup_code END, '; ')
               WITHIN GROUP (ORDER BY r.rejection_id)
        FROM   poz_supplier_int_rejections r
        WHERE  r.parent_table = 'POZ_SUP_ADDRESSES_INT'
        AND    r.parent_id    = i.address_interface_id
        AND    r.request_id   = i.request_id) AS error_message
FROM   poz_sup_addresses_int i
WHERE  i.load_request_id = <Load request id>;
```
The bad key present with a non-null `error_message`, and absent from the base read = pass.

Tables: interface `POZ_SUP_ADDRESSES_INT` (PK `ADDRESS_INTERFACE_ID`, status
`IMPORT_STATUS`, keys `LOAD_REQUEST_ID` + child `REQUEST_ID`), base `HZ_PARTY_SITES`,
rejections `POZ_SUPPLIER_INT_REJECTIONS` (parent_table `POZ_SUP_ADDRESSES_INT`).

## How to run it

```bash
cd gold_regression/harness
python run_object.py SupplierAddresses               # discover -> build -> load -> poll -> verify (fresh prefix)
# or step by step:
python build_artifact.py SupplierAddresses <PREFIX>  # -> objects/SupplierAddresses/SupplierAddresses_gold.zip
python load_fbdi.py SupplierAddresses ../objects/SupplierAddresses/SupplierAddresses_gold.zip
python verify.py  SupplierAddresses <LOAD_REQUEST_ID> <PREFIX>
```

## Live evidence

**2026-07-19 — LIVE-PROVEN. PASS.**

Standalone load path only (no DMT database, no DMT code in the load path);
verification via the read-only BIP relay only.

| Field | Value |
|---|---|
| Date | 2026-07-19 |
| Prefix | `65733` |
| Discovered supplier | `Staffing Services` (segment1 1253, party_id 300000047414569, unlocked) |
| Load ESS request id (`loadAndImportData` result) | `9763266` |
| Chained Import Supplier Addresses child request id | `9763280` |
| Terminal status (`getESSJobStatus` on 9763266) | **SUCCEEDED** (terminal at 60 s) |
| Credential role | `fin_impl` (SOAP load and BIP relay) |
| Interface rows seen | 3 (all accounted for) |

**Good rows → base table `HZ_PARTY_SITES` (2/2 PROCESSED):**

| PARTY_SITE_NAME | PARTY_SITE_ID |
|---|---|
| `65733RT-ADDR-G1` | `300000331545164` |
| `65733RT-ADDR-G2` | `300000331545170` |

**Bad row → interface rejection, absent from base (1/1 REJECTED):**

| PARTY_SITE_NAME | Rejection error |
|---|---|
| `65733RT-ADDR-BAD1` | `A value is required. You must provide a value. [COUNTRY]` |

The bad row (missing COUNTRY) landed in `POZ_SUP_ADDRESSES_INT` with the above
`POZ_SUPPLIER_INT_REJECTIONS` error, `IMPORT_STATUS=REJECTED`, `PARTY_SITE_ID` NULL —
no row in `HZ_PARTY_SITES`. The final gold zip `SupplierAddresses_gold.zip` (prefix
65733) is kept in this directory.

### Earlier same-day live runs (diagnostic, not the promoted gold)

- **Prefix 77930, load req 9763192** — first attempt against the (then not-yet-filtered)
  lowest supplier "Lee Supplies", which is **locked**. All three rows rejected: the
  supplier-locked error plus the CREATE-semantics errors below. This run is what taught
  us the four fixes now baked into the fixture.
- **Prefix 88401, load req 9763206** — corrected CSV loaded against an unlocked supplier
  (Dell Inc.): 2/2 good addresses reached `HZ_PARTY_SITES` (ids 300000331544903,
  300000331544911), bad row rejected on missing COUNTRY. Confirmed the CSV fixes before
  the discovery filter was added.
