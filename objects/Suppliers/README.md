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
- ParameterList: NEW,N (no third argument) — see memory/project_suppliers.md
- Loader Type: SQLLOADER (LOAD_JOB_NAME is NULL — loadAndImportData handles the load internally)
- Auth User: calvin.roth (per-object override rows in DMT_ERP_INTERFACE_OPTIONS_TBL)
- BIP reconciliation key: filter the POZ_*_INT tables by LOAD_REQUEST_ID
  (IMPORT_REQUEST_ID is NULL when the import job errors; LOAD_REQUEST_ID is
  always populated)

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
- Results/Reconciliation: `db/packages/dmt_poz_sup_results_pkg.*` (one shared package; RECONCILE_BATCH takes p_cemli_code — the registry rows set RECON_HAS_CEMLI_ARG=Y)
- BIP Data Models/Reports: `bip/Suppliers/`, `bip/SupplierAddresses/`, `bip/SupplierSites/`, `bip/SupplierSiteAssignments/`, `bip/SupplierContacts/` — deployed to `/Custom/DMT2/{CEMLI}/` (this stack's catalog; never `/Custom/DMT/`)
- Report deploy tool: `scripts/deploy_supplier_bip_reports.py` + `DMT_BIP_DEPLOY_PKG.DEPLOY_RECON_REPORT`

## Reference Files
None in this folder (CTL files embedded in FBDI template).

## Known Issues
None currently.

## History
- Frozen stack: E2E LOADED confirmed working — five separate imports
  (Suppliers → Addresses → Sites → SiteAssignments → Contacts) validated
  against the Fusion demo instance.
- DMT2 Stage D phase 2 (2026-07-08): full live E2E through the work queue
  on run 270 / prefix 1143 — five work items, five zips, five ESS chains;
  every object DONE via the accounting gate; GOOD rows LOADED with Fusion
  ids, BAD rows FAILED with reportable [FUSION_ERROR]/[PRE_VALIDATION] text.
  BIP reconciliation reports live at /Custom/DMT2/{CEMLI}/.
