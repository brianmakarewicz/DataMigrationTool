# SupplierSiteAssignments — gold regression fixture

A standalone, reloadable FBDI fixture (2 good site assignments + 1 bad) that loads
directly into Oracle Fusion via the ERP Integration SOAP service, with read-only
BIP verification against the base and interface tables. No DMT tool code, no DMT
database, is involved in the load path.

A supplier **site assignment** is not a top-level record and it creates no new
supplier or site. It links an **existing supplier site** (a row in
`POZ_SUPPLIER_SITES_ALL_M`, owned by a procurement business unit) to a **client
business unit** — the bill-to / sold-to BU that is allowed to transact against
that site. This fixture creates NEW assignments but borrows every reference —
the supplier, the site, the procurement BU, and the client BUs — from data that
already ships on the target pod, discovered at load time, so it runs on any demo
pod with no dependency on suppliers or sites we loaded earlier (portability rules
6-8). Nothing is stamped with `${PREFIX}` on the good rows because the natural key
of an assignment is `vendor_site_id + client_bu` — both discovered — not a
free-text code we invent. `${PREFIX}` is used only to make the BAD row's invalid
client-BU name unique per run.

## The exact call

| Thing | Value |
|---|---|
| Endpoint | `{FUSION_URL}/fscmService/ErpIntegrationService` |
| Operation | `loadAndImportData` (SOAPAction `.../erpIntegrationService/loadAndImportData`) |
| Auth | HTTP Basic, credential role `fin_impl` (connections.json). The seed's stored `FUSION_USERNAME` is `calvin.roth`, but this run uses `fin_impl` for both the SOAP load and the BIP relay. |
| UCM DocumentAccount | `prc/supplier/import` |
| ContentType | `ZIP` |
| `<typ:interfaceDetails>` | `27` (the Supplier Site Assignment `SOURCE_ERP_OPTIONS_ID` / `ERP_INTERFACE_OPTIONS_ID` from `db/seed/dmt_erp_interface_options_tbl.sql`) |
| `<erp:JobName>` | `/oracle/apps/ess/prc/poz/supplierImport,ImportSupplierSiteAssignments` |
| `<erp:ParameterList>` | `NEW,N` |
| `<typ:notificationCode>` | `10` |

Note on JobName: the seed stores the import job with a semicolon —
`/oracle/apps/ess/prc/poz/supplierImport;ImportSupplierSiteAssignments`.
`loadAndImportData` requires the last semicolon replaced with a comma, giving
`/oracle/apps/ess/prc/poz/supplierImport,ImportSupplierSiteAssignments`.

`loadAndImportData` returns the **Load ESS request id** in the `<result>`
element. Poll it with `getESSJobStatus` (same endpoint, SOAPAction
`.../getESSJobStatus`, `<typ:requestId>`) every 60s until terminal:
SUCCEEDED / WARNING / FAILED / ERROR / EXPIRED. `LOAD_REQUEST_ID` is stamped on
every `POZ_SITE_ASSIGNMENTS_INT` row even when a row is rejected, so it is the
selection key for interface/rejection verification.

## ESS orchestration (jobs in order)

1. **Load File to Interface Tables** and **Import Supplier Site Assignments**
   (`ImportSupplierSiteAssignments`) run as the single chained `loadAndImportData`
   call above. The returned request id is the LOAD request; the import runs as its
   chained child. When that request reaches SUCCEEDED, good rows are in the base
   table and rejected rows carry their errors — no separate downstream job is
   needed. `downstream_jobs` is empty for this object.

## Discovery (portability — run at load time on the TARGET pod)

One read-only BIP query finds a real, already-present supplier **site** plus two
distinct **client BUs that the site is not yet assigned to**. It only offers a
`(procurement BU → client BU)` pair as valid when that same pairing already exists
somewhere in `POZ_SITE_ASSIGNMENTS_ALL_M` on the pod — that is the reliable,
pod-agnostic way to know a client BU is actually enabled to transact against that
procurement BU (a client BU that the setup does not allow would be rejected by
Fusion). The chosen site must therefore have at least two such unassigned client
BUs available.

