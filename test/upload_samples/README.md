# Upload test samples + FBDI metadata

This directory holds the two upload test zips and the tooling that builds them.

## Test files

| File | Format | Contents |
|---|---|---|
| `regressionProprietary.zip` | Proprietary (header CSVs) | One `DMT_<OBJECT>_STG_TBL.csv` per regression staging table (78 files), each with a header row of real staging-column names; only populated columns are emitted, `SOURCE_ID` always included. |
| `FBDIFormat.zip` | Oracle FBDI (headerless, positional) | Every FBDI file the pipeline's generators write (57 files; PlanningBudgets' EPM file excepted), laid out exactly as the generators emit them. |

Both carry the same data as the current regression baseline scenario
(`scripts/regression_scenario.json`, `current_scenario`) and are loadable by the
auto-detect dispatcher (see below). Load them into a **new** scenario of your
choosing.

## Rebuilding the test files

```
python build_regression_zips.py
```

Reads the baseline scenario's staging data from the local Docker DB (read-only)
and writes both zips here. Column layouts come from `fbdi_column_maps.py`.

`python roundtrip_test.py` uploads both zips, plus the real generated CSVs of the
files backlog #792 registered (from `DMT_FBDI_CSV_TBL`), into new scenarios and
checks counts and every mapped value (see its docstring).

## FBDI column maps

`fbdi_column_maps.py` is the single source of truth for the FBDI column-to-slot
mapping. It is derived from the pipeline FBDI generator packages
(`db/packages/*_fbdi_gen_pkg.pkb.sql`) and cross-checked against the real
generated CSVs in `DMT_FBDI_CSV_TBL`. Its `FILES` list registers one entry per
(FBDI file, staging object) pair; positions are keyed per file (backlog #792).
The committed seed `db/seed/dmt_upload_fbdi_metadata.sql` is generated from this
module (`python gen_fbdi_metadata_seed.py`) into `DMT_UPLOAD_FBDI_FILE_TBL` and
`DMT_UPLOAD_FBDI_POS_TBL`, so the FBDI upload is the exact inverse of FBDI
generation. `scripts/check_fbdi_upload_mappings.py` (CI) fails when a generator
writes a file that is not registered, or when the seed is stale.

---

## UI handoff — "Auto detect by filename"

The DMT APEX app (Data Migration Console) needs one new upload option. **No APEX
change was made here** — this is the spec for whoever edits the app.

1. Add a radio/select option labelled **"Auto detect by filename"** to the upload
   format choice on the upload page (alongside the existing proprietary-zip and
   FBDI-zip options).

2. Point that option at this single procedure, passing the uploaded file's name
   from `APEX_APPLICATION_TEMP_FILES`:

   ```plsql
   DMT_CSV_UPLOAD_PKG.UPLOAD_ZIP_AUTO (
       p_file_name       => :P_FILE,            -- APEX_APPLICATION_TEMP_FILES.NAME
       p_batch_id        => NULL,               -- new batch
       p_summary         => :P_SUMMARY,         -- OUT CLOB  (per-file result lines)
       p_batch_id_out    => :P_BATCH_ID,        -- OUT NUMBER
       p_error_msg       => :P_ERROR,           -- OUT VARCHAR2
       p_use_fast_loader => TRUE,               -- optional, default TRUE
       p_scenario_name   => :P_SCENARIO         -- the target scenario name
   );
   ```

   For each CSV inside the uploaded zip the dispatcher routes by filename:
   a name matching `DMT_UPLOAD_OBJECT_TBL.CSV_FILENAME` goes to the proprietary
   (header-driven) loader; a name registered in `DMT_UPLOAD_FBDI_FILE_TBL` goes to the FBDI
   (positional) loader; anything else is skipped with a warning line in
   `p_summary`. Parent-before-child order (DISPLAY_ORDER) is preserved across the
   whole mixed bundle. Show `p_summary` to the user.

The existing two options remain valid: `UPLOAD_ZIP_BUNDLE` (proprietary only) and
`UPLOAD_FBDI_ZIP` (FBDI only). `UPLOAD_ZIP_AUTO` simply accepts either or a mix.

## FBDI coverage notes

* Every FBDI (`.csv`) file a generator writes is registered, except PlanningBudgets'
  `EpbcsDataImport.csv` (EPM data import, out of scope). HDL (`.dat`) objects are
  out of FBDI scope and are covered by the proprietary format only.
* One file can feed several staging objects: Assets `FaMassAdditions.csv` is the
  asset header joined to the asset book, so it loads the header (one row per
  distinct header, `DISTINCT_ROWS_FLAG`) and the book (in `LOAD_ORDER`).
* Several files can feed one staging object with their own layouts: the PO header
  staging table takes `PoHeadersInterfaceOrder.csv`, `PoHeadersInterfaceBlanket.csv`
  and `PoHeadersInterfaceContract.csv`; the PO line table takes the Order and Blanket
  line files. `STYLE_DISPLAY_NAME` (slot 8 of each header file) is how the
  PurchaseOrders / BlanketPOs / Contracts transforms pick their rows.
* Each file's `DATE_MASK` is the format its generator writes dates in: Grants and
  Billing Events write `MM/DD/YYYY`, every other generator `YYYY/MM/DD`.
* **Links the files cannot carry (follow-up):** an uploaded Assets
  `FaMassaddDistributions.csv` row has no `ASSET_NUMBER` (the generator writes the
  synthetic `MASS_ADDITION_ID` instead), and uploaded MiscReceipts lot and serial
  rows have no `SOURCE_ID` link to their parent transaction (the staging link is
  the parent's staging row id, which a file cannot know). The rows and values
  load; the parent link must be resolved after upload.
* **Items (`EgpSystemItemsInterface.csv`)**: the generator writes columns out to
  slot 370, but `APEX_DATA_PARSER` exposes only `COL001..COL300`. The FBDI loader
  loads every column up to slot 300 and reports the beyond-300 columns
  (GLOBAL_ATTRIBUTE11-20, some ATTRIBUTE*/ATTRIBUTE_NUMBER*/ATTRIBUTE_DATE*) as
  skipped in the result summary. None of those are populated in the regression
  data, so the round-trip is complete for that set; a real Items load that fills
  those columns would need a non-parser path.
