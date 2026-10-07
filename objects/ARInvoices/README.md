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

1. **Whole-document rejection is not yet propagated across grains (section 5, decided
   2026-10-07).** AutoInvoice's invalid-lines rule "Reject invoice" holds back every valid line
   that would have joined an invoice with an errored line, and writes NO error for the held lines
   (proven: Fusion 10073725 / 10073734, `docs/findings/known_good_ARInvoices.md`). DMT does not
   yet quote the errored line's real Fusion error onto those held lines (or onto a rejected
   line's distributions, whose interface rows carry no error of their own), so such rows would be
   left UNACCOUNTED. Doing it needs the reconciliation report to identify the invoice a held line
   would have grouped into (AutoInvoice grouping rules, per batch source) — a new BIP version.
   The regression BAD row is deliberately on its own invoice (different bill-to account), so the
   current scenario is not affected; the cross-grain regression scenario the rule requires is
   not built yet.
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
- 2026-10-07 known-good fixes (branch `fix-ar-invoices-known-good`): INTERFACE_LINE_ATTRIBUTE1
  is always run-prefixed (lines and distributions); the hardcoded fallback context
  `DMT Migration` is gone and a line without a context is rejected at pre-validation; the extra
  `AutoInvoiceMasterEss` submission is removed and reconciliation keys on the
  `AutoInvoiceImportEss` request (which creates the invoices); ParameterList argument 23 (Base
  Due Date on Transaction Date) is `Y`. Regression rows now mirror the known-good record
  (context `EXTERNAL_SOURCE`, no transaction number, Progress US Business Unit).
- E2E LOADED confirmed working with BU+BatchSource grouping.
- 24-arg ParameterList documented in memory/project_c006_ar_invoices.md.
