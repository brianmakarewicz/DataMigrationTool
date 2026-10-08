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

## Cross-grain error propagation (whole-document rejection, 2026-10-07)

Import Blanket Agreements rejects every line of an agreement whose header is rejected, but
writes `PO_INTERFACE_ERRORS` only on the header. It does not reject the header when only a line
fails: it accepts the agreement and rejects that line alone. So the only whole-document case
for blanket agreements is header -> lines.

`DMT_BLANKET_PO_RESULTS_PKG.PROPAGATE_DOCUMENT_ERRORS` runs in `RECONCILE_BATCH` after the
per-row apply and before the shared UNACCOUNTED sweep (design section 5, "Whole-document
rejection carries the real error to every grain").

- **Sources** are blanket headers (`STYLE_DISPLAY_NAME = 'Blanket Purchase Agreement'`, the
  catalog row filter) that are FAILED with their own real `[FUSION_ERROR]`.
- **Targets** are that agreement's lines (same `INTERFACE_HEADER_KEY`) that Fusion received
  and that are not LOADED. Each gets
  `[FUSION_ERROR] Rejected with document: header <RECON_KEY>: <real message>` appended, and is
  set FAILED. Standard POs and Contracts in the shared PO tables are never touched. A second
  reconcile adds nothing (exact-quote guard).

Regression cross-grain scenarios (scenario `RegressionTest2610071840`, expected outcomes in
`scripts/regression_scenario.json`):
- `RT-BPAL-BAD1` is a valid line under the bad-supplier header `RT-BPA-BAD1`. It must land
  FAILED quoting the header's supplier error.
- `RT-BPA-XG2` is a valid agreement with a valid line 1 and a line 2 whose only defect is its UOM.
  The header and line 1 must LOAD and only line 2 FAILS. This proves no upward propagation.

Proof run 253 (prefix 93309, STANDALONE:BlanketPOs): BPA-001 and BPA-XG2 LOADED
(`po_header_id` 687871 / 687872) with their good lines. Fusion set `253_LN_100001016` (the BAD1
line) to REJECTED with no error of its own, and it lands FAILED quoting the header. XG2 line 2
FAILED with its own UOM error. 0 UNACCOUNTED. Line amounts tie out: staged 53,000 = loaded
51,000 + failed 2,000. A reconcile-only rerun left every ERROR_TEXT byte-identical.

## Reconciliation by Fusion job id (recon V2, 2026-10-07, backlog #258)

`bip/BlanketPOs/DMT_BLANKET_PO_RECON_V2_DM.xdm` (deployed alongside V1, which is never
overwritten) finds rows only by the work item's own Fusion job ids and the Blanket style,
because BlanketPOs shares the PO interface and base tables with PurchaseOrders and Contracts:

- Base headers and lines: `REQUEST_ID` = the import job (ImportBPAJob) and the header
  `TYPE_LOOKUP_CODE = 'BLANKET'`.
- Interface headers: `LOAD_REQUEST_ID` = the load job AND `REQUEST_ID` = the import job AND
  `DOCUMENT_TYPE_CODE = 'BLANKET'`. Interface lines: their `LOAD_REQUEST_ID` under such a
  header, joined on Fusion's `INTERFACE_HEADER_ID` (Fusion leaves `REQUEST_ID` NULL on the
  interface lines).
- `PO_INTERFACE_ERRORS`: `REQUEST_ID` = the import job, joined on the interface id.

V1 also narrowed the interface rows with `LIKE :P_RUN_ID || '_HDR_%'` / `'_LN_%'`; that is
gone. Document and line numbers are only the `RECORD_KEY`.

Proof run 264 (prefix 93320, scenario RegressionTest2610071920, STANDALONE:BlanketPOs): load
10075472 and import 10075476 (ImportBPAJob) are the ids Fusion stamped on the interface and
base rows. Same result as run 253: BPA-001 and BPA-XG2 LOADED with their good lines, BAD1
FAILED on its supplier error with its line quoting it, XG2 line 2 FAILED on its own UOM error,
0 UNACCOUNTED, line amounts 53,000 staged = 51,000 loaded + 2,000 failed. A reconcile-only
rerun left every TFM row byte-identical; regression harness PASS (7/7 expected outcomes);
Playwright click-through PASS.

