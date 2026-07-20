# SupplierContacts — object notes (gold regression)

FBDI object in the supplier-import family. Attaches contacts to an **existing**
supplier. See `GOLD_README.md` in this folder for the full, live-proven recipe:
ESS orchestration, ParameterList, discovery, verify SQL, and evidence.

## Quick facts

- **Type:** FBDI, one CSV `PozSupContactsInt.csv` (89 columns, no header row).
- **ERP interface options id / interfaceDetails:** `26`
  (`db/seed/dmt_erp_interface_options_tbl.sql`, business object "Supplier Contact").
- **UCM account:** `prc/supplier/import`.
- **Load call:** `loadAndImportData` (SOAP, `fin_impl`), which chains the import.
- **Import job:** `/oracle/apps/ess/prc/poz/supplierImport,ImportSupplierContacts`
  (seed stores it with a `;` before the job name; replace the last `;` with `,`).
- **ParameterList:** `NEW,N`.
- **Populated CSV positions:** 1 IMPORT_ACTION, 2 VENDOR_NAME, 4 FIRST_NAME,
  7 LAST_NAME, 10 PRIMARY_ADMIN_CONTACT, 11 EMAIL_ADDRESS.

## Portability

- **VENDOR_NAME (col 2) is discovered at load time** — an existing, enabled
  standard supplier on the target pod (`poz_suppliers_v`, numeric SEGMENT1,
  excludes our RT suppliers, ordered highest SEGMENT1 first). Never hardcoded,
  never a supplier we loaded earlier.
- Only the contact identity (LAST_NAME / FIRST_NAME / EMAIL_ADDRESS) carries the
  fresh `${PREFIX}`.

## Gotchas learned live (2026-07-19)

- **Locked suppliers reject new contacts.** A supplier with a pending profile
  change request (e.g. *Lee Supplies* 1252 on this pod) rejects a new contact
  with *"This supplier profile is locked for editing…"*. The pending-change table
  is not exposed via BIP, so discovery orders by highest SEGMENT1 to pick a newer,
  editable supplier. 11 of 12 probed suppliers accepted a contact; only the
  legacy locked one failed.
- **Base-table proof is the PERSON party in `HZ_PARTIES`**, keyed by the
  interface `PER_PARTY_ID` (`PARTY_TYPE='PERSON'`), matching the deployed BIP data
  model `bip/SupplierContacts/query.sql`. `POZ_SUPPLIER_CONTACTS` does **not**
  carry the newly imported PERSON contact on this pod — reading it is a false
  negative.

## Verify tables

- Interface: `POZ_SUP_CONTACTS_INT` (by `LOAD_REQUEST_ID`).
- Base: `HZ_PARTIES` (PERSON party, by prefixed `PERSON_LAST_NAME`).
- Rejections: `POZ_SUPPLIER_INT_REJECTIONS`
  (`parent_table='POZ_SUP_CONTACTS_INT'`).

## Bad-row pattern

VENDOR_NAME set to a non-existent supplier → **Import Supplier Contacts** rejects
into `POZ_SUP_CONTACTS_INT` with *"You must provide a valid value for either the
VENDOR_ID or the VENDOR_NAME. [VENDOR_NAME]"*, absent from base.

## Live-proven

2026-07-19, prefix `89777`, load req `9763255`, SUCCEEDED. 2/2 good →
`HZ_PARTIES` (party ids 300000331545112 / 300000331545129), bad → interface
rejection, absent from base. Discovered supplier *St. Johns School* (1493).