```sql
SELECT * FROM (
  SELECT vendor_name       AS SUPPLIER_NAME,
         vendor_id          AS SUPPLIER_VENDOR_ID,
         vendor_site_code   AS VENDOR_SITE_CODE,
         vendor_site_id     AS VENDOR_SITE_ID,
         proc_bu_name       AS PROC_BU,
         MAX(DECODE(rn,1,client_bu_name)) AS CBU1,
         MAX(DECODE(rn,2,client_bu_name)) AS CBU2
  FROM (
    WITH valid_client AS (
      SELECT DISTINCT s.prc_bu_id,
             a.bu_id   AS client_bu_id,
             b.bu_name AS client_bu_name
      FROM   poz_site_assignments_all_m a
      JOIN   poz_supplier_sites_all_m  s ON s.vendor_site_id = a.vendor_site_id
      JOIN   fun_all_business_units_v  b ON b.bu_id = a.bu_id
      WHERE  a.inactive_date IS NULL
    )
    SELECT ss.vendor_site_id, ss.vendor_site_code,
           sv.vendor_name, sv.vendor_id,
           pbu.bu_name AS proc_bu_name,
           vc.client_bu_name,
           ROW_NUMBER() OVER (PARTITION BY ss.vendor_site_id
                              ORDER BY vc.client_bu_name) rn,
           COUNT(*)     OVER (PARTITION BY ss.vendor_site_id) navail
    FROM   poz_supplier_sites_all_m ss
    JOIN   poz_suppliers_v          sv  ON sv.vendor_id = ss.vendor_id
    JOIN   fun_all_business_units_v pbu ON pbu.bu_id = ss.prc_bu_id
    JOIN   valid_client vc ON vc.prc_bu_id = ss.prc_bu_id
    WHERE  NVL(ss.inactive_date, SYSDATE+1) > SYSDATE
    AND    sv.vendor_name    NOT LIKE '%RT %'
    AND    sv.vendor_name    NOT LIKE '%RT-%'
    AND    ss.vendor_site_code NOT LIKE '%RT-SITE%'
    AND    NOT EXISTS (SELECT 1 FROM poz_site_assignments_all_m x
                       WHERE x.vendor_site_id = ss.vendor_site_id
                       AND   x.bu_id = vc.client_bu_id
                       AND   x.inactive_date IS NULL)
  )
  WHERE navail >= 2
  GROUP BY vendor_name, vendor_id, vendor_site_code, vendor_site_id, proc_bu_name
  HAVING MAX(navail) >= 2
  ORDER BY vendor_site_id DESC
) WHERE ROWNUM = 1;
```

Discovered tokens stamped into the fixture:

| Token | Meaning | Example (run below) |
|---|---|---|
| `${SUPPLIER_NAME}` | existing supplier that owns the site | (see live evidence) |
| `${VENDOR_SITE_CODE}` | existing supplier site the assignment attaches to | (see live evidence) |
| `${PROC_BU}` | the site's procurement business unit (by name) | (see live evidence) |
| `${CBU1}`, `${CBU2}` | two client BUs the site is NOT yet assigned to (good rows) | (see live evidence) |
| `${SUPPLIER_VENDOR_ID}`, `${VENDOR_SITE_ID}` | ids (used by the base-table verify read) | — |

## The FBDI artifact

