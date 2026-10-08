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

## Reconciliation by Fusion job id (recon V2, 2026-10-07, backlog #259)

`bip/Contracts/DMT_CONTRACT_RECON_V2_DM.xdm` (deployed alongside V1, which is never
overwritten) finds rows only by the work item's own Fusion job ids and the Contract style,
because Contracts shares the PO interface and base tables with PurchaseOrders and BlanketPOs:
base headers by `REQUEST_ID` = the import job (ImportCPAJob) and `TYPE_LOOKUP_CODE =
'CONTRACT'`; interface headers by `LOAD_REQUEST_ID` = the load job AND `REQUEST_ID` = the
import job AND `DOCUMENT_TYPE_CODE = 'CONTRACT'`; `PO_INTERFACE_ERRORS` by `REQUEST_ID` = the
import job. V1's `LIKE :P_RUN_ID || '_HDR_%'` is gone; the document number is only the
`RECORD_KEY`.

Proof run 269 (prefix 93325, scenario RegressionTest2610071920, STANDALONE:Contracts): load
10075565 and import 10075572 (ImportCPAJob) are the ids Fusion stamped on the interface and
base rows. Same result as earlier runs: CPA-001 LOADED (`po_header_id` 687878), CPA-BAD1 FAILED
on its own supplier error, 0 UNACCOUNTED (count tie-out 2 = 1 + 1; the Contract header carries
no amount column). A reconcile-only rerun left the TFM rows byte-identical; regression harness
PASS; Playwright click-through PASS.

## Known Issues
- **Root cause found (2026-04-06):** ESS WAIT was caused by wrong ESS job (ImportSPOJob instead of ImportCPAJob) and wrong UCM account. Seed script already correct (row 22). Live ATP data may need UPDATE if deployed before seed was fixed.
- ParameterList code in `dmt_loader_pkg.pkb` (Contracts block) builds 9-arg ImportSPOJob format — needs rewrite to 7-arg ImportCPAJob format.

## Table-name vs FBDI-tab audit (backlog #90, 2026-10-01)

Backlog #90 asks whether every STG/TFM table name mirrors the FBDI CSV tab
(record type) it loads. Contracts is its OWN object — a separate zip
(`ImportCPAJob`, UCM `prc/contractPurchaseAgreement/import`) built from the
Contract Purchase Agreement Import template, headers only (ONE CSV, no lines).
It reuses the shared PO headers STG/TFM table, selecting only
`STYLE_DISPLAY_NAME = 'Contract Purchase Agreement'` rows via the catalog
`ROW_FILTER`.

**The mapping (from the generator `DMT_CONTRACT_FBDI_GEN_PKG` body + the
catalog):**

| FBDI tab / CSV | Interface table | Source STG table | Source TFM table | Verdict |
|---|---|---|---|---|
| PoHeadersInterfaceContract.csv | PO_HEADERS_INTERFACE | DMT_PO_HEADERS_INT_STG_TBL (style = Contract Purchase Agreement) | DMT_PO_HEADERS_INT_TFM_TBL (style = Contract Purchase Agreement) | ALIGNED (shared table, style-filtered) |

**Notes:**
- A Contract Purchase Agreement is a header-only document in Fusion — no lines,
  locations, or distributions — so the one-CSV model is correct and complete, not
  a missing-tab gap.
- The `PoHeadersInterfaceContract.csv` name is the CPA import template's header
  tab; it is the correct Oracle FBDI tab name for the CPA job and is distinct
  from the standard-PO `PoHeadersInterfaceOrder.csv` and the BPA
  `PoHeadersInterfaceBlanket.csv`.
- `DMT_PO_HEADERS_INT_*` is shared with PurchaseOrders and BlanketPOs and carries
  no style word; one headers table serves all three PO styles, partitioned by
  `STYLE_DISPLAY_NAME`. Record type matches (headers → headers), so ALIGNED.
- **Generator spec header already accurate** —
  `dmt_contract_fbdi_gen_pkg.pks.sql` documents "1 CSV only:
  PoHeadersInterfaceContract.csv (no lines)", matching the body. No fix needed.

## History
- Code completed. Blocked by demo instance ESS queue congestion.
- 2026-04-06: Root cause identified — wrong ESS job, UCM account, and ParameterList. [DB] task created for Claude Code.
