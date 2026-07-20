# UnitsOfMeasure — Gold Regression Fixture (PASS — live to base tables)

**Result: PASS (2026-07-20).** Units of Measure now loads live to the Fusion base tables
through a non-UI mechanism: the Functional Setup Manager (FSM) "Setup Data Import from CSV
file" REST resource `setupTaskCSVImports`. This is the same standalone path the GLCalendar
investigation discovered — but where GLCalendar stayed tabled, UOM goes all the way to the
base table, because UOM is an ordinary flat-CSV FSM object, not an "External Loading" one.

## Why it was tabled before, and what changed

The earlier note tabled UOM because the gold harness only knew one loader: the ERP
`loadAndImportData` FBDI path (UCM upload → Load Interface File → import ESS job → interface
table). UOM has no interface table and no import ESS job, so that path could never run it.

The new mechanism is different. It does not touch an interface table at all. It hands a CSV
setup package straight to the FSM importer, which calls the SCM `UnitOfMeasureService` and
writes the base tables directly:

- **REST:** `POST /fscmRestApi/resources/11.13.18.05/setupTaskCSVImports`
- **TaskCode:** `INV_MANAGE_UNITS_OF_MEASURE` ("Manage Units of Measure"), found via
  `GET setupTasks?q=TaskName LIKE '%Units of Measure%'`.
- **Import supported:** `GET setupTaskCSVImports/INV_MANAGE_UNITS_OF_MEASURE` returns
  `ImportSupportedFlag: true`.
- **Auth:** HTTP Basic, credential role `scm_impl` (UOM is SCM).
- **Content-Type:** `application/vnd.oracle.adf.resourceitem+json`.

## The critical difference from GLCalendar (why UOM passes and calendars did not)

GLCalendar is an **"External Loading"** object: its data is a service-loaded XML batch nested
inside `Calendar/1_BATCH.zip`, the export on this pod always exceeded the 10 MB per-file limit
(191 calendars), and every constructed batch was silently skipped. **UOM has none of those
problems.** A live export of the UOM task (`setupTaskCSVExports`) completed cleanly and produced
**flat CSVs at the zip root** — no nested `1_BATCH.zip`, no size wall:

```
ASM_SETUP_CSV_METADATA.xml
INV_UNIT_OF_MEASURE_CLASS.csv
INV_UNIT_OF_MEASURE.csv
INV_UNIT_OF_MEASURE_TRANSLATION.csv
ORA_INV_UNIT_OF_MEASURE_STD_CONVERSION.csv
ORA_RCS_PACKAGING_STRINGS.csv
```

Because the exported shape is a plain CSV the importer parses directly, we could mimic it
exactly and re-import. (The manifest still lists `IncludeExternalDataFlag=Y` on the UOM business
objects, but in practice the importer accepted the flat CSVs and loaded them — so that flag is
not a blocker for UOM the way it was for calendars.)

## What we built and ran (live, 2026-07-20)

A minimal import package — just the two members needed to add UOMs to an existing class, plus
the real manifest (with `ProcessType` flipped `EXPORT`→`IMPORT`):

- `ASM_SETUP_CSV_METADATA.xml` — the live-exported manifest.
- `INV_UNIT_OF_MEASURE.csv` — three UOM rows (two good, one bad).
- `INV_UNIT_OF_MEASURE_TRANSLATION.csv` — one US name row per UOM.

**CSV format (learned from the export):** a header row of column names, comma-separated, every
value double-quoted, CRLF line endings. Header names map the columns, so only the minimal set is
needed: `UnitOfMeasure, UomCode, BaseUomFlag, Description, UomClassCode, HasGeneratedCode` for the
UOM file, and `INV_UNIT_OF_MEASURE.UnitOfMeasure, UnitOfMeasure, Description, Language, SourceLang`
for the translation file (the first column is the foreign key back to the parent UOM by name).

Zipped and driven through the importer: `POST setupTaskCSVImports` returned **HTTP 201** with
ProcessId `100007866630872` (ESS request `9765360`); polled `ProcessCompletedFlag` to true;
read `ProcessLog` for per-row outcomes.

## Good / bad design (portable, rules 6–8)

A UOM is standalone reference data. Nothing is hardcoded:

