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

## Cross-grain error propagation (whole-document rejection, 2026-10-07)

Payables Import rejects the whole invoice when the header or any line fails, but it writes
`AP_INTERFACE_REJECTIONS` only for the row that failed. Proven live in run 254: invoice
`93310RT-APINV-XG1` had one bad line (line 2, invalid distribution account). Fusion set the
header REJECTED with no rejection of its own, wrote no rejection for the valid line 1, wrote
`INVALID DISTRIBUTION ACCT` for line 2, and created no base invoice. The bad-supplier invoice
`RT-APINV-BAD1` shows the other direction: header rejected with `INVALID SUPPLIER`, its line
rejected with nothing of its own. The AP FBDI has no distributions file, so the document is the
invoice (header plus its lines) and every direction applies.

`DMT_AP_RESULTS_PKG.PROPAGATE_DOCUMENT_ERRORS` runs in `RECONCILE_BATCH` after the per-row
apply and before the shared UNACCOUNTED sweep (design section 5, "Whole-document rejection
carries the real error to every grain").

- **Sources** are headers and lines FAILED with their own real `[FUSION_ERROR]` (no quote
  marker).
- **Targets** are the other rows of the same invoice (same `INVOICE_ID` in the run) that Fusion
  received and that are not LOADED. Each gets
  `[FUSION_ERROR] Rejected with document: <header|line> <RECON_KEY>: <real message>` appended
  and is set FAILED. A second reconcile adds nothing (exact-quote guard).

Recon report V2 (`bip/APInvoices/DMT_AP_RECON_V2_DM.xdm`, deployed alongside V1):

- Rows are found by Fusion job id only. Base rows come from the Payables Import request id
  (`AP_INVOICES_ALL.REQUEST_ID` and `AP_INVOICE_LINES_ALL.REQUEST_ID`; the tax lines Payables
  adds itself carry no request id and are not returned). Interface rows and their rejections
  come from `LOAD_REQUEST_ID`. The prefixed invoice number is only the match key.
- Rejections are scoped to the load. Fusion reuses interface `INVOICE_ID`s across loads, so V1
  reported a September load's `NO INVOICE LINES` as the run-238 `RT-1099-G1` header's own error.
- Only real `AP_INTERFACE_REJECTIONS` text is returned. V1's composed
  `Rejected by Payables Import (status=...)` and `Parent invoice rejected:` strings are gone.

Regression cross-grain scenario (scenario `RegressionTest2610071919`, expected outcomes in
`scripts/regression_scenario.json`): `RT-APINV-XG1` is a valid header (JGA / 1254 / JGA US1,
300) with valid line 1 (100) and line 2 (200) whose only defect is the distribution account
`999.99.99999.999.999.999`. The header and line 1 must land FAILED quoting line 2; line 2 FAILED
with its own error.

Proof run 254 (prefix 93310, STANDALONE:APInvoices): G1 and G2 LOADED (invoice ids 1566384 /
1566385) with their lines. XG1 header and line 1 FAILED quoting
`line 93310RT-APINV-XG1:LINE:2: [LINE] INVALID DISTRIBUTION ACCT`; line 2 FAILED with its own
error. BAD1 line FAILED quoting `header 93310RT-APINV-BAD1: [HDR] INVALID SUPPLIER`. 0
UNACCOUNTED. Amounts tie out on both tiers: staged 9,550 = loaded 4,250 + failed 5,300. A
reconcile-only rerun left every TFM status and ERROR_TEXT byte-identical.

## Known Issues
- `RT-1099-G1` is seeded as a GOOD invoice but its line is rejected every run
  (`INVALID DISTRIBUTION ACCT | INVALID TYPE 1099`: the seed uses a dash-separated account and
  TYPE_1099 `07`). It is listed in the expected outcomes as it actually behaves (line FAILED,
  header FAILED with its document). Cause confirmed as test data (backlog #308,
  `docs/findings/ap_1099_g1_rejection.md`): the chart of accounts delimiter is `.`, and
  `TYPE_1099` must be an `AP_INCOME_TAX_TYPES` code (`MISC7`). The seed is corrected for
  scenarios minted from 2026-10-07 on; existing scenarios keep the old rows.
- The reconciler still echoes outcomes back to the two STG tables (pre-existing; a
  reconcile-only rerun appends the TFM error text to the STG row again).

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

## Reconciliation report pages by header (2026-10-09, backlog #681)

The registered report is now `bip/APInvoices/DMT_AP_RECON_V3_DM.xdm`, deployed alongside `DMT_AP_RECON_V2_DM` (never overwritten).
It pages on header boundaries (owner decision 2026-10-09, design section 5, "Reconciliation
fetches page on header boundaries"): a page is the next BIP_CHUNK_SIZE headers, keyed by the prefixed invoice number,
plus every base and interface row that belongs to them, and each row carries that header key in
the tenth column `PAGE_KEY`. `DMT_RECON_CONTRACT_PKG.FETCH_ROWS` counts headers, sends the last
header key back as `P_AFTER_KEY`, has no page cap, and fails the fetch with an error if a page
does not advance. Row selection (job ids only), RECORD_KEYs, FUSION_IDs and error text are the
same as in `DMT_AP_RECON_V2_DM`.
