# Purchase Orders

## Status
E2E ACCEPTED (LOADED)

## Pipeline
- Module: Procurement
- FBDI Template: PoHeadersInterfaceOrder.xlsm
- Interface Tables: PO_HEADERS_INTERFACE, PO_LINES_INTERFACE, PO_LINE_LOCATIONS_INTERFACE, PO_DISTRIBUTIONS_INTERFACE
- UCM Account: prc/purchaseOrder/import
- ESS Job: ImportSPOJob
- ParameterList: 9-arg format; see memory/project_c004_purchase_orders.md
- Loader Type: SQLLOADER
- Auth User: calvin.roth
- Grouping: Grouped by PRC_BU_NAME

## Code References
- STG Table DDL (Headers): `schema/tables/18_dmt_po_headers_int_stg_tbl.sql`
- STG Table DDL (Lines): `schema/tables/19_dmt_po_lines_int_stg_tbl.sql`
- STG Table DDL (LineLocations): `schema/tables/20_dmt_po_line_locs_int_stg_tbl.sql`
- STG Table DDL (Distributions): `schema/tables/21_dmt_po_dists_int_stg_tbl.sql`
- TFM Table DDL (Headers): `schema/tables/22_dmt_po_headers_int_tfm_tbl.sql`
- TFM Table DDL (Lines): `schema/tables/23_dmt_po_lines_int_tfm_tbl.sql`
- TFM Table DDL (LineLocations): `schema/tables/24_dmt_po_line_locs_int_tfm_tbl.sql`
- TFM Table DDL (Distributions): `schema/tables/25_dmt_po_dists_int_tfm_tbl.sql`
- Validator: `packages/validators/dmt_po_validator_pkg.*`
- Transformer: `packages/transformers/dmt_po_transform_pkg.*`
- FBDI Generator: `packages/generators/fbdi/po/dmt_po_fbdi_gen_pkg.*`
- Results/Reconciliation: `packages/reconciliation/dmt_po_results_pkg.*`
- BIP Data Model/Report: `bip/PurchaseOrders/`

## Reference Files
None in this folder.

## Known Issues
None currently. Multi-BU grouping working correctly.

## History
- E2E ACCEPTED (LOADED) confirmed. Grouped FBDI pattern validated.
- 9-arg ParameterList documented in memory/project_c004_purchase_orders.md.
