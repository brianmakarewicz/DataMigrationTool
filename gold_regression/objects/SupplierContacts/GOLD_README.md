# SupplierContacts — gold regression fixture

A standalone, reloadable FBDI fixture (2 good + 1 bad supplier contact) that
attaches new contacts to an **existing** supplier on the target pod via the ERP
Integration SOAP service (`loadAndImportData`, which loads the interface AND
chains **Import Supplier Contacts**), with read-only BIP verification against the
base and interface tables. No DMT tool code, no DMT database, is in the load path.

**Portable — no upstream dependency.** A supplier contact must attach to a
supplier that already exists. This fixture does **not** create a supplier first
and does **not** reference any supplier we loaded earlier. It **discovers an
existing, enabled supplier on the target pod at load time** and stamps that
supplier's name into the good rows. Only the contact identity (first/last name +
email) carries the fresh `${PREFIX}`, so the same fixture reloads on any pod
without colliding.

## The one CSV (FBDI, no header row, position-based)

`PozSupContactsInt.csv` — the supplier-contact interface layout, **89 columns**,
per `db/seed/dmt_upload_fbdi_metadata.sql` (`POZ_SUP_CONTACTS`) and the proven
byte-template `test/fbdi_zips/SupplierContacts_116.zip`. Only these positions are
populated:

| Position | Column | Value |
|---|---|---|
| 1 | IMPORT_ACTION | `CREATE` |
| 2 | VENDOR_NAME | **discovered existing supplier** (good rows) / a non-existent name (bad row) |
| 4 | FIRST_NAME | `Alice` / `Bob` / `Ghost` |
| 7 | LAST_NAME | `${PREFIX}RTConAliceG1` / `${PREFIX}RTConBobG2` / `${PREFIX}RTConBad1` |
| 10 | PRIMARY_ADMIN_CONTACT | `Y` |
| 11 | EMAIL_ADDRESS | `${PREFIX}rtcon.alice@good1.test` / `...bob@good2.test` / `...ghost@nowhere.test` |

Three rows:

| Row | VENDOR_NAME | LAST_NAME (natural key) | Purpose |
|---|---|---|---|
| GOOD-1 | `${SUPPLIER_NAME}` (discovered) | `${PREFIX}RTConAliceG1` | valid → base (a PERSON party) |
| GOOD-2 | `${SUPPLIER_NAME}` (discovered) | `${PREFIX}RTConBobG2` | valid → base (a PERSON party) |
| BAD-1  | `${PREFIX}DMT DOES NOT EXIST SUPPLIER` | `${PREFIX}RTConBad1` | rejected → interface |

The BAD row deliberately names a supplier that cannot exist, so **Import Supplier
Contacts** rejects it into `POZ_SUP_CONTACTS_INT` with the deterministic Fusion
error `You must provide a valid value for either the VENDOR_ID or the
VENDOR_NAME. [VENDOR_NAME]` and it never reaches a base party.

## The exact call

| Thing | Value |
|---|---|
| Endpoint | `{FUSION_URL}/fscmService/ErpIntegrationService` |
| Operation | `loadAndImportData` (SOAPAction `http://xmlns.oracle.com/apps/financials/commonModules/shared/model/erpIntegrationService/loadAndImportData`) |
| Auth | HTTP Basic, credential role `fin_impl` (connections.json) |
| UCM DocumentAccount | `prc/supplier/import` |
| ContentType | `ZIP` |
| `<typ:interfaceDetails>` | `26` (the Supplier Contact `SOURCE_ERP_OPTIONS_ID` from `db/seed/dmt_erp_interface_options_tbl.sql`, `ERP_INTERFACE_OPTIONS_ID` 26) |
| `<erp:JobName>` | `/oracle/apps/ess/prc/poz/supplierImport,ImportSupplierContacts` |
| `<erp:ParameterList>` | `NEW,N` |
| `<typ:notificationCode>` | `10` |

Note on JobName: the seed stores the import job with a semicolon —
`/oracle/apps/ess/prc/poz/supplierImport;ImportSupplierContacts`.
`loadAndImportData` requires the last semicolon replaced with a comma, giving
`/oracle/apps/ess/prc/poz/supplierImport,ImportSupplierContacts`.

