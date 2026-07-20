# UnitsOfMeasure (canonical object notes)

**Type:** FSM CSV setup package (NOT an ERP FBDI). **Gold status: PASS (2026-07-20).**

## One-line

A Unit of Measure is standalone SCM reference data. It loads through the Functional Setup
Manager "Setup Data Import from CSV file" REST resource `setupTaskCSVImports` — a non-UI,
no-DMT-code path — straight into the base tables `INV_UNITS_OF_MEASURE_B` / `_TL`. Proven live.

## Load mechanism (found 2026-07-20)

NOT FBDI, NOT HDL. The FSM CSV setup-package import, driven programmatically:

- REST `POST /fscmRestApi/resources/11.13.18.05/setupTaskCSVImports`
- TaskCode **`INV_MANAGE_UNITS_OF_MEASURE`** ("Manage Units of Measure"), discovered via
  `GET setupTasks?q=TaskName LIKE '%Units of Measure%'`; `ImportSupportedFlag: true`.
- Body: `{TaskCode, SetupTaskCSVImportProcess:[{TaskCode, FileContent:<base64 zip>, SourceTargetDiffOkFlag:true}]}`
- Content-Type `application/vnd.oracle.adf.resourceitem+json`; auth role **`scm_impl`** (SCM).
- Poll `.../SetupTaskCSVImportProcess/{id}` for `ProcessCompletedFlag`; read outcome from the
  `SetupTaskCSVImportProcessResult/{id}/enclosure/ProcessLog`.

**Why this works for UOM but the same path stayed tabled for GLCalendar:** UOM exports as
**flat CSVs at the zip root** (no nested batch zip, no export size wall), so the shape is a plain
CSV the importer parses directly and we could mimic it exactly. GLCalendar is an "External
Loading" object whose service-loaded XML batch never round-tripped.

## Package shape

Zip root: `ASM_SETUP_CSV_METADATA.xml` (the real live-exported manifest, `ProcessType`
`EXPORT`→`IMPORT`), `INV_UNIT_OF_MEASURE.csv`, `INV_UNIT_OF_MEASURE_TRANSLATION.csv`. CSVs have a
**header row of column names**, comma-separated, every value double-quoted, CRLF endings. Minimal
UOM columns: `UnitOfMeasure, UomCode, BaseUomFlag, Description, UomClassCode, HasGeneratedCode`.
Translation columns: `INV_UNIT_OF_MEASURE.UnitOfMeasure` (FK to the parent UOM by name),
`UnitOfMeasure, Description, Language, SourceLang`. Member filenames equal the manifest
`BusinessObjectShortName`.

## Portability (rules 6–8)

Nothing hardcoded. Good = two NEW non-base UOMs in the **largest existing UOM class, discovered
live** (`SELECT UOM_CLASS ... GROUP BY UOM_CLASS ORDER BY COUNT(*) DESC`). `UOM_CODE` is 3-char
capped, so the `${PREFIX}` rides in the UOM name/description (`GldRegUOM ${PREFIX} A/B`) and 3
unused codes are picked at load time. Bad = `UomClassCode=ZZ_NO_SUCH_CLASS` (nonexistent class) —
rejected deterministically, never reaches base.

## Verify (read-only BIP, scm_impl)

`INV_UNITS_OF_MEASURE_TL` joins to `_B` on `UNIT_OF_MEASURE_ID` (there is no UOM_ID column). Good
= 2 rows with real ids where `t.UNIT_OF_MEASURE LIKE 'GldRegUOM ${PREFIX}%'`; bad = the bad code
absent from `INV_UNITS_OF_MEASURE_B`.

## Live evidence

Prefix 90210 · class `5` (Quantity) · good codes GAA/GAB → UNIT_OF_MEASURE_ID 300000331549888 /
300000331549889 · bad code GAC rejected ("UomClass does not exist; skipping record") and absent ·
import ProcessId 100007866630872 / ESS 9765360.

See `GOLD_README.md` for the full finding and `recipe.json` for the machine-readable recipe.
