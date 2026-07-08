# Assets

## Status
**E2E LOADED — two-stage, per-record** (2026-06-30, queue model). Validated live:
run 105 (2 GOOD → LOADED in `fa_additions_b`), run 106 (1 GOOD + 1 BAD → GOOD LOADED,
BAD FAILED with real Fusion error), run 107 (official `RegressionTest` scenario).
Requires FA Additions approval **disabled** on the US CORP book (instance config).

## Pipeline (TWO-STAGE)
- Module: Financials
- FBDI Template: FaMassAdditions.xlsm
- Interface Tables: FA_MASS_ADDITIONS, FA_MASSADD_DISTRIBUTIONS, FA_MC_MASS_RATES
- UCM Account: fin/assets/import
- **Stage 1 — chained import job** (`loadAndImportData`): **PrepareMassAdditions**
  (`IMPORT_JOB_NAME`). Brings rows into the interface and stamps posting_status per record.
- **Stage 2 — standalone follow-up** (`submitESSJobRequest`): **PostMassAdditions**
  (`POST_LOAD_JOB_NAME`), ParameterList = Book Type Code (e.g. `US CORP`). Posts to
  `FA_ADDITIONS_B`. Driven by the queue worker's `AWAITING_POSTRUN` state.
- **Per-record, NOT all-or-nothing:** PrepareMassAdditions flags each row (POST/ERROR);
  PostMassAdditions posts only the good ones; reconcile marks each LOADED/FAILED individually.
- Loader Type: SQLLOADER
- Auth User: fin_impl
- **Reconcile anchor: ASSET_NUMBER** — Fusion honors a supplied (prefixed) asset_number,
  so it survives to `fa_additions_b` and the prefix-LIKE Tier-2 match works.

## Code References
- STG Table DDL (Headers): `schema/tables/154_dmt_fa_asset_hdr_stg_tbl.sql`
- STG Table DDL (Assignments): `schema/tables/156_dmt_fa_asset_assign_stg_tbl.sql`
- STG Table DDL (Books): `schema/tables/158_dmt_fa_asset_book_stg_tbl.sql`
- TFM Table DDL (Headers): `schema/tables/155_dmt_fa_asset_hdr_tfm_tbl.sql`
- TFM Table DDL (Assignments): `schema/tables/157_dmt_fa_asset_assign_tfm_tbl.sql`
- TFM Table DDL (Books): `schema/tables/159_dmt_fa_asset_book_tfm_tbl.sql`
- Validator: `packages/validators/dmt_fa_asset_validator_pkg.*`
- Transformer: `packages/transformers/dmt_fa_asset_transform_pkg.*`
- FBDI Generator: `packages/generators/fbdi/assets/dmt_fa_asset_fbdi_gen_pkg.*`
- Results/Reconciliation: `packages/reconciliation/dmt_fa_asset_results_pkg.*`
- BIP Data Model/Report: `bip/Assets/`

## Reference Files
- `FaMassAdditions.ctl` -- CTL file for FA_MASS_ADDITIONS loader
- `FaMassaddDistributions.ctl` -- CTL file for FA_MASSADD_DISTRIBUTIONS loader
- `FaMcMassRates.ctl` -- CTL file for FA_MC_MASS_RATES loader

## Known Issues
- ~~**APPROVAL_TYPE_CODE missing from FBDI generator.**~~ **FIXED 2026-04-03.** APPROVAL_TYPE_CODE is a CTL expression column (`nvl2(:BATCH_NAME, 'ORA_FA_MASS', NULL)`) — it doesn't consume a CSV field. Fix: populate BATCH_NAME (CSV pos 419) with 'DMT' so the expression evaluates to 'ORA_FA_MASS'.
- ~~**PRORATE_CONVENTION_CODE may be invalid.**~~ **FIXED 2026-04-03.** Valid value is `MID-MONTH` (hyphen), not `MID MONTH` (space). All test scripts updated. Valid values from FA_CONVENTION_TYPES: CAL MONTH, CAL DAILY, CAL NMB, FOL-MTH, HALF YEAR, MID-MONTH, plus others.
- **PostMassAdditions purges FA_MASS_ADDITIONS after posting.** Both BIP tiers originally depended on the interface table. Tier 2 now uses prefix-based matching on FA_ADDITIONS_B (same as Projects fix).
- ~~**Demo instance requires FA approval workflow.**~~ **RESOLVED 2026-06-30.** FA Additions
  approval on the US CORP book was intercepting PostMassAdditions ("submitted for approval…").
  User disabled Additions approval on the book → Post now posts directly to FA_ADDITIONS_B.
  If Assets ever sticks at `posting_status=POST` again, check that book approval is off.

