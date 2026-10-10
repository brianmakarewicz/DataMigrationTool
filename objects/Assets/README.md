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
- **Reconcile key: ASSET_NUMBER** — Fusion honors a supplied (prefixed) asset_number, so it
  survives to `fa_additions_b`. It is used only to match a returned row to its TFM row; rows
  are found by the load job id (see "Reconciliation by Fusion job id" below).

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

## Table-name vs FBDI-tab audit (backlog #90, 2026-10-01)

Backlog #90 asks whether every STG/TFM table name mirrors the FBDI CSV tab
(record type) it loads. The Assets object model rule is "one object = one FBDI zip
= one tab per record type". The Assets FBDI template `FaMassAdditions.xlsm` has
three tabs / interface tables; DMT models two of them with three source tables.

**The mapping (from the generator `DMT_FA_ASSET_FBDI_GEN_PKG` + the three `.ctl`):**

| FBDI tab / CSV | Interface table | Source STG table | Source TFM table | Verdict |
|---|---|---|---|---|
| FaMassAdditions.csv | FA_MASS_ADDITIONS | DMT_FA_ASSET_HDR_STG_TBL **+** DMT_FA_ASSET_BOOK_STG_TBL | DMT_FA_ASSET_HDR_TFM_TBL **+** DMT_FA_ASSET_BOOK_TFM_TBL | NAME-MISALIGNED, model correct |
| FaMassaddDistributions.csv | FA_MASSADD_DISTRIBUTIONS | DMT_FA_ASSET_ASSIGN_STG_TBL | DMT_FA_ASSET_ASSIGN_TFM_TBL | NAME-MISALIGNED (Assign = Distributions), model correct |
| FaMcMassRates.csv | FA_MC_MASS_RATES | *(none)* | *(none)* | NOT MODELED -- documented gap |

**Why the names drift but the model is correct (NOT a wrong-record-type defect):**
- The single `FaMassAdditions` tab fuses asset identity and per-book financial /
  depreciation data into one row. One asset can have many books, so DMT correctly
  normalizes that one tab into two source tables -- `HDR` (asset descriptive, one
  per asset) and `BOOK` (financial, one per asset-book). The generator JOINs them on
  `ASSET_NUMBER` to emit one FaMassAdditions row per asset-book. So "two tables feed
  one tab" is a deliberate normalization, not a modeling error.
- `ASSIGN` is the DMT name for the assignment/distribution record type; the Fusion
  tab for the same record type is "Distributions" (`FaMassaddDistributions`). Same
  record type, different label -- a synonym, not a different record type.
