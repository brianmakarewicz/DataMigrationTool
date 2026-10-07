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
   plus SALES_ORDER), not read at runtime; (c) keyset paging of the
   recon report orders by RECORD_KEY = ATTRIBUTE1, which every line of one DMT invoice shares,
   so a page boundary inside such a run of rows can drop one (only above 5,000 rows).
2. **Null transaction-flexfield key is not synthesized.** A line with neither
   `INTERFACE_LINE_ATTRIBUTE1` nor `TRX_NUMBER` in STG reaches the FBDI with a NULL key (the
   section 7 rule "Null FBDI source references are synthesized deterministically" is not applied).
3. Pre-existing package-wide deviations shared with most DMT packages: no NAME/PURPOSE/REVISIONS
   header, procedures signal failure by re-raising rather than an `x_error_code` OUT parameter,
   no `l_step` breadcrumbs, and the validator keeps one nested DECLARE block for the upstream
   check.
4. The reconciliation report matches base lines on `INTERFACE_LINE_ATTRIBUTE1 LIKE :P_PREFIX||'%'`
   (prefix as a search value) rather than on base `REQUEST_ID = :P_IMPORT_ESS_ID`.
5. The Record Detail "Verify in Fusion" REST lookup (`DMT_REST_LOOKUP_TBL` rows `ARInvoices` /
   `AR Lines`) queries `receivablesInvoices` by `TransactionNumber = TFM.TRX_NUMBER`. For an
   auto-numbering source (External Source) DMT sends no transaction number, so the key is empty
   and the button returns NOT_FOUND even for a LOADED invoice (seen on proof run 245). It should key
   on `FUSION_CUSTOMER_TRX_ID` (CustomerTransactionId) instead.

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
- 2026-10-07 cross-grain propagation (branch `fix-ar-cross-grain-propagation`):
  `PROPAGATE_DOCUMENT_ERRORS` quotes a rejected row's real error onto the rest of its Fusion
  invoice; line apply pinned by ATTRIBUTE2; INTERNAL_NOTES grouping stamp behind config
  `AR_GROUP_BY_DMT_INVOICE` (default Y); recon report V2 (`DMT_AR_RECON_V2_DM`) fixes ORA-01489
  when a line error carries INTERFACE_DISTRIBUTION_ID = 0; cross-grain regression rows RT-AR-XG-*.
- 2026-10-07 known-good fixes (branch `fix-ar-invoices-known-good`): INTERFACE_LINE_ATTRIBUTE1
  is always run-prefixed (lines and distributions); the hardcoded fallback context
  `DMT Migration` is gone and a line without a context is rejected at pre-validation; the extra
  `AutoInvoiceMasterEss` submission is removed and reconciliation keys on the
  `AutoInvoiceImportEss` request (which creates the invoices); ParameterList argument 23 (Base
  Due Date on Transaction Date) is `Y`. Regression rows now mirror the known-good record
  (context `EXTERNAL_SOURCE`, no transaction number, Progress US Business Unit).
- E2E LOADED confirmed working with BU+BatchSource grouping.
- 24-arg ParameterList documented in memory/project_c006_ar_invoices.md.
