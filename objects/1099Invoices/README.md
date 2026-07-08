# 1099 Invoices

## Status
ESS QUEUE TIMEOUT, code complete

## Pipeline
- Module: Financials
- FBDI Template: ApInvoicesInterface.xlsm (shared with AP Invoices)
- Interface Tables: AP_INVOICES_INTERFACE, AP_INVOICE_LINES_INTERFACE (shared with AP Invoices)
- UCM Account: fin/payables/import (shared with AP Invoices)
- ESS Job: Same as AP Invoices
- ParameterList: Same as AP Invoices
- Loader Type: SQLLOADER
- Auth User: fin_impl

## Code References
- STG/TFM Tables: Shared with APInvoices (see `objects/APInvoices/README.md`)
- Validator: `packages/validators/dmt_ap_validator_pkg.*` (shared)
- Transformer: `packages/transformers/dmt_ap_transform_pkg.*` (shared)
- FBDI Generator: `packages/generators/fbdi/ap/dmt_1099_fbdi_gen_pkg.*`
- Results/Reconciliation: `packages/reconciliation/dmt_1099_results_pkg.*`
- BIP Data Model/Report: `bip/1099Invoices/`

## Reference Files
None in this folder.

## Known Issues
- ESS queue timeout on demo instance. Code is complete and ready to test when instance queue clears.

## History
- Code completed. Blocked by demo instance ESS queue congestion.