- The earlier worry (recorded in backlog #90 and in DMT_DESIGN.html) that DMT might
  have modeled the *wrong* record types ("Book/Assignment where the FBDI wants
  Distributions/Rates") is DISPROVEN here: Book is part of the MassAdditions tab,
  and Assignment IS the Distributions tab.

**Findings (what was fixed vs deferred):**
1. **FIXED (low-risk):** the generator package spec
   `dmt_fa_asset_fbdi_gen_pkg.pks.sql` previously documented the CSVs as
   `FaAssetHeaders.csv / FaAssetAssignments.csv / FaAssetBooks.csv` -- files that
   do not exist. Corrected to the real tabs (`FaMassAdditions.csv`,
   `FaMassaddDistributions.csv`, and the un-modeled `FaMcMassRates.csv`) with the
   HDR+BOOK-feed-one-tab explanation. This is documentation only; no runtime change.
2. **DEFERRED (physical rename, high ripple -- DO NOT do under this item):** renaming
   the three physical tables to match the tabs is NOT unambiguously correct and would
   ripple across ~248 references (eight `dmt_fa_asset_*` packages, the catalog /
   pipeline / upload seeds, views, and the reconcile/results package which a separate
   backlog item owns). Because HDR+BOOK feed one tab, there is no clean 1:1 rename
   anyway (you cannot rename two tables to one tab). Recorded as a finding only.
3. **DOCUMENTED GAP:** the `FaMcMassRates` / "Rates" tab (FA_MC_MASS_RATES,
   multi-currency rate rows) has no STG table, no TFM table, and no generator branch.
   DMT loads the single-currency path only. If multi-currency Assets ever enter scope,
   a `DMT_FA_ASSET_RATES_*` table + a `gen_rates_csv` branch would be required. This
   matches the `FaMcMassRates.ctl` being present as a reference file with no code behind it.

**Registry note (not a misalignment):** `db/seed/dmt_upload_object_tbl.sql` sets
`CSV_FILENAME = <STAGING_TABLE>.csv` (e.g. `DMT_FA_ASSET_HDR_STG_TBL.csv`). That column
is the **inbound DMT upload-template** filename, NOT the Fusion FBDI tab name -- a
different concept (what a user uploads into STG, documented in that seed's header). It
is correctly following its own convention and is out of scope for FBDI-tab alignment.

## Reconciliation by Fusion job id, one call per work item (2026-10-07)

Owner decision: the reconciliation report finds rows only by Fusion job ids, never by searching
on the run prefix. The asset number is used only to match a row Fusion returned to its TFM row.

- **Report V2** `DMT_FA_ASSET_RECON_V2_DM` / `_RPT` (deployed alongside V1, which is never
  overwritten). `FA_ADDITIONS_B`, `FA_BOOKS` and `FA_DISTRIBUTION_HISTORY` have no request id,
  but `FA_MASS_ADDITIONS` keeps each row after Post Mass Additions with the load job's
  `LOAD_REQUEST_ID`, `POSTING_STATUS = 'POSTED'` and the created `ASSET_ID` (its `REQUEST_ID`
  is the Post Mass Additions job). So base assets and their active distributions are found
  through the POSTED mass additions of the load, and interface rejections by
  `LOAD_REQUEST_ID`. No `LIKE` anywhere. Keyset ordering and comparison pinned to BINARY.
  Registry (Assets plus the Assets.Book / Assets.Assignment auditor rows) repointed by the seed
  and `db/migrations/2026-10-07_assets_recon_v2_registry.sql`. `query.sql` now mirrors V2.
- **One call per work item.** One book = one load, so `RECONCILE_BATCH` passes the work item's
  own load id (and import id, for symmetry) to `FETCH_ROWS`. Per-row accounting at the Post
  step and the all-or-nothing SQL*Loader path (`ACCOUNT_ALL_OR_NOTHING`) are unchanged.
- **Recorded ids checked.** The import id comes from the load's own PrepareMassAdditions
  child, so it cannot be taken from another book's load.

Proof run 259 (prefix 93315, scenario RegressionTest2610071920, STANDALONE:Assets): work item
1619 (US CORP) recorded load 10075373, import 10075390 (PrepareMassAdditions, child of
10075373) and post 10075433; Fusion stamped `LOAD_REQUEST_ID` 10075373 and `REQUEST_ID`
10075433 on the three mass additions. Outcomes match run 238: G1 and G2 LOADED on header, book
and assignment (asset ids 581152 / 581153, distributions 399477 / 399478), BAD1 FAILED with
Fusion's "You must enter a valid expense account ID" and its book and assignment quoting it,
0 UNACCOUNTED. Cost staged 156,000 = loaded 155,000 (FA_BOOKS cost 120,000 + 35,000) + failed
1,000. A reconcile-only rerun of work item 1619 left all 9 TFM rows byte-identical.
`dmt_regression_run.py` PASS (review items only: the pre-existing fixedAssets REST verify 404,
also seen on run 238); Playwright click-through PASS.

## A rejected asset carries its error to the rest of its book batch (2026-10-08, backlog #175 / #200)

When SQL*Loader rejects one asset row, the book's whole load commits nothing, so the other
assets of that book never reach FA_MASS_ADDITIONS. `ACCOUNT_ALL_OR_NOTHING` still gives the
rejected asset its own real error from the SQL*Loader log. The other assets of the book used
to get a generic `[BATCH_REJECTED]` sentence; now the new private
`PROPAGATE_DOCUMENT_ERRORS` quotes the rejected asset's real error onto every other header
of the book that did not load, and the existing cascade carries it to their book and
assignment rows:
`[FUSION_ERROR] Rejected with document: book batch <book> asset <asset number>: <real error>`.
It is idempotent, never touches LOADED rows, and only runs inside the existing
all-or-nothing gate (load process genuinely failed, nothing in the book loaded).

**Rejection in the distributions file (backlog #571, 2026-10-09).** A `FA_MASSADD_DISTRIBUTIONS`
rejection used to leave its book unaccounted, because there was no asset row to quote. Now
`ACCOUNT_ALL_OR_NOTHING` maps the distributions log's "Record N" to the assignment row at that
position of the work item's own distributions CSV (rows stamped with the work item id, generator
order `TFM_SEQUENCE_ID`; SQL*Loader counts physical lines, so a value holding a line break spans
several records and they all belong to the same row). That assignment row lands FAILED with its
real SQL*Loader error. `PROPAGATE_DOCUMENT_ERRORS` treats it as a source and quotes it onto every
asset header of the batch, its own header included (design section 5: a distribution error is
added to its header), as `Rejected with document: book batch <book> asset <num> distribution: <error>`;
the cascade carries it to the book and the other assignment rows.

**Import id of a failed load (backlog #573, 2026-10-09).** When a load ends in error, the queue
worker now records an import id only if the load itself ran one: a child of the load in the
captured job hierarchy whose job is the object's import job (PrepareMassAdditions). It no longer
searches for the nearest later import, which gave a failed book another book's id.

Regression cross-grain rows (scenario RegressionTest2610081851): book SUPREMO US CORP with
`RT-ASSET-XG-G1`, `RT-ASSET-XG-BAD` (prorate convention `CAL MONTH LONG`, 14 characters,
longer than FA_MASS_ADDITIONS.PRORATE_CONVENTION_CODE's 10) and `RT-ASSET-XG-G2`; US CORP
(G1, G2, BAD1) is the separate good batch. Proof run 323 (prefix 93378, STANDALONE:Assets):
US CORP G1/G2 LOADED on header, book and assignment, BAD1 FAILED with "You must enter a
valid expense account ID"; SUPREMO load 10081966 rejected XG-BAD with "Error on table
FA_MASS_ADDITIONS, column PRORATE_CONVENTION_CODE. ORA-12899: value too large for column
??? (actual: 14, maximum: 10)" and XG-G1/XG-G2 (header, book, assignment) FAILED quoting it;
0 UNACCOUNTED; `dmt_regression_run.py` PASS with all 18 listed rows matching. A
reconcile-only rerun of work item 2010 (rolled back) left every TFM row identical.

## Field widths match the interface; asset-named cascade; line breaks in the header file (2026-10-09)

- **Widths (backlog #574, owner rule: field width is constrained by the STG and TFM tables).**
  The STG and TFM columns now match the FBDI interface: header `DESCRIPTION` 80 (was 240),
  `MANUFACTURER_NAME` 360 (was 30), `ATTRIBUTE_CATEGORY` 30 (`ATTRIBUTE_CATEGORY_CODE`, was 210);
  book `DEPRECIATION_METHOD` 12 (`METHOD_CODE`, was 30), `PRORATE_CONVENTION_CODE` 10 (was 30).
  Every other Assets column already matched. A value too long for Fusion is now rejected when
  it is staged, naming the column, instead of by SQL*Loader (which rolls back the whole book).
  The table files carry a re-runnable `fit_width` block: widening always applies; narrowing
  applies only when no existing row is longer, otherwise the column is left as it is and a
  line says so (data is never truncated). On the local database `PRORATE_CONVENTION_CODE`
  stays 30 on STG and TFM because older scenarios hold the 14-character `CAL MONTH LONG`.
- **Cascade names the asset (backlog #572).** A book or assignment row of a failed asset now
  carries `[FUSION_ERROR] Rejected with document: asset <asset number>: <header's real error>`
  (shared `FORMAT_DOCUMENT_ERROR`), instead of the unnamed "parent record" form.
- **Header-file line breaks (backlog #650).** `ACCOUNT_ALL_OR_NOTHING` maps a
  FA_MASS_ADDITIONS "Record N" to its header/book row counting the line breaks in every text
  value the generator writes (same approach as the distributions mapping, #571).
- **Regression row change.** `RT-ASSET-XG-BAD` can no longer carry a 14-character prorate
  code (the column is 10 now), so from scenario RegressionTest261009080330 its description
  holds a line break instead. Proof run 357 (prefix 93403, STANDALONE:Assets): SQL*Loader
  rejected SUPREMO records 2 (DESCRIPTION, "second enclosure string not present") and 3 (the
  continuation line, DATE_PLACED_IN_SERVICE); both map to XG-BAD, so XG-G2 (record 4) quotes
  XG-BAD's error instead of taking record 3's as its own. All 27 listed rows met their
  expected outcome, 0 UNACCOUNTED, harness PASS.
- **After #651 (PR #730, line breaks fail in the validator).** XG-BAD is now failed before the
  CSV is written, so XG-G1/XG-G2 load and the header mapping above is a safety net only. The
  book and assignment of a header failed before load now quote it under its own tag
  (`[POST_VALIDATION] Rejected with document: asset <num>: ...`) instead of being left FAILED
  with no text. Run 378 (prefix 93421, scenario RegressionTest261009113635): G1/G2 and
  XG-G1/XG-G2 LOADED on all three grains, BAD1 and XG-BAD FAILED with their real errors. The
  US FIN SVCS batch (XD rows, 8 rows) ends UNACCOUNTED: its assignment is failed by the new
  validator and the rest of the asset is still sent (backlog #745, not this change).

## Known Issues
- ~~**APPROVAL_TYPE_CODE missing from FBDI generator.**~~ **FIXED 2026-04-03.** APPROVAL_TYPE_CODE is a CTL expression column (`nvl2(:BATCH_NAME, 'ORA_FA_MASS', NULL)`) — it doesn't consume a CSV field. Fix: populate BATCH_NAME (CSV pos 419) with 'DMT' so the expression evaluates to 'ORA_FA_MASS'.
- ~~**PRORATE_CONVENTION_CODE may be invalid.**~~ **FIXED 2026-04-03.** Valid value is `MID-MONTH` (hyphen), not `MID MONTH` (space). All test scripts updated. Valid values from FA_CONVENTION_TYPES: CAL MONTH, CAL DAILY, CAL NMB, FOL-MTH, HALF YEAR, MID-MONTH, plus others.
- ~~**PostMassAdditions purges FA_MASS_ADDITIONS after posting.**~~ **Disproven 2026-10-07:** posted rows stay in FA_MASS_ADDITIONS with LOAD_REQUEST_ID and ASSET_ID, so report V2 finds base assets through them by job id instead of by asset-number prefix.
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

## Reconciliation report pages by header (2026-10-09, backlog #682)

The registered report is now `bip/Assets/DMT_FA_ASSET_RECON_V3_DM.xdm`, deployed alongside `DMT_FA_ASSET_RECON_V2_DM` (never overwritten).
It pages on header boundaries (owner decision 2026-10-09, design section 5, "Reconciliation
fetches page on header boundaries"): a page is the next BIP_CHUNK_SIZE headers, keyed by the asset number,
plus every base and interface row that belongs to them, and each row carries that header key in
the tenth column `PAGE_KEY`. `DMT_RECON_CONTRACT_PKG.FETCH_ROWS` counts headers, sends the last
header key back as `P_AFTER_KEY`, has no page cap, and fails the fetch with an error if a page
does not advance. Row selection (job ids only), RECORD_KEYs, FUSION_IDs and error text are the
same as in `DMT_FA_ASSET_RECON_V2_DM`.

## A failed load fails every record type of the book's zip (2026-10-10, backlog #673)

Each book gets its own zip (headers and books in FaMassAdditions.csv, assignments in
FaMassaddDistributions.csv) and its own load job. When the loader sees that load job fail,
`fin_mark_generated_failed` calls `DMT_FA_ASSET_FBDI_GEN_PKG.FAIL_GENERATED_ROWS` with the work
item's book, which sets every GENERATED header, book and assignment row of that book FAILED with the
same `[LOAD_ERROR]` text, scoped exactly as `GENERATE_FBDI` scoped them (no book = all books, the
standalone path). Before, only the header rows were marked, and of every book of the run, while the
book and assignment rows stayed GENERATED until the sweep made them UNACCOUNTED. A load failure cannot honestly be produced from data on this pod, so the proof is the rolled-back
unit test `test/unit/test_load_failure_all_types.sql` (synthetic runs and rows only). This path runs
only when the loader waits on the load itself; the queue-driven path leaves the rows GENERATED for
reconciliation and the shared unaccounted sweep, which already covers every record type.
