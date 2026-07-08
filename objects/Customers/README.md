# Customers

## Status
E2E LOADED

## Pipeline
- Module: Financials
- FBDI Template: HzImpPartiesT.xlsm (7 sheets)
- Interface Tables: HZ_IMP_PARTIES_T, HZ_IMP_ADDRESSES_T, HZ_IMP_ADDRESSUSES_T, HZ_IMP_ACCTS_T, HZ_IMP_ACCTADDRESSES_T, HZ_IMP_ACCTADDRUSES_T, HZ_IMP_LOCATIONS_T
- UCM Account: ar/customerImport/import
- ESS Job: /oracle/apps/ess/cdm/foundation/bulkImport
- ParameterList: UNKNOWN -- needs verification
- Loader Type: SQLLOADER
- Auth User: fin_impl

## Sub-Objects
1. Parties
2. Locations
3. PartySites
4. PartySiteUses
5. Accounts
6. AccountSites
7. AccountSiteUses

## Code References
- STG Table DDL (Parties): `schema/tables/28_dmt_hz_parties_stg_tbl.sql`
- STG Table DDL (Locations): `schema/tables/29_dmt_hz_locations_stg_tbl.sql`
- STG Table DDL (PartySites): `schema/tables/30_dmt_hz_party_sites_stg_tbl.sql`
- STG Table DDL (PartySiteUses): `schema/tables/31_dmt_hz_party_site_uses_stg_tbl.sql`
- STG Table DDL (Accounts): `schema/tables/32_dmt_hz_accounts_stg_tbl.sql`
- STG Table DDL (AccountSites): `schema/tables/33_dmt_hz_acct_sites_stg_tbl.sql`
- STG Table DDL (AccountSiteUses): `schema/tables/34_dmt_hz_acct_site_uses_stg_tbl.sql`
- TFM Table DDL (Parties): `schema/tables/35_dmt_hz_parties_tfm_tbl.sql`
- TFM Table DDL (Locations): `schema/tables/36_dmt_hz_locations_tfm_tbl.sql`
- TFM Table DDL (PartySites): `schema/tables/37_dmt_hz_party_sites_tfm_tbl.sql`
- TFM Table DDL (PartySiteUses): `schema/tables/38_dmt_hz_party_site_uses_tfm_tbl.sql`
- TFM Table DDL (Accounts): `schema/tables/39_dmt_hz_accounts_tfm_tbl.sql`
- TFM Table DDL (AccountSites): `schema/tables/40_dmt_hz_acct_sites_tfm_tbl.sql`
- TFM Table DDL (AccountSiteUses): `schema/tables/41_dmt_hz_acct_site_uses_tfm_tbl.sql`
- Validator: `packages/validators/dmt_cust_validator_pkg.*`
- Transformer: `packages/transformers/dmt_cust_transform_pkg.*`
- FBDI Generator: `packages/generators/fbdi/customers/dmt_cust_fbdi_gen_pkg.*`
- Results/Reconciliation: `packages/reconciliation/dmt_cust_results_pkg.*`
- BIP Data Model/Report: `bip/Customers/`

## Reference Files
None in this folder.

## Known Issues
None currently.

## History
- E2E LOADED confirmed working. 7 sub-object pipeline validated.
- 2026-04-02: Regression test — 38L/0F (O2C pipeline). All customers + AR invoices LOADED. BIP reconciliation confirmed working.
