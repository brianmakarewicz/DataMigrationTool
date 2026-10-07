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
None currently.

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
- E2E LOADED confirmed working with BU+BatchSource grouping.
- 24-arg ParameterList documented in memory/project_c006_ar_invoices.md.