- **Good:** two NEW non-base UOMs placed inside the **largest existing UOM class, discovered
  live** (`SELECT UOM_CLASS ... GROUP BY UOM_CLASS ORDER BY COUNT(*) DESC` — class `5`,
  "Quantity", on this pod). `UOM_CODE` is capped at 3 characters in Fusion, so the run
  `${PREFIX}` cannot live in the code; instead three unused 3-char codes are picked at load time
  and the `${PREFIX}` is carried in the UOM **name/description** (`GldRegUOM ${PREFIX} A` / `B`),
  which is how we verify.
- **Bad:** a NEW UOM with `UomClassCode = ZZ_NO_SUCH_CLASS` — a class that does not exist. The
  importer rejects it deterministically and it never reaches the base table. Pod-independent, no
  bad reference data required.

## Live evidence (base-table pass)

| Item | Value |
|---|---|
| Date | 2026-07-20 |
| Prefix | 90210 |
| Discovered class | `5` (Quantity) |
| Good UOM codes | `GAA`, `GAB` |
| **Good base rows** | `INV_UNITS_OF_MEASURE_B` UNIT_OF_MEASURE_ID **300000331549888** (GAA), **300000331549889** (GAB) — names `GldRegUOM 90210 A` / `GldRegUOM 90210 B` in `INV_UNITS_OF_MEASURE_TL` (US) |
| Bad UOM code | `GAC` |
| **Bad error** | `UnitOfMeasure:Import-Export Process : UomClass does not exist; skipping record. (uom :GldRegUOM 90210 BAD,uomCode:GAC,uomClassCode:ZZ_NO_SUCH_CLASS) ,Skipping the row` |
| Bad in base? | **No** — `GAC` absent from `INV_UNITS_OF_MEASURE_B` (confirmed) |
| Import ProcessId / ESS | `100007866630872` / `9765360` |
| Export ProcessId / ESS | `100007866630828` / `9765315` |

ProcessLog summary: "A total of 2 rows were processed. 1 rows of them failed" — the one failure
is the intended bad row; both good rows loaded.

## Verify SQL (read-only BIP, scm_impl)

Good UOMs reached base (expect 2 rows with real ids):
```sql
SELECT b.UOM_CODE, b.UNIT_OF_MEASURE_ID, b.UOM_CLASS, t.UNIT_OF_MEASURE
FROM   INV_UNITS_OF_MEASURE_B b
JOIN   INV_UNITS_OF_MEASURE_TL t ON t.UNIT_OF_MEASURE_ID = b.UNIT_OF_MEASURE_ID
WHERE  t.LANGUAGE = 'US' AND t.UNIT_OF_MEASURE LIKE 'GldRegUOM ${PREFIX}%';
```
Bad UOM absent (rejection proof — expect zero rows):
```sql
SELECT UOM_CODE FROM INV_UNITS_OF_MEASURE_B WHERE UOM_CODE = '${BAD_CODE}';
```

## How to re-run

The FSM CSV import is object-agnostic and lives in `harness/load_fsm_csv.py` (additive helper:
task discovery, ImportSupportedFlag check, `run_import(task, zip_bytes, role)` submit+poll+log).
Package construction (discover class, pick free codes, build CSVs + manifest, zip) is the
per-object step. The exported reference members are the authoritative CSV shape; rebuild the
package by mimicking them exactly and re-import with `INV_MANAGE_UNITS_OF_MEASURE`, role
`scm_impl`.

## Files

- `recipe.json` — machine-readable PASS recipe: task discovery, import body, poll paths, CSV
  columns, discovery queries, good/bad design, verify SQL, live evidence.
- `artifact/UnitsOfMeasure_gold.zip` — the proven import package (manifest + two CSVs) with the
  loaded fixture.
- `artifact/ASM_SETUP_CSV_METADATA.xml`, `INV_UNIT_OF_MEASURE.csv`,
  `INV_UNIT_OF_MEASURE_TRANSLATION.csv` — the package members.

## Sources

- Oracle: [Automate Export and Import of CSV File Packages](https://docs.oracle.com/en/cloud/saas/applications-common/25c/oafsm/automate-export-and-import-of-csv-file-packages.html)
- Oracle: [Get a setup task CSV import (REST, Common Features)](https://docs.oracle.com/en/cloud/saas/applications-common/25c/farca/op-fscmrestapi-resources-11.13.18.05-setuptaskcsvimports-taskcode-get.html)
