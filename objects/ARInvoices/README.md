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
- `known_good/` — the owner's known-good AutoInvoice run (Fusion process 10071776): submitted zip,
  FBDI template (.xlsm), a re-prefixed GOOD+BAD variant proven standalone on 2026-10-07, probe
  files, scripts and ESS-log evidence. Analysis: `docs/findings/known_good_ARInvoices.md`.

## Known Issues
Live standard violations / gaps still present in this object's code (section 5 / section 7 of
`docs/DMT_DESIGN.html`):

1. **Whole-document rejection — implemented 2026-10-07, with these limits.**
   `DMT_AR_RESULTS_PKG.PROPAGATE_DOCUMENT_ERRORS` quotes a rejected line's (or distribution's)
   real Fusion error onto every other non-LOADED line and distribution DMT sent with the same
   AutoInvoice grouping values, because the AR document is the Fusion invoice, not the DMT source
   invoice (section 5 AR note, decided 2026-10-07). With config `AR_GROUP_BY_DMT_INVOICE = Y`
   (default) the transform stamps `DMT <invoice key>` into INTERNAL_NOTES, so the Fusion invoice
   equals the DMT invoice and an error spreads only within it. Limits: (a) the grouping key is built from
   the values DMT sent, compared literally; AutoInvoice compares the ids it derives from them
   (customer, site, type, terms), so two different spellings that resolve to the same id would
   group in Fusion but not here; (b) the pod's grouping rule is hard-coded (Oracle mandatory set
   plus SALES_ORDER), not read at runtime. (Paging fixed 2026-10-07 by recon report V3: the line
   RECORD_KEY is ATTRIBUTE1/ATTRIBUTE2, unique per line.)
2. **Null transaction-flexfield key is not synthesized.** A line with neither
   `INTERFACE_LINE_ATTRIBUTE1` nor `TRX_NUMBER` in STG reaches the FBDI with a NULL key (the
   section 7 rule "Null FBDI source references are synthesized deterministically" is not applied).
3. Pre-existing package-wide deviations shared with most DMT packages: no NAME/PURPOSE/REVISIONS
   header, procedures signal failure by re-raising rather than an `x_error_code` OUT parameter,
   no `l_step` breadcrumbs, and the validator keeps one nested DECLARE block for the upstream
   check.
