# LookupTypes (canonical) — Application Standard / Common Lookups

Durable call-library note for the Lookups object (lookup **types** + their lookup **codes**).
The gold fixture, file format, and verify SQL live in `../Lookups/` — see
`../Lookups/GOLD_README.md` and `../Lookups/recipe.json`.

## What this object is

One migration object = a lookup **type** row plus its child lookup **code** rows.
Base tables: `FND_LOOKUP_TYPES_B` / `FND_LOOKUP_TYPES_TL` (the type),
`FND_LOOKUP_VALUES_B` / `FND_LOOKUP_VALUES_TL` (the codes).

## How it loads — FSM "Setup Data Import from CSV file" (non-UI REST)

**Status: ✅ LIVE-PROVEN 2026-07-20** (prefix `90777`, import ProcessId `100007866630904`,
ESS request `9765415`, fin_impl). Lookups is **not** UI-only — the standalone FSM CSV-package
REST path loads it, the same mechanism GLCalendar found and UnitsOfMeasure proved.

- REST `POST /fscmRestApi/resources/11.13.18.05/setupTaskCSVImports`
- TaskCode **`FND_MANAGE_STANDARD_LOOKUPS`** (`ImportSupportedFlag: true`).
  `FND_MANAGE_COMMON_LOOKUPS` also exists and is import-supported.
- Body `{TaskCode, SetupTaskCSVImportProcess:[{TaskCode, FileContent:<base64 zip>, SourceTargetDiffOkFlag:true}]}`;
  Content-Type `application/vnd.oracle.adf.resourceitem+json`; auth `fin_impl`.
- Poll `.../SetupTaskCSVImportProcess/{id}` for `ProcessCompletedFlag`; read the
  `SetupTaskCSVImportProcessResult/{id}/enclosure/ProcessLog`.
- Driver: `harness/load_fsm_csv.py` (object-agnostic round-trip).

Unlike GLCalendar (an **External Loading** object whose batch never round-trips), Standard
Lookups is a **plain flat-CSV** object — the import ProcessLog reports
"Total Objects for External Loading: 0" and the CSVs load directly through the `LookupWS`
service.

## Package shape (learned from a live export)

Three files at the **root** of the import zip:

- **`FND_APP_STANDARD_LOOKUP.csv`** (types): `LookupType,Meaning,Description,CreatedBy,CreationDate,LastUpdatedBy,LastUpdateDate,LastUpdateLogin,ModuleId,CustomizationLevel,RestAccessSecured,BossAppPackageName,BossAppPackageVersion,BossModuleName,BossIdentifier`
  (required: `LookupType`, `Meaning`, `ModuleId`, `CustomizationLevel=U`, `RestAccessSecured=SECURE`).
- **`ORA_FND_APP_STANDARD_LOOKUP_CODE.csv`** (codes): `FND_APP_STANDARD_LOOKUP.LookupType,LookupCode,Meaning,Description,EnabledFlag,StartDateActive,EndDateActive,DisplaySequence,CreatedBy,CreationDate,LastUpdatedBy,LastUpdateDate,LastUpdateLogin,Tag`
  — first column is the **parent-qualified** type key.
- **`ASM_SETUP_CSV_METADATA.xml`** — the real exported manifest, `ProcessType` `EXPORT`→`IMPORT`.

**Format:** comma-delimited, every field double-quoted, CRLF, header row, dates
`YYYY/MM/DD HH24:MI:SS.FF`. (This supersedes the old pipe-delimited UI-import assumption.)

## Portability

A lookup type is standalone reference data — no upstream dependency. Create a **new** type with
a fresh numeric `${PREFIX}` code (e.g. `RT_GOLD_90777`) + a couple of codes. `ModuleId` for the
FND application (`40B3FA7250D19380E040449823C67A1A`) is read once from the live export; no
per-run discovery needed.

## Bad-row rejection

A code whose parent `LookupType` is absent from the type CSV is skipped by the importer
("Parent row is missing in file FND_APP_STANDARD_LOOKUP.csv … Row will be skipped") and never
reaches the base — the deterministic, pod-independent bad-row proof.

## Verify (read-only BIP, direct reads via the `_VL` views)

The BIP FSCM data source is not granted the `_B` tables (`ORA-00942`) but is granted the `_VL`
views over `_B`+`_TL`:

```sql
SELECT lookup_type FROM fnd_lookup_types_vl WHERE lookup_type = 'RT_GOLD_<prefix>';
SELECT lookup_type, lookup_code FROM fnd_lookup_values_vl
  WHERE lookup_type = 'RT_GOLD_<prefix>' AND lookup_code IN ('G1','G2');
-- bad code, parent type never created -> expect zero rows:
SELECT lookup_code FROM fnd_lookup_values_vl WHERE lookup_type = 'RT_NO_SUCH_TYPE_<prefix>';
```
