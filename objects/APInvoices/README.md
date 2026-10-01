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

## Table-name vs FBDI-tab audit (backlog #90, 2026-10-01)

Backlog #90 asks whether every STG/TFM table name mirrors the FBDI CSV tab
(record type) it loads. The object model rule is "one object = one FBDI zip =
one tab per record type". AP Invoices is ONE zip (`ApInvoicesInterface.xlsm`)
with TWO CSV tabs; DMT models both with one STG + one TFM table each.

**The mapping (from the generator `DMT_AP_FBDI_GEN_PKG` + the catalog):**

| FBDI tab / CSV | Interface table | Source STG table | Source TFM table | Verdict |
|---|---|---|---|---|
| ApInvoicesInterface.csv | AP_INVOICES_INTERFACE | DMT_AP_INVOICES_INT_STG_TBL | DMT_AP_INVOICES_INT_TFM_TBL | ALIGNED |
| ApInvoiceLinesInterface.csv | AP_INVOICE_LINES_INTERFACE | DMT_AP_INVOICE_LINES_INT_STG_TBL | DMT_AP_INVOICE_LINES_INT_TFM_TBL | ALIGNED |

**Findings:**
1. **ALIGNED, no action.** Both tables mirror their FBDI tab and interface table
   name-for-name (the `_INT_` infix is DMT's standard "interface-staging" marker,
   not a drift). The generator spec-header already lists the correct two CSV
   filenames; no comment fix was required.
2. **No distributions tab (not a gap).** The Fusion AP FBDI has no distributions
   CSV — distributions are auto-created server-side from line-level data during
   import. So there is correctly no `DMT_AP_*_DISTS_*` table and no NOT-MODELED
   finding. This matches the generator header note "NO distributions CSV".

## History
- E2E LOADED confirmed working with OU-based grouping.