## Known Issues
- **Root cause found (2026-04-06):** ESS WAIT was caused by wrong ESS job (ImportSPOJob instead of ImportBPAJob) and wrong UCM account. Seed script `schema/seed/05_dmt_erp_options_extra_seed.sql` was copying from row 21 (PO) instead of row 23 (BPA). Seed script fixed. ATP UPDATE + ParameterList code fix pending.
- ParameterList code at `dmt_loader_pkg.pkb` line 1777 builds 9-arg ImportSPOJob format — needs rewrite to 8-arg ImportBPAJob format (see status.md [DB] task).

## Table-name vs FBDI-tab audit (backlog #90, 2026-10-01)

Backlog #90 asks whether every STG/TFM table name mirrors the FBDI CSV tab
(record type) it loads. BlanketPOs is its OWN object — a separate zip
(`ImportBPAJob`, UCM `prc/blanketPurchaseAgreement/import`) built from the
Blanket Purchase Agreement Import template, NOT the standard-PO template. It
carries TWO CSVs (headers + lines; no locations or distributions). It reuses the
shared PO_* STG/TFM tables, selecting only `STYLE_DISPLAY_NAME = 'Blanket
Purchase Agreement'` rows via the catalog `ROW_FILTER`.

**The mapping (from the generator `DMT_BLANKET_PO_FBDI_GEN_PKG` body + the
captured zip `test/fbdi_zips/BlanketPOs_100000905.zip` + the catalog):**

| FBDI tab / CSV | Interface table | Source STG table | Source TFM table | Verdict |
|---|---|---|---|---|
| PoHeadersInterfaceBlanket.csv | PO_HEADERS_INTERFACE | DMT_PO_HEADERS_INT_STG_TBL (style = Blanket Purchase Agreement) | DMT_PO_HEADERS_INT_TFM_TBL (style = Blanket Purchase Agreement) | ALIGNED (shared table, style-filtered) |
| PoLinesInterfaceBlanket.csv | PO_LINES_INTERFACE | DMT_PO_LINES_INT_STG_TBL (style = Blanket Purchase Agreement) | DMT_PO_LINES_INT_TFM_TBL (style = Blanket Purchase Agreement) | ALIGNED (shared table, style-filtered) |

**Notes:**
- The CSV filenames carry the `Blanket` suffix because the BPA import template's
  tabs are named `PoHeadersInterfaceBlanket` / `PoLinesInterfaceBlanket` — these
  ARE the correct Oracle FBDI tab names for the BPA job (verified against the
  captured `BlanketPOs_100000905.zip`, which ships exactly those two entries).
  This is NOT the same tab as the standard-PO `...InterfaceOrder` CSVs.
- The STG/TFM tables (`DMT_PO_HEADERS_INT_*`, `DMT_PO_LINES_INT_*`) are shared
  with PurchaseOrders and Contracts and carry no style word in their names; one
  table serves all three PO document styles, partitioned by `STYLE_DISPLAY_NAME`.
  Record type matches (headers → headers, lines → lines), so ALIGNED — the shared
  table is a deliberate model choice, not a wrong-record-type defect.
- **Generator spec header already accurate** —
  `dmt_blanket_po_fbdi_gen_pkg.pks.sql` documents "2 CSVs" correctly. The
  one-line header says `PoHeadersInterfaceOrder.csv + PoLinesInterfaceOrder.csv`
  as a shorthand for "the PO headers/lines CSVs"; the body emits the exact
  `...Blanket` tab names and the captured zip confirms them. Left as-is (the
  header is a style-agnostic description, not a wrong filename claim); no code
  change.

## History
- Code completed. Blocked by demo instance ESS queue congestion.
- 2026-04-06: Root cause identified — wrong ESS job, UCM account, and ParameterList. Seed script fixed. [DB] task created for Claude Code.
