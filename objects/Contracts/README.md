# Contracts

## Status
[DB] task pending — wrong ESS job + wrong UCM account + wrong ParameterList. Seed script already correct (row 22). Live ATP data may need UPDATE. ParameterList code fix ready for Claude Code.

## Pipeline
- Module: Procurement
- FBDI Template: Contract Purchase Agreement Import Template (SEPARATE from PurchaseOrders, headers only)
- Interface Tables: PO_HEADERS_INTERFACE (headers only)
- UCM Account: `prc/contractPurchaseAgreement/import` (NOT prc/purchaseOrder/import)
- ESS Job: `ImportCPAJob` (NOT ImportSPOJob)
- Job Definition: `/oracle/apps/ess/prc/po/pdoi;ImportCPAJob`
- ERP Options Source Row: `ERP_INTERFACE_OPTIONS_ID = 22`
- Loader Type: SQLLOADER
- Auth User: calvin.roth

## ESS ParameterList (7 arguments)

Confirmed from Fusion UI — Request 9419807 (2026-04-06, calvin.roth).

| # | Argument | Display Label | Required | Stored Value | Notes |
|---|----------|--------------|----------|-------------|-------|
| 1 | argument1 | Procurement BU | Yes | 300000046987012 | BU internal ID |
| 2 | argument2 | Default Buyer | Yes | 300000047340498 | Buyer internal ID |
| 3 | argument3 | Approval Action | Yes | SUBMIT | Also: DO_NOT_APPROVE, BYPASS |
| 4 | argument4 | Batch ID | No | 123 | Pass-through text |
| 5 | argument5 | Import Source | No | source | Pass-through text |
| 6 | argument6 | Communicate Agreements | No | N | "Yes"→"Y", "No"→"N" |
| 7 | argument7 | (auto-generated group tag) | — | 300000046987012_123 | `{BU_ID}_{BatchID}` |

**Different from ImportSPOJob (9 args):** No "Default Requisitioning BU". No "Create or Update Item". 7 args total vs 9.
**Different from ImportBPAJob (8 args):** No "Create or Update Item" (BPA has it at arg3). 7 args vs 8.

## Code References
- STG/TFM Tables: Shared with PurchaseOrders (headers only)
- Validator: `packages/validators/dmt_po_validator_pkg.*` (shared)
- Transformer: `packages/transformers/dmt_po_transform_pkg.*` (shared)
- FBDI Generator: `packages/generators/fbdi/po/dmt_contract_fbdi_gen_pkg.*`
- Results/Reconciliation: `packages/reconciliation/dmt_contract_results_pkg.*`
- BIP Data Model/Report: `bip/Contracts/`

## Reference Files
None in this folder.

## Known Issues
- **Root cause found (2026-04-06):** ESS WAIT was caused by wrong ESS job (ImportSPOJob instead of ImportCPAJob) and wrong UCM account. Seed script already correct (row 22). Live ATP data may need UPDATE if deployed before seed was fixed.
- ParameterList code in `dmt_loader_pkg.pkb` (Contracts block) builds 9-arg ImportSPOJob format — needs rewrite to 7-arg ImportCPAJob format.

## History
- Code completed. Blocked by demo instance ESS queue congestion.
- 2026-04-06: Root cause identified — wrong ESS job, UCM account, and ParameterList. [DB] task created for Claude Code.
