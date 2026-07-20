# Lookups — GOLD fixture (✅ LIVE-PROVEN via FSM CSV import)

**Object:** Application Standard / Common Lookups (a lookup *type* plus its lookup *codes*).
**Base tables:** `FND_LOOKUP_TYPES_B` / `FND_LOOKUP_TYPES_TL` (the type),
`FND_LOOKUP_VALUES_B` / `FND_LOOKUP_VALUES_TL` (the codes).
**Status:** ✅ **LIVE-PROVEN 2026-07-20.** prefix `90777`, import ProcessId
`100007866630904` / ESS request `9765415` (fin_impl). Never faked.

## The correction: it is NOT UI-only

Lookups was previously tabled as "UI-only" (the *Manage Standard Lookups → Actions → Import*
click). That was wrong. There **is** a standalone, non-UI, no-DMT-code load path — the same
FSM "Setup Data Import from CSV file" REST mechanism that GLCalendar discovered and
UnitsOfMeasure proved:

- **REST resource:** `POST /fscmRestApi/resources/11.13.18.05/setupTaskCSVImports`
- **Task code (confirmed live):** `FND_MANAGE_STANDARD_LOOKUPS` ("Manage Standard Lookups").
  `FND_MANAGE_COMMON_LOOKUPS` also exists and also reports import-supported.
- **Import supported (confirmed live):** `GET setupTaskCSVImports/FND_MANAGE_STANDARD_LOOKUPS`
  returns `ImportSupportedFlag: true`.
- **Auth:** HTTP Basic, credential role `fin_impl`.
- **Driver:** the object-agnostic harness helper `harness/load_fsm_csv.py`
  (submit base64 zip → poll `ProcessCompletedFlag` → read `ProcessLog`).

## Why Lookups loads where GLCalendar did not

GLCalendar is an **"External Loading"** object: its batch is service-loaded XML through a SOA
service, so the flat CSVs we built were always skipped ("all the related CSV files are missing
or empty"), and the pod could not export a reference batch (191 calendars → 13.24 MB, over the
10 MB export limit).

Standard Lookups is a **plain flat-CSV object.** The live import ProcessLog says
**"Total Objects for External Loading: 0"** — the CSVs load directly through the `LookupWS`
service. And the export is small enough to succeed: `setupTaskCSVExports` for
`FND_MANAGE_STANDARD_LOOKUPS` completed (7,423 rows), emitting the real flat CSVs so we could
mimic the exact accepted shape.

## The exact package (learned from a live export, then re-imported)

Three files at the **root** of the zip (not nested in a batch subzip):

1. **`FND_APP_STANDARD_LOOKUP.csv`** — the lookup **types**. Header:
   `LookupType,Meaning,Description,CreatedBy,CreationDate,LastUpdatedBy,LastUpdateDate,LastUpdateLogin,ModuleId,CustomizationLevel,RestAccessSecured,BossAppPackageName,BossAppPackageVersion,BossModuleName,BossIdentifier`
2. **`ORA_FND_APP_STANDARD_LOOKUP_CODE.csv`** — the lookup **codes**. Header:
   `FND_APP_STANDARD_LOOKUP.LookupType,LookupCode,Meaning,Description,EnabledFlag,StartDateActive,EndDateActive,DisplaySequence,CreatedBy,CreationDate,LastUpdatedBy,LastUpdateDate,LastUpdateLogin,Tag`
   The **first column is parent-qualified** (`FND_APP_STANDARD_LOOKUP.LookupType`) — it links
   each code back to its type.
3. **`ASM_SETUP_CSV_METADATA.xml`** — the real exported manifest with `ProcessType` flipped
   `EXPORT` → `IMPORT`. It declares the two business objects, their node paths
   (`/StandardLookupType1VO/StandardLookupType1VORow` and `.../Lookup1VO/Lookup1VORow`), and the
   `LookupWS` service.

