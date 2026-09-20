# GL Balances

## Status
**E2E LOADED** (2 LOADED, 1 intentional FAILED)

## Pipeline
- Module: Financials
- FBDI Template: GlInterface.xlsm
- Interface Table: GL_INTERFACE
- UCM Account: fin/generalLedger/import
- ESS Job: JournalImportLauncher
- ParameterList: `300000046975980,Spreadsheet,300000046975971,<integration_id>,N,N,N`
- Loader Type: SQLLOADER
- Auth User: fin_impl

## ParameterList Details
- **DataAccessSetID:** 300000046975980 (US Primary Ledger)
- **Source:** Spreadsheet (must match USER_JE_SOURCE_NAME in data exactly)
- **LedgerID:** 300000046975971 (US Primary Ledger)
- **GroupID:** integration_id (isolates this run's rows)
- **Last 3:** N,N,N

Discovered via BIP query against `gl_ledgers` + `gl_access_sets` on 2026-04-02.

## Code References
- STG Table DDL: `schema/tables/148_dmt_gl_interface_stg_tbl.sql`
- TFM Table DDL: `schema/tables/149_dmt_gl_interface_tfm_tbl.sql`
- Validator: `packages/validators/dmt_gl_validator_pkg.*`
- Transformer: `packages/transformers/dmt_gl_transform_pkg.*`
- FBDI Generator: `packages/generators/fbdi/gl/dmt_gl_fbdi_gen_pkg.*`
- Results/Reconciliation: `packages/reconciliation/dmt_gl_results_pkg.*`
- BIP Data Model/Report: `bip/GLBalances/`

## Reference Files
None in this folder.

## Known Issues
None currently.

## History
- 2026-09-20: **Conformed to the BIP reconciliation report contract v1 as the
  reference implementation.** The recon data model now returns the NINE standard
  columns in contract order (OBJECT_TYPE, RECORD_KEY, SOURCE_TYPE, FUSION_STATUS,
  FUSION_ID, ERROR_MESSAGE, LOAD_REQUEST_ID, SOURCE_REF, DMT_REFERENCE), declares
  exactly the six standard parameters (P_RUN_ID, P_LOAD_REQUEST_ID, P_IMPORT_ESS_ID,
  P_PREFIX, P_CHUNK_SIZE, P_AFTER_KEY — no P_OFFSET/P_LIMIT), and pages by KEYSET:
  rows ordered by RECORD_KEY, only keys greater than P_AFTER_KEY, at most P_CHUNK_SIZE
  per page. FUSION_STATUS is normalized inside the DM to SUCCESS/ERROR. Artifacts
  renamed to the _RECON_ infix: DMT_GL_BAL_RECON_DM.xdm + DMT_GL_BAL_RECON_RPT.xdo
  (deploy script + BIP registry updated). The reconciler's shared keyset fetch loop
  bulk-collects each page into one DMT_RECON_ROW_TBL collection, then a single MERGE
  marks LOADED (BASE/SUCCESS, capturing FUSION_ID) and a single MERGE marks FAILED
  (ERROR, with the real message). Round-trip proof is a single set-based summary.
  Two-tier GL semantics preserved: a balanced base journal is postable (LOADED); an
  unbalanced one will not post (FAILED). Validated standalone against prior loaded
  run 314 (keys 473/474 SUCCESS, 475 ERROR) with keyset paging proven page-by-page.
  Supersedes the rejected six-column/OFFSET attempt (PR #324). NOTE: contrary to the
  older lesson below, the deployed DM DOES query GL_JE_HEADERS/GL_JE_LINES in the
  UNION ALL — the "tier 2 stubbed" note is obsolete.
- E2E LOADED confirmed with 2 rows reaching LOADED status in Fusion (2026-04-02).
- 2026-04-02: BIP audit — switched to two-tier reconciliation.
  - Tier 1: GL_INTERFACE (interface table errors/status)
  - Tier 2: GL_JE_HEADERS + GL_JE_LINES (stubbed — not queryable via BIP UNION ALL)
  - Added P_IMPORT_ESS_ID parameter to BIP data model
  - Eliminated absence=LOADED fallback. Unmatched GENERATED rows now FAILED with RECONCILE_ERROR.
- 2026-04-02: Three fixes to reach LOADED:
  1. **ParameterList IDs wrong.** Was using Corporate Primary Ledger IDs (300000116270108/300000116270105) which don't exist on this instance. Fixed to US Primary Ledger IDs (300000046975980/300000046975971). Discovered via `/fusion-query` skill against gl_ledgers + gl_access_sets.
  2. **Period closed.** Test data used period `12-11` (Dec 2011) — closed. Switched to `04-26` (open). Discovered via `/fusion-query` against gl_period_statuses.
  3. **BIP reconciliation misinterpreted status P.** GL_INTERFACE status `P` = Processed (success, awaiting purge). Reconciliation was treating ALL INTERFACE rows as FAILED. Fixed to: `P` = LOADED, anything else (NEW, E, EFxx) = FAILED.

## Lessons Learned
- **GL_INTERFACE status P = success.** Unlike other interface tables where presence = failure, GL_INTERFACE keeps processed rows with status `P` until purged. BIP reconciliation must check the status value, not just presence.
- **GL_INTERFACE status codes:** P=Processed(success), NEW=unprocessed, E=error, EFxx=specific error code.
- **ParameterList must match ledger.** DataAccessSetID and LedgerID must correspond to the ledger named in the data. Query `gl_ledgers` + `gl_access_sets` to find correct IDs.
- **Use open periods.** Test data must use a period with `closing_status = 'O'` in `gl_period_statuses`. Query to find open periods: `SELECT period_name FROM gl_period_statuses WHERE application_id = 101 AND closing_status = 'O' AND ledger_id = <id>`.
- **Never assume absence=LOADED without positive verification.** Two-tier BIP pattern queries both interface AND base tables.
- **DMT_GL_BAL_RECON_DM.xdm is the deployed DM** (Contract v1, _RECON_ infix). The
  deploy script and BIP registry both point here. The old GL_BAL_DM.xdm / GL_DM.xdm
  names are retired.
- **BIP SQL parser requires blank lines around UNION ALL.** Without them, BIP throws java.sql.SQLSyntaxErrorException.
- **GL_JE_HEADERS/LINES not queryable in BIP UNION ALL context.** Tier 2 is stubbed with DUAL.
- **Valid COA segments for US Primary Ledger:** 6-segment format (101.10.xxxxx.120.000.000). Accounts 78630, 77600, 60540, 62510, 78610 confirmed valid.
