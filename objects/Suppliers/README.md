# Suppliers (supplier family — five sibling objects)

## Status
E2E LOADED (frozen stack); DMT2 live slice proven 2026-07-08 (run 270, prefix 1143)

## The family is FIVE SEPARATE OBJECTS

Suppliers, SupplierAddresses, SupplierSites, SupplierSiteAssignments and
SupplierContacts are five sibling objects, not one object with sub-parts.
Each one:

- generates its OWN FBDI zip (one CSV per zip),
- gets its OWN UCM upload (account `prc/supplier/import`) and its OWN
  `loadAndImportData` ESS chain (load job + chained import job),
- has its OWN row in DMT_PIPELINE_DEF_TBL (EXEC_PROC / RECON_PROC) and
  DMT_BIP_REPORT_TBL,
- reaches its OWN terminal outcome through the accounting gate.

They are sequenced by DEPENDS_ON in DMT_PIPELINE_DEF_TBL:
Suppliers → SupplierAddresses → SupplierSites → SupplierSiteAssignments,
with SupplierContacts depending only on Suppliers.

Contrast: PurchaseOrders is ONE object whose single zip contains four CSVs.
That multi-CSV-in-one-zip pattern does NOT apply to the supplier family.

## Pipeline (applies to each of the five objects)
- Module: Procurement
- Interface Tables: POZ_SUPPLIERS_INT, POZ_SUP_ADDRESSES_INT, POZ_SUPPLIER_SITES_INT, POZ_SITE_ASSIGNMENTS_INT, POZ_SUP_CONTACTS_INT
- UCM Account: prc/supplier/import
- ESS Job: /oracle/apps/ess/prc/poz/supplierImport,ImportSuppliers (each object's own submission)
- ParameterList: NEW,N (no third argument)
- Loader Type: SQLLOADER (LOAD_JOB_NAME is NULL — loadAndImportData handles the load internally)
- Auth User: calvin.roth (per-object override rows in DMT_ERP_INTERFACE_OPTIONS_TBL)
- BIP reconciliation: Contract v1 nine-column reports (backlog #217,
  2026-10-09), one per object, deployed alongside the V1 `SUP_*_DM` models
  (never overwritten): `DMT_SUP_RECON_V2_DM`, `DMT_SUP_ADDR_RECON_V2_DM`,
  `DMT_SUP_SITE_RECON_V2_DM`, `DMT_SUP_SITE_ASSN_RECON_V2_DM`,
  `DMT_SUP_CONT_RECON_V2_DM`. Six parameters (P_RUN_ID, P_LOAD_REQUEST_ID,
  P_IMPORT_ESS_ID, P_PREFIX, P_CHUNK_SIZE, P_AFTER_KEY), tie-safe keyset paging.
- Row selection: the POZ_*_INT row by LOAD_REQUEST_ID only (IMPORT_REQUEST_ID
  is NULL when the import job errors; LOAD_REQUEST_ID is always populated). The
  base row is reached from that interface row: POZ_SUPPLIERS by VENDOR_ID,
  HZ_PARTY_SITES by PARTY_SITE_ID, POZ_SUPPLIER_SITES_ALL_M by VENDOR_ID +
  VENDOR_SITE_CODE, POZ_SITE_ASSIGNMENTS_ALL_M by VENDOR_SITE_ID + BU name,
  HZ_PARTIES (PERSON) by PER_PARTY_ID. Base found = BASE/SUCCESS with the base
  id as FUSION_ID; otherwise INTERFACE/ERROR with the real
  POZ_SUPPLIER_INT_REJECTIONS text (or NULL, which leaves the row for the
  UNACCOUNTED sweep).
- Match key: RECORD_KEY = SOURCE_REF = the business key as sent, joined with
  `~` (Suppliers VENDOR_NAME~SEGMENT1; Addresses VENDOR_NAME~PARTY_SITE_NAME;
  Sites VENDOR_NAME~VENDOR_SITE_CODE; SiteAssignments
  VENDOR_NAME~VENDOR_SITE_CODE~BUSINESS_UNIT_NAME; Contacts
  VENDOR_NAME~FIRST_NAME~LAST_NAME), recorded as RECON_KEY_SQL on each
  DMT_BIP_REPORT_TBL row. No DFF carrier, so DMT_REFERENCE is NULL.

## The five objects
1. Suppliers
2. SupplierAddresses
3. SupplierSites
4. SupplierSiteAssignments
5. SupplierContacts

## Code References
- STG Table DDL (Suppliers): `db/tables/dmt_poz_suppliers_stg_tbl.sql`
- STG Table DDL (Addresses): `db/tables/dmt_poz_sup_addr_stg_tbl.sql`
- STG Table DDL (Sites): `db/tables/dmt_poz_sup_site_stg_tbl.sql`
- STG Table DDL (SiteAssignments): `db/tables/dmt_poz_sup_site_assn_stg_tbl.sql`
- STG Table DDL (Contacts): `db/tables/dmt_poz_sup_contacts_stg_tbl.sql`
- TFM Table DDL: `db/tables/dmt_poz_*_tfm_tbl.sql` (same five stems)
- Validators: `db/packages/dmt_poz_sup_validator_pkg.*`, `dmt_poz_sup_addr_validator_pkg.*`, `dmt_poz_sup_site_validator_pkg.*`, `dmt_poz_sup_site_assn_validator_pkg.*`, `dmt_poz_sup_cont_validator_pkg.*`
- Transformer: `db/packages/dmt_poz_sup_transform_pkg.*` (one package, five TRANSFORM_* procedures — one per object)
- FBDI Generators: `db/packages/dmt_poz_sup_fbdi_gen_pkg.*`, `dmt_poz_sup_addr_fbdi_gen_pkg.*`, `dmt_poz_sup_site_fbdi_gen_pkg.*`, `dmt_poz_sup_site_assn_fbdi_gen_pkg.*`, `dmt_poz_sup_cont_fbdi_gen_pkg.*`
- Results/Reconciliation: one package per object — `db/packages/dmt_poz_sup_results_pkg.*`, `dmt_poz_sup_addr_results_pkg.*`, `dmt_poz_sup_site_results_pkg.*`, `dmt_poz_sup_site_assn_results_pkg.*`, `dmt_poz_sup_cont_results_pkg.*`. Each reads its report through the shared fetch `DMT_RECON_CONTRACT_PKG.FETCH_ROWS` and applies it with static SQL; RECONCILE_BATCH keeps p_cemli_code (registry rows set RECON_HAS_CEMLI_ARG=Y) and rejects any other object's code.
- BIP Data Models/Reports: `bip/Suppliers/`, `bip/SupplierAddresses/`, `bip/SupplierSites/`, `bip/SupplierSiteAssignments/`, `bip/SupplierContacts/` — deployed to `/Custom/DMT2/{CEMLI}/` (this stack's catalog; never `/Custom/DMT/`)
- Report deploy tool: `scripts/deploy_recon_bip_reports.py` + `DMT_BIP_DEPLOY_PKG.DEPLOY_RECON_REPORT`

## Reference Files
None in this folder (CTL files embedded in FBDI template).

## Table-name vs FBDI-tab audit (backlog #90, 2026-10-01)

Backlog #90 asks whether every STG/TFM table name mirrors the FBDI CSV tab
(record type) it loads. The object-model rule is "one object = one FBDI zip =
one tab per record type". The supplier family is the clean case of that rule:
it is FIVE SEPARATE OBJECTS, so there are five zips, and each zip carries
exactly ONE CSV / one interface table / one STG table / one TFM table. There is
no one-tab-fed-by-two-tables normalization here (unlike Assets) and no
multi-CSV-in-one-zip bundling (unlike PurchaseOrders).

**The mapping (CSV names verified from the generated test zips in
`test/fbdi_zips/*_116.zip` — these are the names Fusion actually accepted on the
live Stage D run — plus the five `DMT_POZ_SUP*_FBDI_GEN_PKG` bodies and the
catalog):**

| Object (zip) | FBDI tab / CSV | Interface table | Source STG table | Source TFM table | Verdict |
|---|---|---|---|---|---|
| Suppliers | PoSupplierImport.csv | POZ_SUPPLIERS_INT | DMT_POZ_SUPPLIERS_STG_TBL | DMT_POZ_SUPPLIERS_TFM_TBL | ALIGNED (table stem = interface table) |
| SupplierAddresses | PozSupAddressesInt.csv | POZ_SUP_ADDRESSES_INT | DMT_POZ_SUP_ADDR_STG_TBL | DMT_POZ_SUP_ADDR_TFM_TBL | NAME-SHORTENED (ADDR = Addresses) |
| SupplierSites | PozSupplierSitesInt.csv | POZ_SUPPLIER_SITES_INT | DMT_POZ_SUP_SITE_STG_TBL | DMT_POZ_SUP_SITE_TFM_TBL | NAME-SHORTENED (SUP_SITE = Supplier Sites) |
| SupplierSiteAssignments | PozSiteAssignmentsInt.csv | POZ_SITE_ASSIGNMENTS_INT | DMT_POZ_SUP_SITE_ASSN_STG_TBL | DMT_POZ_SUP_SITE_ASSN_TFM_TBL | NAME-SHORTENED (SITE_ASSN = Site Assignments) |
| SupplierContacts | PozSupContactsInt.csv | POZ_SUP_CONTACTS_INT | DMT_POZ_SUP_CONTACTS_STG_TBL | DMT_POZ_SUP_CONTACTS_TFM_TBL | NAME-SHORTENED (SUP_CONTACTS = Supplier Contacts) |

**Why this is clean (no wrong-record-type risk):**
- Every STG/TFM table maps 1:1 to exactly one interface table and one CSV. The
  physical table stems (`POZ_SUPPLIERS`, `POZ_SUP_ADDR`, `POZ_SUP_SITE`,
  `POZ_SUP_SITE_ASSN`, `POZ_SUP_CONTACTS`) are the Fusion `POZ_*_INT` interface
  table names, shortened to fit the 30-byte object-name limit. "ADDR" for
  Addresses, "ASSN" for Assignments, and dropping the `_INT` suffix are
  abbreviations of the same record type, not a different record type.
- The earlier backlog-#90 worry (that an object might model the wrong record
  type) does not arise here: each DMT table is named after, and feeds, exactly
  the interface table its generator writes. There is nothing to disprove and
  nothing to flag as MISALIGNED.

**Findings (what was fixed vs noted):**
1. **FIXED (low-risk, doc-only):** four of the five generator package specs
   documented FBDI filenames that the generator does not actually emit —
   `dmt_poz_sup_addr_fbdi_gen_pkg.pks.sql` said `PoSupplierAddressImport.csv`,
   `dmt_poz_sup_site_fbdi_gen_pkg.pks.sql` said `PoSupplierSiteImport.csv`,
   `dmt_poz_sup_site_assn_fbdi_gen_pkg.pks.sql` said
   `PoSupplierSiteAssignmentImport.csv`, and
   `dmt_poz_sup_cont_fbdi_gen_pkg.pks.sql` said `PoSupplierContactImport.csv`.
   The package bodies' `C_CSV_FILE` constants (and the generated test zips)
   actually emit `PozSupAddressesInt.csv`, `PozSupplierSitesInt.csv`,
   `PozSiteAssignmentsInt.csv` and `PozSupContactsInt.csv`. The four spec
   headers were corrected to match the real emitted names. This is documentation
   only; no runtime change. (The Suppliers spec header already matched its body,
   `PoSupplierImport.csv`.)
2. **NOTED (not a defect, do NOT change):** the Suppliers zip emits
   `PoSupplierImport.csv`, which is a DMT-specific name rather than Oracle's
   canonical `PozSuppliersInt.csv` for the Supplier Import template. It is left
   as-is because this exact name loaded end-to-end on the live demo in Stage D
   (run 270) — the `ImportSuppliers` job accepted it — so it is proven, not
   broken. Renaming a proven, loading CSV for cosmetic Oracle-name parity is out
   of scope for a doc audit and would risk the proven load path.
3. **No physical rename.** As with Assets, renaming the STG/TFM tables to their
   full un-abbreviated spelling is NOT done under this item: the abbreviations
   are unambiguous, correct record types, and renaming would ripple across the
   five validators, the shared transform/results packages, the catalog, pipeline
   and upload seeds, views, and BIP models for no correctness gain.

## Known Issues
- None open for reconciliation. The former "SupplierSites LOADED with a NULL
  FUSION_VENDOR_SITE_ID" residue is gone: the V2 report reads the base id from
  POZ_SUPPLIER_SITES_ALL_M and a row is LOADED only with it (backlog #217).
- The match key is the business key, not a DMT-stamped reference: the supplier
  FBDIs carry no field DMT stamps today. Two rows of one load with the same
  business key would match each other's report rows; the transform's business
  keys are unique per load in practice.

## History
- Frozen stack: E2E LOADED confirmed working — five separate imports
  (Suppliers → Addresses → Sites → SiteAssignments → Contacts) validated
  against the Fusion demo instance.
- DMT2 Stage D phase 2 (2026-07-08): full live E2E through the work queue
  on run 270 / prefix 1143 — five work items, five zips, five ESS chains;
  every object DONE via the accounting gate; GOOD rows LOADED with Fusion
  ids, BAD rows FAILED with reportable [FUSION_ERROR]/[PRE_VALIDATION] text.
  BIP reconciliation reports live at /Custom/DMT2/{CEMLI}/.