- One CSV inside the zip: `PozSiteAssignmentsInt.csv` (FBDI control-file name
  Fusion expects). **No header row; position-based, 15 columns per the CTL.**
  Column order taken from the proven generator
  `db/packages/dmt_poz_sup_site_assn_fbdi_gen_pkg.pkb.sql`:

  | Col | Field | Value |
  |---|---|---|
  | 1 | IMPORT_ACTION | `CREATE` |
  | 2 | VENDOR_NAME | `${SUPPLIER_NAME}` (discovered) |
  | 3 | VENDOR_SITE_CODE | `${VENDOR_SITE_CODE}` (discovered existing site) |
  | 4 | PROCUREMENT_BUSINESS_UNIT_NAME | `${PROC_BU}` (the site's proc BU) |
  | 5 | BUSINESS_UNIT_NAME (the CLIENT BU) | `${CBU1}` / `${CBU2}` (good) / `${PREFIX}NO SUCH BU` (bad) |
  | 6 | BILL_TO_BU_NAME | same as col 5 |
  | 7 | SHIP_TO_LOCATION_CODE | (empty) |
  | 8 | BILL_TO_LOCATION_CODE | (empty) |
  | 9 | ALLOW_AWT_FLAG | (empty) |
  | 10 | AWT_GROUP_NAME | (empty) |
  | 11 | ACCTS_PAY_CONCAT_SEGMENTS | (empty) |
  | 12 | PREPAY_CONCAT_SEGMENTS | (empty) |
  | 13 | FUTURE_DATED_CONCAT_SEGMENTS | (empty) |
  | 14 | DISTRIBUTION_SET_NAME | (empty) |
  | 15 | INACTIVE_DATE | (empty) |

- Three rows, all `IMPORT_ACTION=CREATE`:
  - GOOD-1 assigns the discovered site to client BU `${CBU1}`
  - GOOD-2 assigns the same site to client BU `${CBU2}`
  - BAD-1  assigns the same site to client BU `${PREFIX}NO SUCH BU`
    (no such business unit exists → deterministic Fusion rejection: invalid /
    missing client business unit reference reaching `POZ_SITE_ASSIGNMENTS_INT`)
- `${PREFIX}` stamps only the bad client-BU name so the same fixture reloads on
  any run without colliding. The good rows carry no prefix — their natural key is
  the discovered `vendor_site_id + client BU`.
- Templated source: `artifact/PozSiteAssignmentsInt.csv`. Assembled zip:
  `SupplierSiteAssignments_gold.zip` (rebuilt by
  `harness/build_artifact.py SupplierSiteAssignments <prefix>`, or by the one-shot
  `harness/run_object.py SupplierSiteAssignments`).

## Verification (read-only, via the ephemeral BIP relay)

Independent single-table reads (never a relayed multi-table join). Credential
role `fin_impl`.

**Good rows → base table `POZ_SITE_ASSIGNMENTS_ALL_M`** — direct read by the
discovered `vendor_site_id` and the two client BU names:

```sql
SELECT b.bu_name AS business_unit_name,
       a.assignment_id,
       a.vendor_site_id
FROM   poz_site_assignments_all_m a
JOIN   fun_all_business_units_v   b ON b.bu_id = a.bu_id
WHERE  a.vendor_site_id = <discovered VENDOR_SITE_ID>
AND    a.inactive_date IS NULL
AND    b.bu_name IN ('<CBU1>', '<CBU2>');
```

Both client BUs must be present with a real `ASSIGNMENT_ID`. (Note: the interface
row leaves its own `ASSIGNMENT_ID` NULL even when PROCESSED, so verification reads
the **base** table directly, never the interface's `assignment_id`.)

**Bad row → interface error, absent from base** — direct read of the interface
table by load request id, joined to the rejections table:

```sql
SELECT i.business_unit_name,
       i.assignment_interface_id,
       i.vendor_site_code,
       (SELECT LISTAGG(CASE WHEN r.attribute IS NOT NULL
                            THEN r.reject_lookup_code || ' [' || r.attribute || ']'
                            ELSE r.reject_lookup_code END, '; ')
               WITHIN GROUP (ORDER BY r.rejection_id)
        FROM   poz_supplier_int_rejections r
        WHERE  r.parent_table = 'POZ_SITE_ASSIGNMENTS_INT'
        AND    r.parent_id    = i.assignment_interface_id) AS error_message
FROM   poz_site_assignments_int i
WHERE  i.load_request_id = :LRID;
```

The bad client-BU name must appear with a non-null `error_message`, and must be
absent from the base read above (it never resolves to a base assignment).

Tables: interface `POZ_SITE_ASSIGNMENTS_INT` (PK `ASSIGNMENT_INTERFACE_ID`), base
`POZ_SITE_ASSIGNMENTS_ALL_M`, rejections `POZ_SUPPLIER_INT_REJECTIONS`
(parent_table `POZ_SITE_ASSIGNMENTS_INT`). All confirmed against the deployed DMT
data model `bip/SupplierSiteAssignments/SUP_SITE_ASSN_DM.xdm`.

## How to run it

```bash
cd gold_regression/harness
python run_object.py SupplierSiteAssignments        # discover -> build -> load -> verify
# or step by step:
python build_artifact.py SupplierSiteAssignments <PREFIX>
python load_fbdi.py SupplierSiteAssignments ../objects/SupplierSiteAssignments/SupplierSiteAssignments_gold.zip
python verify.py  SupplierSiteAssignments <LOAD_REQUEST_ID> <PREFIX>
```

## Live evidence

**2026-07-19 — LIVE-PROVEN. PASS.**

Standalone load path only (no DMT database, no DMT code in the load path);
verification via the read-only BIP relay only. Passed on the first live run.

| Field | Value |
|---|---|
| Date | 2026-07-19 |
| Prefix | `54318` (used only for the bad row's invalid client-BU name) |
| Load ESS request id (`loadAndImportData` result) | `9763415` |
| Terminal status (`getESSJobStatus`) | `SUCCEEDED` (terminal at 60s) |
| Credential role | `fin_impl` (SOAP load and BIP relay) |
| Discovered supplier / site / proc BU | `Escheatment Agency` / `US1 - Escheatment` / `US1 Business Unit` (vendor_id 300000287742453, vendor_site_id 300000287742475) |
| Discovered client BUs (good rows) | `Sweden Business Unit` (CBU1), `UK Business Unit` (CBU2) |

**Good assignments → base table `POZ_SITE_ASSIGNMENTS_ALL_M` (2/2):**

| Client BU (BUSINESS_UNIT_NAME) | ASSIGNMENT_ID | VENDOR_SITE_ID |
|---|---|---|
| `Sweden Business Unit` | `300000331545486` | `300000287742475` |
| `UK Business Unit` | `300000331545488` | `300000287742475` |

**Bad assignment → interface rejection, absent from base (1/1):**

| Client BU | Rejection error |
|---|---|
| `54318NO SUCH BU` | `You must provide a valid value. [BUSINESS_UNIT_NAME]` |

The bad row (client BU `54318NO SUCH BU`, a business unit that does not exist)
landed in `POZ_SITE_ASSIGNMENTS_INT` with the above `POZ_SUPPLIER_INT_REJECTIONS`
error and never resolved to a base assignment (absent from
`POZ_SITE_ASSIGNMENTS_ALL_M`). Both good rows attached the existing site to a
client BU it was not previously assigned to, each producing a real base
`ASSIGNMENT_ID`. The final gold zip `SupplierSiteAssignments_gold.zip`
(prefix 54318) is kept in this directory.

### Field notes worth keeping

- The **client BU** is FBDI column 5 (`BUSINESS_UNIT_NAME`), and column 6
  (`BILL_TO_BU_NAME`) is set to the same value. This is the BU allowed to
  transact against the site — not the site's own procurement BU (column 4).
- Portability hinges on only offering a `(procurement BU → client BU)` pairing
  that already exists somewhere in `POZ_SITE_ASSIGNMENTS_ALL_M` on the pod. A
  client BU the setup does not enable for that procurement BU would be rejected
  by Fusion, so "reuse a pairing the pod already trusts" is the reliable,
  pod-agnostic filter. The chosen site must have at least two such unassigned
  client BUs so both good rows land distinctly.
- The interface row's own `ASSIGNMENT_ID` stays NULL even for PROCESSED rows, so
  the good-row proof reads the **base** table directly by
  `vendor_site_id + client BU name`, never the interface's `assignment_id`
  (same base-vs-interface gotcha the SupplierSites fixture documents).
