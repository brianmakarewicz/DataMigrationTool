# PaymentTerms — Gold Regression Fixture (PASS — live to base tables)

**Result: PASS (2026-07-20).** Payables Payment Terms now loads live to the Fusion base tables
`AP_TERMS_B` / `AP_TERMS_TL` through a non-UI mechanism: the Functional Setup Manager (FSM)
"Setup Data Import from CSV file" REST resource `setupTaskCSVImports`. This is the same
standalone path proven for Units of Measure, and it works here for the same reason — Manage
Payment Terms exports as **flat CSVs at the zip root** that the importer parses directly, so we
can mimic the exported shape exactly and re-import.

## Why it was tabled before, and what changed

The earlier note (2026-07-19) tabled Payment Terms as having "no standalone bulk load path": no
FBDI interface table, no HDL loader, and the `payablesPaymentTerms` REST resource is read-only
(GET-only; a POST returns 403). All of that is still true — but it missed the FSM CSV import
path, which had not been proven when the note was written. The FSM importer does not touch an
interface table or the read-only REST resource. It hands a CSV setup package straight to the
Payables `PaymentTermService` and writes the base tables directly:

- **REST:** `POST /fscmRestApi/resources/11.13.18.05/setupTaskCSVImports`
- **TaskCode:** `AP_MANAGE_PAYMENT_TERMS` ("Manage Payment Terms"), found via
  `GET setupTasks?q=TaskName LIKE '%Payment Terms%'`.
- **Import supported:** `GET setupTaskCSVImports/AP_MANAGE_PAYMENT_TERMS` returns
  `ImportSupportedFlag: true`.
- **Auth:** HTTP Basic, credential role `fin_impl` (Payment Terms is a Payables/Financials object).
- **Content-Type:** `application/vnd.oracle.adf.resourceitem+json`.

## The package shape (learned from a live export, 2026-07-20)

A live export of the task (`setupTaskCSVExports` of `AP_MANAGE_PAYMENT_TERMS`, ProcessId
`100007866630921`, ESS request `9765461`) completed cleanly and produced **flat CSVs at the zip
root** plus the manifest — no nested batch zip, no 10 MB per-file wall:

```
ASM_SETUP_CSV_METADATA.xml
AP_TERM_HEADER.csv
AP_TERM_LINE.csv
AP_TERM_HEADER_TRANSLATION.csv
AP_TERM_SUBSCRIPTION.csv
```

A payment term is **four related record types**, all keyed back to the header by term Name:

- **AP_TERM_HEADER** — the term. Minimal columns used: `Name, EnabledFlag, Type (STD),
  StartDateActive, Description`. Dates are `YYYY/MM/DD`.
- **AP_TERM_LINE** — one or more installment lines. FK column `AP_TERM_HEADER.Name`, then
  `SequenceNum, DuePercent, DueDays`. Net-30 is one line with `DuePercent=100, DueDays=30`.
- **AP_TERM_HEADER_TRANSLATION** — the US name/description. FK `AP_TERM_HEADER.Name`, then
  `Name, Description, Language, SourceLang`.
- **AP_TERM_SUBSCRIPTION** — assigns the term to a **reference data set**. FK
  `AP_TERM_HEADER.Name`, then `SetCode`. A term must belong to a set that exists; the importer
  resolves `SetCode` to a `SetId`. On this pod the most-used reference set is `COMMON` (22 seeded
  subscriptions; discovered live from the export, not hardcoded).

## What we built and ran (live, 2026-07-20)

A minimal import package — the real manifest (with `ProcessType` flipped `EXPORT`→`IMPORT`) plus
the four member CSVs, three term rows each (two good, one bad):

- Zipped and driven through `harness/load_fsm_csv.py --task AP_MANAGE_PAYMENT_TERMS --role fin_impl`.
- `POST setupTaskCSVImports` returned **HTTP 201** with ProcessId `100007867615386` (ESS request
  `9765468`); polled `ProcessCompletedFlag` to true; read `ProcessLog` for per-row outcomes.
- ProcessLog: "A total of 3 rows were processed. 1 rows of them failed" — the one failure is the
  intended bad row; both good terms loaded to base.

## Good / bad design (portable, rules 6–8)

A payment term is standalone Payables reference data. Nothing is hardcoded:

