# SupplierSiteAssignments — object notes (gold regression)

One object = one FBDI zip = one load ESS job. SupplierSiteAssignments is one of
the five separate supplier-family objects (Suppliers, SupplierAddresses,
SupplierSites, SupplierSiteAssignments, SupplierContacts) — not a sub-object of
Suppliers.

The full, live-proven call library for this object is in `GOLD_README.md` in this
folder. Summary:

- **Load:** `loadAndImportData` on `{FUSION_URL}/fscmService/ErpIntegrationService`,
  DocumentAccount `prc/supplier/import`, `<typ:interfaceDetails>` `27`, JobName
  `/oracle/apps/ess/prc/poz/supplierImport,ImportSupplierSiteAssignments`,
  ParameterList `NEW,N`, auth role `fin_impl`. Poll the returned request id with
  `getESSJobStatus` to a terminal status.
- **FBDI member:** `PozSiteAssignmentsInt.csv`, 15 positional columns, no header.
  Key positions: 1 IMPORT_ACTION, 2 VENDOR_NAME, 3 VENDOR_SITE_CODE (an existing
  site), 4 PROCUREMENT_BUSINESS_UNIT_NAME (the site's proc BU),
  5 BUSINESS_UNIT_NAME (the CLIENT BU the site is assigned to), 6 BILL_TO_BU_NAME
  (same value as col 5). Column order from the proven generator
  `db/packages/dmt_poz_sup_site_assn_fbdi_gen_pkg.pkb.sql`.

## Portability — what an assignment links

A site assignment creates no new supplier or site. It links an **existing
supplier site** to a **client business unit** (the bill-to / sold-to BU allowed
to transact against that site). Every reference must already exist on the target
pod — discover them at load time, never hardcode ids:

1. an existing supplier **site** (VENDOR_NAME + VENDOR_SITE_CODE, owned by a
   procurement BU),
2. the site's **procurement business unit** (PROCUREMENT_BUSINESS_UNIT_NAME),
3. one or more **client business units** (BUSINESS_UNIT_NAME) the site is **not
   already assigned to**.

The gold recipe discovers a site plus two unassigned client BUs with one BIP
query (see GOLD_README.md). It creates only the NEW assignments; no `${PREFIX}` is
put on the good rows because the assignment's natural key is
`vendor_site_id + client BU` (both discovered).

## Gotchas learned

- **Only reuse a `(procurement BU → client BU)` pairing the pod already trusts.**
  A valid client BU for a given procurement BU is one that already appears in
  `POZ_SITE_ASSIGNMENTS_ALL_M` for that procurement BU. A client BU the setup does
  not enable would be rejected. Discovery filters on that, so the fixture is
  portable to any pod.
- **Interface `ASSIGNMENT_ID` stays NULL even when PROCESSED.** Do not verify
  "good" from the interface row. Read the base table
  `POZ_SITE_ASSIGNMENTS_ALL_M` directly by `vendor_site_id + client BU name` and
  take the base `ASSIGNMENT_ID`. (Same base-vs-interface issue as SupplierSites.)
- **Bad-row trigger:** an invalid/nonexistent client BU name (col 5/6) produces a
  deterministic rejection `You must provide a valid value. [BUSINESS_UNIT_NAME]`
  in `POZ_SITE_ASSIGNMENTS_INT` and never reaches the base table.

## Tables

- Interface: `POZ_SITE_ASSIGNMENTS_INT` (key `ASSIGNMENT_INTERFACE_ID`,
  `LOAD_REQUEST_ID` the selection key, `BUSINESS_UNIT_NAME`, `VENDOR_SITE_CODE`).
- Base: `POZ_SITE_ASSIGNMENTS_ALL_M` (`ASSIGNMENT_ID`, `VENDOR_SITE_ID`, `BU_ID`).
- Rejections: `POZ_SUPPLIER_INT_REJECTIONS`
  (parent_table `POZ_SITE_ASSIGNMENTS_INT`, `PARENT_ID` = `ASSIGNMENT_INTERFACE_ID`).

## Live proof

2026-07-19, prefix `54318`, load req `9763415` (SUCCEEDED): existing site
`US1 - Escheatment` (Escheatment Agency, vendor_site_id 300000287742475) assigned
to two previously-unassigned client BUs → `POZ_SITE_ASSIGNMENTS_ALL_M`
(`Sweden Business Unit` id 300000331545486, `UK Business Unit` id 300000331545488);
bad client BU `54318NO SUCH BU` → `POZ_SITE_ASSIGNMENTS_INT` rejection
`You must provide a valid value. [BUSINESS_UNIT_NAME]`, absent from base. Full
evidence in `GOLD_README.md`.
