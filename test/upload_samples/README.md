# Upload test samples + FBDI metadata

This directory holds the two upload test zips and the tooling that builds them.

## Test files

| File | Format | Contents |
|---|---|---|
| `regressionProprietary.zip` | Proprietary (header CSVs) | One `DMT_<OBJECT>_STG_TBL.csv` per RegressionTest object (49 files), each with a header row of real staging-column names; only populated columns are emitted, `SOURCE_ID` always included. |
| `FBDIFormat.zip` | Oracle FBDI (headerless, positional) | The FBDI-named CSVs for the 35 FBDI objects in RegressionTest, laid out exactly as the pipeline's FBDI generators emit them. |

Both carry the same data as the RegressionTest scenario (scenario_id 1) and are
loadable by the auto-detect dispatcher (see below). Load them into a **new**
scenario of your choosing.

## Rebuilding the test files

```
python build_regression_zips.py
```

Reads scenario_id 1 staging data from the local Docker DB (read-only) and writes
both zips here. Column layouts come from `fbdi_column_maps.py`.

## FBDI column maps

`fbdi_column_maps.py` is the single source of truth for the FBDI column-to-slot
mapping. It is derived from the pipeline FBDI generator packages
(`db/packages/*_fbdi_gen_pkg.pkb.sql`) and cross-checked against the real
generated CSVs in `DMT_FBDI_CSV_TBL` (run 167). The committed seed
`db/seed/dmt_upload_fbdi_metadata.sql` is generated from this same module, so the
FBDI upload (which reads `FBDI_POSITION`) is the exact inverse of FBDI generation.

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
   (header-driven) loader; a name matching `FBDI_CSV_FILENAME` goes to the FBDI
   (positional) loader; anything else is skipped with a warning line in
   `p_summary`. Parent-before-child order (DISPLAY_ORDER) is preserved across the
   whole mixed bundle. Show `p_summary` to the user.

The existing two options remain valid: `UPLOAD_ZIP_BUNDLE` (proprietary only) and
`UPLOAD_FBDI_ZIP` (FBDI only). `UPLOAD_ZIP_AUTO` simply accepts either or a mix.

## FBDI coverage notes

* 35 FBDI objects are seeded (`FBDI_CSV_FILENAME` + `FBDI_POSITION`). HDL (`.dat`)
  objects are out of FBDI scope and are covered by the proprietary format only.
* Supplier family = five separate objects/files; PO = four record-type files
  (headers/lines/locations/distributions); Customers = seven files; Requisitions
  = three; Projects = four; Grants = header + personnel (regression scope). Each
  physical FBDI CSV routes to its own staging table by its own filename.
* **Items (`EgpSystemItemsInterface.csv`)**: the generator writes columns out to
  slot 370, but `APEX_DATA_PARSER` exposes only `COL001..COL300`. The FBDI loader
  loads every column up to slot 300 and reports the beyond-300 columns
  (GLOBAL_ATTRIBUTE11-20, some ATTRIBUTE*/ATTRIBUTE_NUMBER*/ATTRIBUTE_DATE*) as
  skipped in the result summary. None of those are populated in the regression
  data, so the round-trip is complete for that set; a real Items load that fills
  those columns would need a non-parser path.
* PO/BlanketPO/Contract share the same PO staging tables. Only the standard PO
  "Order" filenames are registered (`PoHeadersInterfaceOrder.csv`, etc.) because a
  filename must map to exactly one object; blanket/contract-specific header
  filenames are intentionally not registered.