- **Good:** two NEW terms — `GldRegTerm ${PREFIX} A` (net-30, one line `DuePercent=100, DueDays=30`)
  and `GldRegTerm ${PREFIX} B` (net-45, `DuePercent=100, DueDays=45`), each subscribed to the
  discovered reference set `COMMON`. The run `${PREFIX}` lives in the term **Name** (which is how
  we verify), so re-runs never collide.
- **Bad:** a NEW term `GldRegTerm ${PREFIX} BAD` whose subscription names `SetCode =
  ZZ_NO_SUCH_SET`, a reference set that does not exist. The importer cannot resolve it to a
  `SetId`, rejects the whole term deterministically, and it never reaches `AP_TERMS_B`.
  Pod-independent, no bad reference data required. (This mirrors the UOM invalid-class pattern.)

## Live evidence (base-table pass)

| Item | Value |
|---|---|
| Date | 2026-07-20 |
| Prefix | 90212 |
| Reference set (good) | `COMMON` (discovered live — most-used set on this pod) |
| Good term A (net-30) | `AP_TERMS_B` TERM_ID **300000331550019**, name `GldRegTerm 90212 A` in `AP_TERMS_TL` (US); line seq 1 `DUE_PERCENT=100 DUE_DAYS=30` |
| Good term B (net-45) | `AP_TERMS_B` TERM_ID **300000331550020**, name `GldRegTerm 90212 B` in `AP_TERMS_TL` (US); line seq 1 `DUE_PERCENT=100 DUE_DAYS=45` |
| Bad term | `GldRegTerm 90212 BAD` (SetCode `ZZ_NO_SUCH_SET`) |
| **Bad error** | `JBO-27024: Failed to validate a row ... in PaymentTermSubscriptionEO / JBO-27014: Attribute SetId in PaymentTermSubscriptionEO is required` — the nonexistent set has no SetId, so the term is rejected |
| Bad in base? | **No** — `GldRegTerm 90212 BAD` absent from `AP_TERMS_TL`/`AP_TERMS_B` (confirmed) |
| Import ProcessId / ESS | `100007867615386` / `9765468` |
| Export ProcessId / ESS | `100007866630921` / `9765461` |

## Verify SQL (read-only BIP, fin_impl)

Good terms reached base (expect 2 rows with real ids):
```sql
SELECT t.NAME AS TERM_NAME, b.TERM_ID AS TERM_ID
FROM   AP_TERMS_B b
JOIN   AP_TERMS_TL t ON t.TERM_ID = b.TERM_ID
WHERE  t.LANGUAGE = 'US' AND t.NAME LIKE 'GldRegTerm ${PREFIX}%';
```
Bad term absent (rejection proof — expect zero rows):
```sql
SELECT t.NAME FROM AP_TERMS_TL t
WHERE  t.LANGUAGE = 'US' AND t.NAME = 'GldRegTerm ${PREFIX} BAD';
```

## How to re-run

The FSM CSV import is object-agnostic and lives in `harness/load_fsm_csv.py` (unchanged: task
discovery, `ImportSupportedFlag` check, `run_import(task, zip_bytes, role)` submit+poll+log).
Package construction (build the four CSVs + manifest, zip) is the per-object step; the exported
reference members in `artifact/` are the authoritative CSV shape. Rebuild the package by mimicking
them exactly and re-import with `AP_MANAGE_PAYMENT_TERMS`, role `fin_impl`.

## Files

- `recipe.json` — machine-readable PASS recipe: task discovery, import body, poll paths, CSV
  columns, discovery notes, good/bad design, verify SQL, live evidence.
- `artifact/PaymentTerms_gold.zip` — the proven import package (manifest + four CSVs).
- `artifact/ASM_SETUP_CSV_METADATA.xml`, `AP_TERM_HEADER.csv`, `AP_TERM_LINE.csv`,
  `AP_TERM_HEADER_TRANSLATION.csv`, `AP_TERM_SUBSCRIPTION.csv` — the package members.

## Sources

- Oracle: [Automate Export and Import of CSV File Packages](https://docs.oracle.com/en/cloud/saas/applications-common/25c/oafsm/automate-export-and-import-of-csv-file-packages.html)
- Oracle: [Get a setup task CSV import (REST, Common Features)](https://docs.oracle.com/en/cloud/saas/applications-common/25c/farca/op-fscmrestapi-resources-11.13.18.05-setuptaskcsvimports-taskcode-get.html)
