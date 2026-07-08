# AR Invoices

## Status
E2E LOADED

## Pipeline
- Module: Financials
- FBDI Template: RaInterfaceLinesAll.xlsm
- Interface Tables: RA_INTERFACE_LINES_ALL, RA_INTERFACE_DISTRIBUTIONS_ALL
- UCM Account: ar/autoInvoice/import
- ESS Job: /oracle/apps/ess/financials/receivables/transactions/autoInvoice
- ParameterList: 24-arg format with #NULL for empty args; see memory/project_c006_ar_invoices.md
- Loader Type: SQLLOADER
- Auth User: fin_impl
- Grouping: Grouped by BU+BatchSource

## Code References
- STG Table DDL (Lines): `schema/tables/42_dmt_ra_lines_stg_tbl.sql`
- STG Table DDL (Distributions): `schema/tables/43_dmt_ra_dists_stg_tbl.sql`
- TFM Table DDL (Lines): `schema/tables/44_dmt_ra_lines_tfm_tbl.sql`
- TFM Table DDL (Distributions): `schema/tables/45_dmt_ra_dists_tfm_tbl.sql`
- Validator: `packages/validators/dmt_ar_validator_pkg.*`
- Transformer: `packages/transformers/dmt_ar_transform_pkg.*`
- FBDI Generator: `packages/generators/fbdi/ar/dmt_ar_fbdi_gen_pkg.*`
- Results/Reconciliation: `packages/reconciliation/dmt_ar_results_pkg.*`
- BIP Data Model/Report: `bip/ARInvoices/`

## Reference Files
None in this folder.

## Known Issues
None currently.

## History
- E2E LOADED confirmed working with BU+BatchSource grouping.
- 24-arg ParameterList documented in memory/project_c006_ar_invoices.md.