**CSV format (this supersedes the old UI-doc assumption).** Comma-delimited, **every field
double-quoted**, CRLF line ends, header row present, dates `YYYY/MM/DD HH24:MI:SS.FF`. NOT the
pipe-delimited unquoted format the UI *Import Lookups* documentation describes — the FSM CSV
package importer uses the quoted-comma export shape.

Fixture files (`artifact/`, `${PREFIX}` tokens): `FND_APP_STANDARD_LOOKUP.csv`,
`ORA_FND_APP_STANDARD_LOOKUP_CODE.csv`, `ASM_SETUP_CSV_METADATA.xml`.

## Portability (rules 6–8)

Standalone reference data — a lookup type borrows nothing. The good type carries a fresh numeric
`${PREFIX}` (`RT_GOLD_90777`) so re-runs never collide and nothing depends on earlier loads.
`ModuleId` for the FND application (`40B3FA7250D19380E040449823C67A1A`) is read once from the
live export; it is the seeded FND module present on every pod, so no discovery is needed.

## Good / bad design

- **Good:** lookup type `RT_GOLD_${PREFIX}` with two enabled codes `G1`, `G2`.
- **Bad (deterministic rejection):** a code `BAD1` whose parent `LookupType` =
  `RT_NO_SUCH_TYPE_${PREFIX}` is **not** in the type CSV. The importer skips it with
  *"Parent row is missing in file FND_APP_STANDARD_LOOKUP.csv … Row will be skipped"*, so it
  never reaches `FND_LOOKUP_VALUES` — pod-independent, needs no bad reference data.

## Verify SQL (read-only BIP, direct reads)

The BIP relay data source (`ApplicationDB_FSCM`) is **not** granted the `_B` tables directly
(`ORA-00942`), but **is** granted the translated views `FND_LOOKUP_TYPES_VL` /
`FND_LOOKUP_VALUES_VL`, which sit over `_B` + `_TL`. Verify through the `_VL` views.

Good type reached base:
```sql
SELECT lookup_type FROM fnd_lookup_types_vl WHERE lookup_type = 'RT_GOLD_${PREFIX}';
```
Good codes reached base:
```sql
SELECT lookup_type, lookup_code FROM fnd_lookup_values_vl
 WHERE lookup_type = 'RT_GOLD_${PREFIX}' AND lookup_code IN ('G1','G2');
```
Bad code absent from base (rejection proof):
```sql
SELECT lookup_type, lookup_code FROM fnd_lookup_values_vl
 WHERE lookup_type = 'RT_NO_SUCH_TYPE_${PREFIX}';   -- expect zero rows
```

## Live evidence (2026-07-20)

| Item | Value |
|---|---|
| Prefix | `90777` |
| Import ProcessId | `100007866630904` |
| ESS request id | `9765415` |
| Import status | Completed with warnings — 3 code rows processed, bad row skipped |
| Reference export ProcessId / ESS | `100007866630815` / `9765313` (7,423 rows, flat CSVs emitted) |
| Good type in base | `RT_GOLD_90777` in `FND_LOOKUP_TYPES_VL` |
| Good codes in base | `G1`, `G2` in `FND_LOOKUP_VALUES_VL` (meanings "RT Gold Code 1/2 90777") |
| Bad row | `BAD1` under `RT_NO_SUCH_TYPE_90777` — importer "Parent row is missing … Row will be skipped"; absent from base |

## Sources

- Oracle: [Automate Export and Import of CSV File Packages](https://docs.oracle.com/en/cloud/saas/applications-common/25c/oafsm/automate-export-and-import-of-csv-file-packages.html)
- Oracle: [Get a setup task CSV import (REST, Common Features)](https://docs.oracle.com/en/cloud/saas/applications-common/25c/farca/op-fscmrestapi-resources-11.13.18.05-setuptaskcsvimports-taskcode-get.html)
- Oracle: [File Format for Importing Lookups](https://docs.oracle.com/en/cloud/saas/applications-common/25b/facia/file-format-for-importing-lookups.html) (the UI pipe-delimited path — superseded here by the FSM CSV-package shape learned from a live export)
