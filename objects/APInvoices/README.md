# AP Invoices

## Status
E2E LOADED

## Pipeline
- Module: Financials
- FBDI Template: ApInvoicesInterface.xlsm
- Interface Tables: AP_INVOICES_INTERFACE, AP_INVOICE_LINES_INTERFACE
- UCM Account: fin/payables/import
- ESS Job: /oracle/apps/ess/financials/payables/invoices/transactions
- ParameterList: Grouped by OU
- Loader Type: SQLLOADER
- Auth User: fin_impl
- Grouping: Grouped by OU

## Code References
- STG Table DDL (Invoices): `schema/tables/46_dmt_ap_invoices_int_stg_tbl.sql`
- STG Table DDL (Lines): `schema/tables/47_dmt_ap_invoice_lines_int_stg_tbl.sql`
- TFM Table DDL (Invoices): `schema/tables/48_dmt_ap_invoices_int_tfm_tbl.sql`
- TFM Table DDL (Lines): `schema/tables/49_dmt_ap_invoice_lines_int_tfm_tbl.sql`
- Validator: `packages/validators/dmt_ap_validator_pkg.*`
- Transformer: `packages/transformers/dmt_ap_transform_pkg.*`
- FBDI Generator: `packages/generators/fbdi/ap/dmt_ap_fbdi_gen_pkg.*`
- Results/Reconciliation: `packages/reconciliation/dmt_ap_results_pkg.*`
- BIP Data Model/Report: `bip/APInvoices/`

## Reference Files
None in this folder.

## Known Issues
None currently.

## History
- E2E LOADED confirmed working with OU-based grouping.