**ImportSupplierContacts ParameterList — `NEW,N`** (same supplier-import family
convention as ImportSuppliers): arg 1 = `NEW` (import type / process new rows),
arg 2 = `N` (do not purge). No prefix or discovered id goes into the
ParameterList for this object — the good/bad rows are selected by the load.

## ESS orchestration (jobs in order)

1. **`loadAndImportData`** — one SOAP call that (a) base64-embeds the FBDI zip and
   uploads it to UCM under `prc/supplier/import`, (b) runs **Load File to
   Interface Tables** to unpack the zip into `POZ_SUP_CONTACTS_INT`, and (c)
   chains **Import Supplier Contacts** (`ImportSupplierContacts`) with
   `ParameterList=NEW,N`. It returns the **Load ESS request id** in `<result>`.
2. **`getESSJobStatus`** — poll the Load ESS request id every 60s until terminal
   (`SUCCEEDED` / `WARNING` / `FAILED` / `ERROR` / `EXPIRED`). On this pod the
   parent reaches `SUCCEEDED` once the chained import completes. `LOAD_REQUEST_ID`
   is stamped on every `POZ_SUP_CONTACTS_INT` row (good and bad) and is the
   selection key for the interface/rejection verify.

No further downstream program is required before verification.

## Discovery (run before build, read-only BIP)

One step, credential role `fin_impl`, picks a **standard, enabled** demo supplier
(numeric `SEGMENT1`, excludes our own `RT` suppliers), ordered by the
highest-numbered supplier so the pick is deterministic and portable:

```sql
SELECT * FROM (
  SELECT sv.vendor_name AS VNAME, sv.segment1 AS VNUM, sv.vendor_id AS VID
  FROM   poz_suppliers_v sv
  WHERE  sv.vendor_name IS NOT NULL
  AND    REGEXP_LIKE(sv.segment1, '^[0-9]+$')
  AND    sv.vendor_name NOT LIKE '%RT %' AND sv.vendor_name NOT LIKE '%RT-%'
  AND    NVL(sv.enabled_flag,'Y') = 'Y'
  ORDER BY TO_NUMBER(sv.segment1) DESC
) WHERE ROWNUM = 1
```

Discovered tokens stamped into the good rows: `${SUPPLIER_NAME}` (VENDOR_NAME
col 2), `${SUPPLIER_NUM}`, `${SUPPLIER_ID}` (kept for documentation; VENDOR_NAME
is what the import matches on).

**Data-quality gotcha learned live (why DESC ordering):** the lowest-numbered
legacy demo supplier on this pod, *Lee Supplies* (1252), is **locked for editing
by a pending supplier profile change request**. A new contact against it is
rejected with *"This supplier profile is locked for editing as a profile change
request is pending approval."* A one-shot probe load of a contact against twelve
different suppliers showed **11 of 12 accepted the contact** — only *Lee Supplies*
was locked. Ordering the discovery by `TO_NUMBER(segment1) DESC` selects the
newest standard supplier (here *St. Johns School*, 1493), which is editable. The
pending-change-request table is not exposed through the read-only BIP FSCM data
source, so the lock cannot be detected up front; picking the newest supplier
avoids the stale, legacy locked one deterministically.

## Verification (read-only, via the BIP relay — direct single-table reads)

Both directions are proven with **independent single-table reads**, never a
relayed multi-table join.

- **Good → base.** A supplier contact loads as a **PERSON party in
  `HZ_PARTIES`** keyed by the `PER_PARTY_ID` the import stamps on the interface
  row. The direct base read finds each good contact by its prefixed last name:

  ```sql
  SELECT p.person_last_name AS LAST_NAME, p.party_id AS CONTACT_ID,
         p.person_first_name AS FIRST_NAME
  FROM   hz_parties p
  WHERE  p.party_type = 'PERSON'
  AND    p.person_last_name LIKE '<prefix>RTCon%'
  ```

  Each good LAST_NAME present with a real `PARTY_ID` = pass. **This mirrors the
  deployed BIP data model `bip/SupplierContacts/query.sql`, which confirms base
  presence in `HZ_PARTIES` on `PER_PARTY_ID` / `PARTY_TYPE='PERSON'` — not in
  `POZ_SUPPLIER_CONTACTS`.** On this pod `POZ_SUPPLIER_CONTACTS` does **not**
  carry the newly imported contact for the PERSON party (it stays empty for the
  new `per_party_id`), so a base read through `POZ_SUPPLIER_CONTACTS` is a
  false negative. The person party in `HZ_PARTIES` is the base-table proof.

