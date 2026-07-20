# SupplierAddresses (gold regression object)

Import Supplier Addresses — part of the Supplier import family. One FBDI zip, one
CSV (`PozSupAddressesInt.csv`), one load ESS job that chains `ImportSupplierAddresses`.
A supplier address is a **party site** created on an existing supplier's party — this
fixture creates no supplier and depends on none we loaded; it discovers an existing
active, unlocked supplier at load time and attaches new addresses to it. See
`GOLD_README.md` in this folder for the full proven call recipe, ParameterList,
discovery query, verify SQL and live evidence. This file records the durable learnings.

## Status

**GOLD — live-proven 2026-07-19 (prefix 65733, load req 9763266, child import req
9763280).** 2 good → base `HZ_PARTY_SITES` (ids 300000331545164 / 300000331545170);
1 bad (missing `COUNTRY`) → `POZ_SUP_ADDRESSES_INT` with a `POZ_SUPPLIER_INT_REJECTIONS`
error, absent from base. Attached to discovered supplier "Staffing Services" (1253).

## Object shape

- Type: FBDI, module Procurement. `interfaceDetails` (ERP_INTERFACE_OPTIONS_ID) = **56**
  (business object "Supplier Address"). UCM account `prc/supplier/import`.
- Import job: `/oracle/apps/ess/prc/poz/supplierImport,ImportSupplierAddresses`
  (seed stores `;`; replace the last `;` with `,` for `loadAndImportData`).
- ParameterList: `NEW,N` — the same two args the whole supplier import family uses
  (import mode NEW, purge=N).
- CSV: `PozSupAddressesInt.csv`, **109 headerless position-based columns** (object code
  `POZ_SUP_ADDR` in `db/seed/dmt_upload_fbdi_metadata.sql`). Key positions: 1
  `IMPORT_ACTION`, 2 `VENDOR_NAME`, 3 `PARTY_SITE_NAME`, 4 `PARTY_SITE_NAME_NEW`, 5
  `COUNTRY`, 6 `ADDRESS_LINE1`, 18 `CITY`, 19 `STATE`, 22 `POSTAL_CODE`, 35–37 the three
  purpose flags (`RFQ_OR_BIDDING` / `ORDERING` / `REMIT_TO`).
- Interface table: `POZ_SUP_ADDRESSES_INT` (PK `ADDRESS_INTERFACE_ID`, status
  `IMPORT_STATUS`, keys `LOAD_REQUEST_ID` + chained child `REQUEST_ID`, populated
  `PARTY_SITE_ID` on success).
- Base table: `HZ_PARTY_SITES` (the address is a party site; key it on the supplier's
  `PARTY_ID` + prefixed `PARTY_SITE_NAME`).
- Rejections: `POZ_SUPPLIER_INT_REJECTIONS` (parent_table `POZ_SUP_ADDRESSES_INT`,
  parent_id = `ADDRESS_INTERFACE_ID`; also filter `request_id` = the child import
  request id, because `parent_id` values are reused across sibling supplier interface
  tables and across prior loads).

## Learnings (new, from building the gold fixture)

- **CREATE puts the site name in `PARTY_SITE_NAME` (col 3); `PARTY_SITE_NAME_NEW` (col 4)
  must be blank on CREATE.** Col 4 is the rename target used only on UPDATE. A value in
  col 4 on a CREATE rejects with *"The attribute must be blank when the action is
  create."* and col 3 blank rejects with *"A value is required … [PARTY_SITE_NAME]."*
- **At least one purpose flag must be `Y`.** One of `RFQ_OR_BIDDING_PURPOSE_FLAG` (35),
  `ORDERING_PURPOSE_FLAG` (36), `REMIT_TO_PURPOSE_FLAG` (37). Omitting all three rejects
  every row with *"At least one of the following must be Y …"*. The fixture sets
  `ORDERING_PURPOSE_FLAG=Y` on all rows.
- **The chosen supplier must not be locked.** If a supplier has a pending profile change
  request, `POZ_SUPPLIERS_V.SUPPLIER_LOCKED_FLAG='Y'` and every address for it is
  rejected with *"This supplier profile is locked for editing as a profile change
  request is pending approval."* On this demo pod the lowest-numbered supplier,
  "Lee Supplies" (1252), is locked, so discovery **must** filter
  `NVL(supplier_locked_flag,'N')='N'`. This is a portable filter, not a hardcoded id.
- **Auth for the standalone SOAP load is `fin_impl`, not `calvin.roth`.** The seed's
  stored `FUSION_USERNAME` is `calvin.roth`, but that user returns HTTP 401 on the ERP
  Integration SOAP service; the harness loads and runs the BIP relay as `fin_impl`.
- **Deterministic bad row = missing `COUNTRY`.** On an otherwise well-formed CREATE
  against a valid unlocked supplier, blanking `COUNTRY` (col 5) yields exactly one
  rejection, *"A value is required. You must provide a value. [COUNTRY]"*, in
  `POZ_SUP_ADDRESSES_INT`, and the row never reaches `HZ_PARTY_SITES`.
- **No downstream program needed.** `loadAndImportData` chains the import; once the load
  request reaches SUCCEEDED (60 s here), processed addresses are already party sites in
  the base table. Verify immediately.

## Verify SQL

Good (base): `SELECT ps.party_site_name, ps.party_site_id FROM hz_party_sites ps WHERE
ps.party_id = <discovered SUPPLIER_PARTY_ID> AND ps.party_site_name LIKE '<PREFIX>' ||
'RT-ADDR-%';`

Bad (interface + rejection, by load request id): read `POZ_SUP_ADDRESSES_INT WHERE
load_request_id = <load req>` and LISTAGG the `POZ_SUPPLIER_INT_REJECTIONS` rows joined
on `parent_id = address_interface_id AND request_id = i.request_id`. See `GOLD_README.md`
for the exact statements.
