# Blanket POs

## Status
[DB] task pending — wrong ESS job + wrong UCM account + wrong ParameterList. Seed script fixed, ATP update + code fix ready for Claude Code.

## Pipeline
- Module: Procurement
- FBDI Template: POBlanketPurchaseAgreementImportTemplate.xlsm (SEPARATE from PurchaseOrders)
- Interface Tables: PO_HEADERS_INTERFACE, PO_LINES_INTERFACE, PO_LINE_LOCATIONS_INTERFACE, PO_GA_ORG_ASSIGN_INTERFACE, PO_ATTR_VALUES_INTERFACE, PO_ATTR_VALUES_TLP_INTERFACE
- UCM Account: `prc/blanketPurchaseAgreement/import` (NOT prc/purchaseOrder/import)
- ESS Job: `ImportBPAJob` (NOT ImportSPOJob)
- Job Definition: `/oracle/apps/ess/prc/po/pdoi;ImportBPAJob`
- ERP Options Source Row: `ERP_INTERFACE_OPTIONS_ID = 23`
- Loader Type: SQLLOADER
- Auth User: calvin.roth

## ESS ParameterList (8 arguments)

Confirmed from Fusion UI — Request 9419765 (2026-04-06, calvin.roth).

| # | Argument | Display Label | Required | Stored Value | Notes |
|---|----------|--------------|----------|-------------|-------|
| 1 | argument1 | Procurement BU | Yes | 300000046987012 | BU internal ID |
| 2 | argument2 | Default Buyer | Yes | 300000047340498 | Buyer internal ID |
| 3 | argument3 | Create or Update Item | No | N | "Yes"→"Y", "No"→"N" |
| 4 | argument4 | Approval Action | Yes | SUBMIT | Also: DO_NOT_APPROVE, BYPASS |
| 5 | argument5 | Batch ID | No | 1234 | Pass-through text |
| 6 | argument6 | Import Source | No | source | Pass-through text |
| 7 | argument7 | Communicate Agreements | No | N | "Yes"→"Y", "No"→"N" |
| 8 | argument8 | (auto-generated group tag) | — | 300000046987012_1234 | `{BU_ID}_{BatchID}` |

**Different from ImportSPOJob (9 args):** No "Default Requisitioning BU". arg3=CreateOrUpdateItem (not ApprovalAction). 8 args total vs 9.

## Code References
- STG/TFM Tables: Shared with PurchaseOrders (see `objects/PurchaseOrders/README.md`)
- Validator: `packages/validators/dmt_po_validator_pkg.*` (shared)
- Transformer: `packages/transformers/dmt_po_transform_pkg.*` (shared)
- FBDI Generator: `packages/generators/fbdi/po/dmt_blanket_po_fbdi_gen_pkg.*`
- Results/Reconciliation: `packages/reconciliation/dmt_blanket_po_results_pkg.*`
- BIP Data Model/Report: `bip/BlanketPOs/`

## Reference Files
None in this folder.

## Known Issues
- **Root cause found (2026-04-06):** ESS WAIT was caused by wrong ESS job (ImportSPOJob instead of ImportBPAJob) and wrong UCM account. Seed script `schema/seed/05_dmt_erp_options_extra_seed.sql` was copying from row 21 (PO) instead of row 23 (BPA). Seed script fixed. ATP UPDATE + ParameterList code fix pending.
- ParameterList code at `dmt_loader_pkg.pkb` line 1777 builds 9-arg ImportSPOJob format — needs rewrite to 8-arg ImportBPAJob format (see status.md [DB] task).

## History
- Code completed. Blocked by demo instance ESS queue congestion.
- 2026-04-06: Root cause identified — wrong ESS job, UCM account, and ParameterList. Seed script fixed. [DB] task created for Claude Code.