4. **One work item, several loads.** ARInvoices is one work item that loops over its
   (BU, batch source) groups, one load and one AutoInvoice import per group, and reconciles
   each group inline with that group's own ids. The work item can record only one pair of
   ids (the last group's), so a later reconcile-only rerun of a multi-group run re-reads only
   the last group by job id. Rows already LOADED or FAILED are never touched by a rerun, so
   this matters only for rows left UNACCOUNTED in an earlier group. Fix if it bites: make
   ARInvoices spawn one child work item per group (as Requisitions and Items do).

## Table-name vs FBDI-tab audit (backlog #90, 2026-10-01)

Backlog #90 asks whether every STG/TFM table name mirrors the FBDI CSV tab
(record type) it loads. The object model rule is "one object = one FBDI zip =
one tab per record type". AR AutoInvoice is ONE zip with TWO CSV tabs; DMT
models both with one STG + one TFM table each.

**The mapping (from the generator `DMT_AR_FBDI_GEN_PKG` + the catalog):**

| FBDI tab / CSV | Interface table | Source STG table | Source TFM table | Verdict |
|---|---|---|---|---|
| RaInterfaceLinesAll.csv | RA_INTERFACE_LINES_ALL | DMT_RA_LINES_STG_TBL | DMT_RA_LINES_TFM_TBL | NAME-SHORTENED |
| RaInterfaceDistributionsAll.csv | RA_INTERFACE_DISTRIBUTIONS_ALL | DMT_RA_DISTS_STG_TBL | DMT_RA_DISTS_TFM_TBL | NAME-SHORTENED |

**Findings:**
1. **NAME-SHORTENED, same record type (not a defect).** The two DMT tables carry
   the SAME record types as the two FBDI tabs — invoice lines and invoice
   distributions — but with abbreviated names: `DMT_RA_LINES` for
   `RaInterfaceLinesAll` and `DMT_RA_DISTS` for `RaInterfaceDistributionsAll`.
   The `RA_` prefix is Oracle's own Receivables-AutoInvoice table family
   (`RA_INTERFACE_*`), so the DMT names already echo the Fusion interface tables;
   they simply drop the `INTERFACE`/`ALL` filler and shorten "DISTRIBUTIONS" to
   "DISTS". This is a shortening, not a wrong record type — no rename needed.
2. **No header tab (not a gap).** AR AutoInvoice has no separate header CSV: an
   invoice header is derived by the AutoInvoice import from the grouping columns
   on the lines rows. So there is correctly no `DMT_RA_HEADERS_*` table and no
   NOT-MODELED finding. The generator spec-header already names the correct two
   CSVs (`RaInterfaceLinesAll.csv`, `RaInterfaceDistributionsAll.csv`); no comment
   fix was required.

## History
- 2026-10-07 recon report V4 (`DMT_AR_RECON_V4_DM`, alongside V1-V3; backlog #230): rows are
  found only by the load's own Fusion job ids. Base lines by
  `RA_CUSTOMER_TRX_LINES_ALL.REQUEST_ID` = the AutoInvoiceImportEss id, base distributions
  through their loaded line, interface rows and errors by `LOAD_REQUEST_ID` (AutoInvoice clears
  `REQUEST_ID` on the interface lines it rejects, so the import id is not added there). No LIKE
  on the run prefix. `DMT_AR_RESULTS_PKG` passes the import id to the report; the import lookup
  also matches the group's transaction source on AutoInvoiceImportEss argument 2.
  Proof run 262 (prefix 93318, scenario RegressionTest2610071920): load 10075458, import
  10075462 recorded on the work item and stamped by Fusion on all three base lines and headers;
  3 lines LOADED ($1,400), 3 lines and 2 distributions FAILED ($1,500) with their own real error
  or the cross-grain quote, 0 UNACCOUNTED; a reconcile-only rerun left both TFM tables
  byte-identical.
- 2026-10-07 recon report V3 (`DMT_AR_RECON_V3_DM`, alongside V1/V2): line RECORD_KEY =
  ATTRIBUTE1/ATTRIBUTE2 so keyset paging never drops a line of a multi-line invoice; transform
  stamps the same RECON_KEY; page cap sized for AutoAccounting rows DMT did not send. Verify in
  Fusion now queries by CustomerTransactionId. Regression harness learns the expected outcome
  FAILED_WITH_DOCUMENT (scripts/regression_scenario.json).
- 2026-10-07 cross-grain propagation (branch `fix-ar-cross-grain-propagation`):
  `PROPAGATE_DOCUMENT_ERRORS` quotes a rejected row's real error onto the rest of its Fusion
  invoice; line apply pinned by ATTRIBUTE2; INTERNAL_NOTES grouping stamp behind config
  `AR_GROUP_BY_DMT_INVOICE` (default Y); recon report V2 (`DMT_AR_RECON_V2_DM`) fixes ORA-01489
  when a line error carries INTERFACE_DISTRIBUTION_ID = 0; cross-grain regression rows RT-AR-XG-*.
  Proof run 249 (prefix 93305, scenario RegressionTest2610071705): 3 lines LOADED (incl. XG-B,
  same grouping values as XG-A but its own Fusion invoice), XG-A line 2 FAILED with its own
  memo-line error, XG-A line 1 and both XG-A distributions FAILED quoting it, 0 UNACCOUNTED.
- 2026-10-07 known-good fixes (branch `fix-ar-invoices-known-good`): INTERFACE_LINE_ATTRIBUTE1
  is always run-prefixed (lines and distributions); the hardcoded fallback context
  `DMT Migration` is gone and a line without a context is rejected at pre-validation; the extra
  `AutoInvoiceMasterEss` submission is removed and reconciliation keys on the
  `AutoInvoiceImportEss` request (which creates the invoices); ParameterList argument 23 (Base
  Due Date on Transaction Date) is `Y`. Regression rows now mirror the known-good record
  (context `EXTERNAL_SOURCE`, no transaction number, Progress US Business Unit).
- E2E LOADED confirmed working with BU+BatchSource grouping.
- 24-arg ParameterList documented in memory/project_c006_ar_invoices.md.