- **Bad → interface + absent from base.** Direct read of
  `POZ_SUP_CONTACTS_INT` by `LOAD_REQUEST_ID`, with the rejection text from
  `POZ_SUPPLIER_INT_REJECTIONS` (`parent_table='POZ_SUP_CONTACTS_INT'`,
  `parent_id = contact_interface_id`); and the base read above confirms the bad
  LAST_NAME is absent from `HZ_PARTIES`.

  ```sql
  SELECT i.last_name AS LAST_NAME, i.contact_interface_id AS CONTACT_INTERFACE_ID,
         (SELECT LISTAGG(CASE WHEN r.attribute IS NOT NULL
                              THEN r.reject_lookup_code || ' [' || r.attribute || ']'
                              ELSE r.reject_lookup_code END, '; ')
                 WITHIN GROUP (ORDER BY r.rejection_id)
          FROM   poz_supplier_int_rejections r
          WHERE  r.parent_table = 'POZ_SUP_CONTACTS_INT'
          AND    r.parent_id    = i.contact_interface_id) AS ERROR_MESSAGE
  FROM   poz_sup_contacts_int i
  WHERE  i.load_request_id = <load_request_id>
  ```

Tables: interface `POZ_SUP_CONTACTS_INT`, base `HZ_PARTIES` (PERSON party),
rejections `POZ_SUPPLIER_INT_REJECTIONS`.

## How to run it

```bash
cd gold_regression/harness
python run_object.py SupplierContacts                 # discover -> build -> load -> verify
# or step by step:
python build_artifact.py SupplierContacts <PREFIX>
python load_fbdi.py SupplierContacts ../objects/SupplierContacts/SupplierContacts_gold.zip
python verify.py SupplierContacts <LOAD_REQUEST_ID> <PREFIX>
```

## Live evidence

**2026-07-19 — LIVE-PROVEN. PASS.**

Standalone load path only (no DMT database, no DMT code in the load path);
verification via the read-only BIP relay only.

| Field | Value |
|---|---|
| Date | 2026-07-19 |
| Prefix | `89777` |
| Load ESS request id (`loadAndImportData` result) | `9763255` |
| Terminal status (`getESSJobStatus`) | `SUCCEEDED` (terminal at 60s) |
| Credential role | `fin_impl` (SOAP load and BIP relay) |
| Discovered supplier | `St. Johns School` (SEGMENT1 `1493`, vendor_id `300000324469533`) |
| Interface rows seen | 3 (2 PROCESSED, 1 REJECTED — all accounted for) |

**Good rows → base table `HZ_PARTIES` (PERSON party) (2/2):**

| LAST_NAME | FIRST_NAME | PARTY_ID |
|---|---|---|
| `89777RTConAliceG1` | `Alice` | `300000331545112` |
| `89777RTConBobG2` | `Bob` | `300000331545129` |

**Bad row → interface rejection, absent from base (1/1):**

| LAST_NAME | Rejection error |
|---|---|
| `89777RTConBad1` | `You must provide a valid value for either the VENDOR_ID or the VENDOR_NAME. [VENDOR_NAME]` (`POZ_SUPPLIER_INT_REJECTIONS`, parent_table `POZ_SUP_CONTACTS_INT`) |

The bad contact landed in `POZ_SUP_CONTACTS_INT` (load_request_id 9763255,
IMPORT_STATUS REJECTED) with the above rejection and no PERSON party in
`HZ_PARTIES`. Gold zip `SupplierContacts_gold.zip` (built at prefix 89777) kept
in this directory.

**First-attempt failure (prefix 90288, load req 9763190), diagnosed and fixed:**
the load reported SUCCEEDED but the two good contacts were REJECTED with *"This
supplier profile is locked for editing as a profile change request is pending
approval"* — the discovered supplier was *Lee Supplies* (1252), which is locked
by a pending change request. Re-ordering discovery to the highest-numbered
supplier fixed it. A second issue on that run was a false-negative base read:
the initial recipe confirmed base presence through `POZ_SUPPLIER_CONTACTS`, which
does not carry the newly imported PERSON contact on this pod; switching the base
read to `HZ_PARTIES` on the person party (matching the deployed BIP data model)
gave the correct positive result on the 89777 re-verify.