## 2026-06-30 Two-Stage Rebuild (queue model)
- **Job order was reversed in config.** Fixed: `IMPORT_JOB_NAME`=PrepareMassAdditions,
  `POST_LOAD_JOB_NAME`=PostMassAdditions (seed `04_dmt_erp_options_cemli_seed.sql`).
- **`SUBMIT_IMPORT_JOB`** (loader) parametrized for book-code ParameterList + `;`/`,` delimiters,
  exposed in spec.
- **Queue worker `AWAITING_POSTRUN` state** added (`POLL_ONE` + `submit_postrun_job` +
  `dispatch_ess_polls`). Reuses existing `POSTRUN_ESS_JOB_ID` column. Two live-caught bugs
  fixed: status missing from `DMT_WORK_QUEUE_STATUS_CK`; heartbeat dispatcher didn't poll the
  new state.
- **All-or-nothing per FBDI: DISPROVEN by test** (run 106). Oracle does per-record accounting.
- **Multi-book: IMPLEMENTED + TESTED (run 108).** One FBDI per `BOOK_TYPE_CODE`, run completely
  separately. The un-partitioned Assets queue row transforms once, then `EXECUTE_ONE` spawns
  one child queue row per book; each child generates a book-filtered FBDI → load → Prepare →
  **Post(book)** → reconcile, independently. (`g_partition_key` global; generator `p_book`
  filter; `RUN_ASSETS_TRANSFORM_ONLY`; `submit_postrun_job` uses the row's PARTITION_KEY.)
  Validated: US CORP → LOADED, US FIN SVCS CORP → FAILED independently (book-specific COA/
  category mismatch — expected; proves per-book isolation). One book per asset.
  - Minor follow-up: a multi-book row that errors at Prepare currently reconciles to a generic
    `[RECONCILE_ERROR]` rather than the specific Fusion reason (the reason IS in the Prepare ESS
    log / DMT_LOG_TBL). Pre-existing reconcile Tier-1 match nuance, not multi-book-specific.

## Lessons Learned
- **FaMassAdditions.ctl expects exactly 425 CSV columns.** FaMassaddDistributions.ctl expects 66. Always verify generator output count against CTL.
- **EXPRESSION and CONSTANT columns in CTL do NOT consume CSV fields.** Only count non-expression, non-constant lines when determining expected column count.
- **Refactoring FBDI generators is high-risk.** The 3/29 refactor moved from named-column SELECT + PL/SQL append to inline SQL concatenation. This made column counting harder and silently dropped 3 tail columns. When refactoring generators, always verify output column count against CTL before and after.
- **The 3 missing columns were at the tail:** SPLIT_MERGED_CODE (pos 423), APPROVAL_TYPE_CODE (pos 424), MERGE_PARENT_MASS_ADDITIONS_ID (pos 425). SqlLdr's `trailing nullcols` masks missing tail columns if they have no NOT NULL constraint, but these had SQL expressions that referenced other CSV fields by position — so the misalignment caused cascading data corruption.
- ~~**BIP reconciliation uses "absence = LOADED" pattern:** PostMassAdditions removes successfully posted rows from fa_mass_additions. If BIP returns no error rows, all GENERATED rows are marked LOADED.~~ **RESOLVED 2026-04-02:** Switched to two-tier BIP (interface + base table). No more absence=LOADED.
- **Never assume absence=LOADED without positive verification.** Two-tier BIP pattern queries both interface AND base tables. If neither has the row, it's FAILED, not silently LOADED.
- **PostMassAdditions purges FA_MASS_ADDITIONS after posting.** Tier 2 originally used `EXISTS (SELECT 1 FROM fa_mass_additions ma WHERE ma.load_request_id = :P_BATCH_ID)` to join to FA_ADDITIONS_B, but this returns 0 when interface rows are purged. Fixed to prefix-based matching: `WHERE a.asset_number LIKE :P_PREFIX || '%'`.
- **CTL EXPRESSION columns don't consume CSV fields.** SPLIT_MERGED_CODE, APPROVAL_TYPE_CODE, and MERGE_PARENT_MASS_ADDITIONS_ID are EXPRESSION columns (they reference `:OTHER_FIELD_NAME`, not `:SELF`). They are derived server-side by SQL*Loader from other CSV fields. The correct CSV field count is 422, not 425. To populate APPROVAL_TYPE_CODE, populate BATCH_NAME (CSV pos 419) — the expression `nvl2(:BATCH_NAME, 'ORA_FA_MASS', NULL)` does the rest.
- **PrepareMassAdditions is a child of InterfaceLoaderController, not PostMassAdditions.** It runs BEFORE PostMassAdditions and its ERROR state is visible in ESS hierarchy (DMT_ESS_JOB_TBL). If it fails, PostMassAdditions has nothing to post — ESS status is SUCCEEDED but 0 rows reach FA_ADDITIONS_B.
- **ESS output download works for SqlLdr child jobs.** `GET_ESS_OUTPUT_TEXT(sqlldr_ess_id)` returns the full SqlLdr log with row counts and column mappings. Essential for diagnosing column-count mismatches.
- **PrepareMassAdditions output reveals the actual rejection reasons.** `GET_ESS_OUTPUT_TEXT(prepare_ess_id)` shows per-asset errors. This is the primary diagnostic for Assets failures — not BIP, not the PostMassAdditions output (which is empty).
- **Expense account cross-validation rule:** When Natural Account (segment 3) is between 10000-39999 (Balance Sheet), Cost Center (segment 2) must be '000'. Regression data had segment2='10' with segment3='15160' → PrepareMassAdditions rejected with "You must enter a valid expense account." Fixed by using expense natural account 68010.
- **BATCH_NAME removed from FBDI generator.** The 'DMT' value at CSV position 419 triggered ORA_FA_MASS approval workflow. Reverted to empty string. BATCH_NAME/APPROVAL_TYPE_CODE needs instance-specific configuration.

## History
- 2026-03-23: 2 rows reached LOADED in Fusion. Working state.
- 2026-03-29: Broke by refactor (commit 9c49546). SqlLdr started rejecting all rows.
- 2026-04-01: Root cause found — 3 missing columns (positions 423-425) in generator. Fix committed (7b1220d).
- 2026-04-01: Fix deployed to ATP and verified. 6/6 rows LOADED (2 headers, 2 books, 2 assignments). Load ESS 9391554 SUCCEEDED, Import ESS 9391568 SUCCEEDED.
- 2026-04-02: BIP audit — switched to two-tier reconciliation.
  - Tier 1: FA_MASS_ADDITIONS (interface table errors/status)
  - Tier 2: FA_ADDITIONS_B (base table, positive confirmation)
  - Added P_IMPORT_ESS_ID parameter to BIP data model
  - Eliminated absence=LOADED fallback. Unmatched GENERATED rows now FAILED with RECONCILE_ERROR.
- 2026-04-02: Regression test — 0L/6F/12O. Load ESS error (SQL*Loader rejection). FBDI data quality issue — likely column count or format mismatch. Books/assignments stuck at GENERATED (no cascade from failed headers).
- 2026-04-03 (DB-17): **Root cause found.** PrepareMassAdditions (ESS child job) rejects all rows with:
  - "You must enter a valid prorate convention" (MID MONTH not valid on demo instance)
  - "must select an approval type" (APPROVAL_TYPE_CODE is NULL — position 424 not in generator)
  - SqlLdr loads succeed (2 rows each for headers + distributions), but PrepareMassAdditions fails, so PostMassAdditions has 0 rows to post.
- 2026-04-03 (DB-17): **BIP Tier 2 fix deployed.** Changed from EXISTS-via-interface-table to prefix-based matching on FA_ADDITIONS_B.ASSET_NUMBER. Added P_PREFIX parameter. Cannot verify until data quality issues are fixed.
- 2026-04-03 (DB-17): ESS output download confirmed working for SqlLdr child jobs and PrepareMassAdditions output.
- 2026-04-03 (DB-18): **Both root causes fixed.**
  - BATCH_NAME (CSV pos 419) now populated with 'DMT' → CTL expression derives APPROVAL_TYPE_CODE = 'ORA_FA_MASS'
  - PRORATE_CONVENTION_CODE fixed from 'MID MONTH' to 'MID-MONTH' in all test scripts
  - Valid values from FA_CONVENTION_TYPES: MID-MONTH, CAL MONTH, CAL DAILY, FOL-MTH, HALF YEAR, etc.
  - Pending: deploy updated generator to ATP, re-insert test data with correct prorate, retest pipeline
- 2026-04-07 (DB-27): Expense account fix (68010). BATCH_NAME removed (approval workflow blocker). Assets blocked on demo instance approval config.
- 2026-04-08 (DB-30): **FA approval fix researched.** Three options identified:
  - **Option A (recommended):** Manage Asset Books → US CORP → Enable Approvals → deselect "Additions". Single UI setting. Keep BATCH_NAME='DMT'. PostMassAdditions will post directly.
  - **Option B:** Download "Asset Transaction Approval Basic Template" spreadsheet via Manage Workflow Rules, add auto-approve rule for BATCH_NAME='DMT', upload.
  - **Option C:** Use BPM REST API (`PUT /bpm/api/4.0/tasks/{id}` with `{"action":{"id":"APPROVE"}}`) to programmatically approve pending tasks after PostMassAdditions.
  - Next step: Apply Option A on demo instance with fin_impl user, re-enable BATCH_NAME='DMT' in FBDI generator, retest.
