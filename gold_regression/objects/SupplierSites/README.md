# SupplierSites — object notes (gold regression)

One object = one FBDI zip = one load ESS job. SupplierSites is one of the five
separate supplier-family objects (Suppliers, SupplierAddresses, SupplierSites,
SupplierSiteAssignments, SupplierContacts) — not a sub-object of Suppliers.

The full, live-proven call library for this object is in `GOLD_README.md` in this
folder. Summary:

- **Load:** `loadAndImportData` on `{FUSION_URL}/fscmService/ErpIntegrationService`,
  DocumentAccount `prc/supplier/import`, `<typ:interfaceDetails>` `25`, JobName
  `/oracle/apps/ess/prc/poz/supplierImport,ImportSupplierSites`, ParameterList
  `NEW,N`, auth role `fin_impl`. Poll the returned request id with
  `getESSJobStatus` to a terminal status.
- **FBDI member:** `PozSupplierSitesInt.csv`, 199 positional columns, no header.
  Key positions: 1 IMPORT_ACTION, 2 SUPPLIER_NAME, 3 PROCUREMENT_BU,
  4 PARTY_SITE_NAME (an existing supplier address), 5 VENDOR_SITE_CODE (the new
  site's natural key), 9 PAY_SITE_FLAG, 11 PURCHASING_SITE_FLAG.

## Portability — what a site attaches to

A supplier site is not standalone. It needs three references that must already
exist on the target pod (discover them at load time, never hardcode ids):

1. an existing **supplier** (SUPPLIER_NAME),
2. an existing supplier **address / party site** (PARTY_SITE_NAME) — the site
   sits on an address; without a real address the import rejects
   "The address doesn't exist for the supplier. [PARTY_SITE_NAME]",
3. a **procurement business unit** (PROCUREMENT_BU, by name).

The gold recipe discovers all three with one BIP query (see GOLD_README.md) and
creates only the NEW site codes (`${PREFIX}RT-SITE-*`).

## Gotchas learned

- **Interface PK is `VENDOR_SITE_INTERFACE_ID`**, not `SITE_INTERFACE_ID`. The
  frozen-stack BIP query (`ConversionTool/bip/SupplierSites/query.sql`) used the
  wrong name; the gold verify query uses `VENDOR_SITE_INTERFACE_ID` for the
  rejections join.
- **Known NULL-site-id issue:** `POZ_SUPPLIER_SITES_INT` can report
  `STATUS=PROCESSED` while its own `VENDOR_SITE_ID` stays NULL. Do not verify
  "good" from the interface row. Read the base table
  `POZ_SUPPLIER_SITES_ALL_M` directly by `vendor_site_code` and take the base
  `vendor_site_id`. (On the 2026-07-19 proof the base read returned real ids, so
  the issue did not bite.)
- **Locked supplier:** a supplier with a pending profile change request is locked
  ("This supplier profile is locked for editing…") and cannot take a new site.
  Discovery must not pick such a supplier.

## Tables

- Interface: `POZ_SUPPLIER_SITES_INT` (key `VENDOR_SITE_INTERFACE_ID`,
  natural keys `VENDOR_NAME` + `VENDOR_SITE_CODE`, `STATUS` PROCESSED/REJECTED).
- Base: `POZ_SUPPLIER_SITES_ALL_M` (`VENDOR_SITE_CODE`, `VENDOR_SITE_ID`,
  `VENDOR_ID`).
- Rejections: `POZ_SUPPLIER_INT_REJECTIONS`
  (parent_table `POZ_SUPPLIER_SITES_INT`, `PARENT_ID` = `VENDOR_SITE_INTERFACE_ID`).

## Live proof

2026-07-19, prefix `79717`, load req `9763210` (SUCCEEDED): good sites
`79717RT-SITE-G1`/`-G2` → `POZ_SUPPLIER_SITES_ALL_M`
(ids 300000331544937 / 300000331544940, vendor ABC Bank 300000175345137); bad
`79717RT-SITE-BAD` (nonexistent supplier) → `POZ_SUPPLIER_SITES_INT` REJECTED with
an invalid-supplier-reference rejection, absent from base. Full evidence in
`GOLD_README.md`.
