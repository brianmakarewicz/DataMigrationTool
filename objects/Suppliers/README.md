# Suppliers

## Status
E2E LOADED

## Pipeline
- Module: Procurement
- FBDI Template: PozSuppliersInt.xlsm (5 sheets: Suppliers, Addresses, Sites, SiteAssignments, Contacts)
- Interface Tables: POZ_SUPPLIERS_INT, POZ_SUPPLIER_ADDRESSES_INT, POZ_SUPPLIER_SITES_INT, POZ_SUP_SITE_ASSIGNMENTS_INT, POZ_SUP_CONTACTS_INT
- UCM Account: prc/supplier/import
- ESS Job: /oracle/apps/ess/prc/poz/suppImport
- ParameterList: See memory/project_c001_suppliers.md
- Loader Type: SQLLOADER
- Auth User: calvin.roth

## Sub-Objects
1. Suppliers
2. SupplierAddresses
3. SupplierSites
4. SupplierSiteAssignments
5. SupplierContacts

## Code References
- STG Table DDL (Suppliers): `schema/tables/05_dmt_poz_suppliers_stg_tbl.sql`
- STG Table DDL (Addresses): `schema/tables/08_dmt_poz_sup_addr_stg_tbl.sql`
- STG Table DDL (Sites): `schema/tables/06_dmt_poz_sup_site_stg_tbl.sql`
- STG Table DDL (SiteAssignments): `schema/tables/09_dmt_poz_sup_site_assn_stg_tbl.sql`
- STG Table DDL (Contacts): `schema/tables/07_dmt_poz_sup_contacts_stg_tbl.sql`
- TFM Table DDL (Suppliers): `schema/tables/13_dmt_poz_suppliers_tfm_tbl.sql`
- TFM Table DDL (Addresses): `schema/tables/14_dmt_poz_sup_addr_tfm_tbl.sql`
- TFM Table DDL (Sites): `schema/tables/15_dmt_poz_sup_site_tfm_tbl.sql`
- TFM Table DDL (SiteAssignments): `schema/tables/16_dmt_poz_sup_site_assn_tfm_tbl.sql`
- TFM Table DDL (Contacts): `schema/tables/17_dmt_poz_sup_contacts_tfm_tbl.sql`
- Validators: `packages/validators/dmt_poz_sup_validator_pkg.*`, `dmt_poz_sup_addr_validator_pkg.*`, `dmt_poz_sup_site_validator_pkg.*`, `dmt_poz_sup_site_assn_validator_pkg.*`, `dmt_poz_sup_cont_validator_pkg.*`
- Transformer: `packages/transformers/dmt_poz_sup_transform_pkg.*`
- FBDI Generators: `packages/generators/fbdi/suppliers/dmt_poz_sup_fbdi_gen_pkg.*`, `dmt_poz_sup_addr_fbdi_gen_pkg.*`, `dmt_poz_sup_site_fbdi_gen_pkg.*`, `dmt_poz_sup_site_assn_fbdi_gen_pkg.*`, `dmt_poz_sup_cont_fbdi_gen_pkg.*`
- Results/Reconciliation: `packages/reconciliation/dmt_poz_sup_results_pkg.*`
- BIP Data Models/Reports: `bip/Suppliers/`, `bip/SupplierAddresses/`, `bip/SupplierSites/`, `bip/SupplierSiteAssignments/`, `bip/SupplierContacts/`

## Reference Files
None in this folder (CTL files embedded in FBDI template).

## Known Issues
None currently.

## History
- E2E LOADED confirmed working. 5-import sequential pipeline (Suppliers → Addresses → Sites → SiteAssignments → Contacts) validated against Fusion demo instance.
- BIP reconciliation key documented in memory/project_c001_suppliers.md.
