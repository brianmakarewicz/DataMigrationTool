# GLCalendar — GOLD fixture (TABLED: non-UI path reachable, batch payload unverifiable on this pod)

**Object:** GL Accounting Calendar — a calendar (period set) plus its accounting periods.
**Base tables:** `GL_CALENDARS` / `GL_PERIOD_SETS` (calendar header) and `GL_PERIODS` (the periods).
**Status:** 🟡 **TABLED 2026-07-20.** A genuine non-UI (web-service) load path was found and
proven **reachable**, and a portable fixture is built. It is **not** live-proven because the
exact import batch payload could not be validated on this demo pod. Never faked.

## The important difference from Lookups

Lookups was tabled because **no** non-UI load path exists at all (import is a UI-only
Setup-and-Maintenance click). GLCalendar is **not** that case. There **is** a standalone,
web-service, no-UI, no-DMT-code load path, and this demo user can reach it:

- **REST resource:** `POST /fscmRestApi/resources/11.13.18.05/setupTaskCSVImports`
- **Task code (confirmed live):** `GL_MANAGE_ACCOUNTING_CALENDARS`
  (found via `GET setupTasks?q=TaskName LIKE '%Accounting Calendar%'`).
- **Import supported (confirmed live):** `GET setupTaskCSVImports/GL_MANAGE_ACCOUNTING_CALENDARS`
  returns `"ImportSupportedFlag": true`.
- **Auth:** HTTP Basic, credential role `fin_impl`. No procurement/second user needed.

This is the FSM "Setup Data Import from CSV file" mechanism, driven programmatically (not the
UI, not FBDI `loadAndImportData`, not HDL). It is a **new mechanism** for this library — none of
the other 44 objects use `setupTaskCSVImports`.

So why is it tabled? Because for **this specific task** the import content is not a simple flat
CSV that `setupTaskCSVImports` validates directly — it is an **"External Loading" FSM
configuration-package batch** loaded through the SOA service
`oracle.apps.financials.generalLedger.calendars.accounting.calendarsService.CalendarsService`,
and we could not reproduce the exact batch shape it accepts (details below).

## What we proved live (mechanism reachability)

| Step | Endpoint / call | Result (live, 2026-07-20) |
|---|---|---|
| Task exists | `GET setupTasks?q=TaskName LIKE '%Accounting Calendar%'` | `GL_MANAGE_ACCOUNTING_CALENDARS` / "Manage Accounting Calendars" |
| Import supported | `GET setupTaskCSVImports/GL_MANAGE_ACCOUNTING_CALENDARS` | `ImportSupportedFlag: true` |
| Import accepted | `POST setupTaskCSVImports` with base64 zip | HTTP **201**, ProcessId returned, process runs and **completes** |
| Import result | `.../SetupTaskCSVImportProcessResult/{id}/enclosure/ProcessLog` | "Completed successfully" — but **0 objects loaded** |

The importer round-trips fully (submit → poll `ProcessCompletedFlag` → read `ProcessLog`).
Two live import attempts (ProcessIds `100007866630774` nested-XML batch, `100007866630785`
flat-CSV batch, ESS request ids `9764655`, `9764673`) both returned the **same skip**:

> Business object: Accounting Calendar. Status: Completed successfully. Status details:
> **The import process skipped the Accounting Calendar business object because all the related
> CSV files are missing or empty.**

The import doesn't error — it "succeeds" while loading nothing, because it did not recognise our
batch member(s) as the CSVs it expects. Base tables confirmed clean afterward (no `RTG9040*` /
`RTB9040*` period sets, no `RT ...` calendars).

## Why the exact batch payload is unverifiable on this pod (the blocker)

The reliable way to learn the exact batch shape is to **export** the object from the pod and
mimic the emitted files. That export is walled on this demo instance:

1. `POST setupTaskCSVExports` for `GL_MANAGE_ACCOUNTING_CALENDARS` completes, but the export's
   `FileContent` zip contains **only** `ASM_SETUP_CSV_METADATA.xml` — the batch itself is never
   emitted. The `ProcessLog` explains why:

   > The size of the file **GL_CALENDAR.xml** in batch `Calendar/1_BATCH.zip` is **13.24 MB and
   > exceeds the limit of 10 MB. Therefore, it can't be processed.**

   The pod has **191 pre-existing calendars**; the object serialises them all into one
   `GL_CALENDAR.xml` that always exceeds the FSM 10 MB per-file export ceiling.
2. **Scope criteria are ignored.** Adding `SetupTaskCSVExportCriteria`
   (`BusinessObjectCode=GL_PERIOD_SET`, `AttributeName=PeriodSetName`,
   `AttributeValue=<one tiny calendar>`) had **no effect** — the export still processed all 191
   rows and still hit the 13.24 MB / 10 MB wall. So we cannot shrink the export below the limit
   to obtain a valid reference batch.

Net: we have the **manifest** (real, exported — see `artifact/ASM_SETUP_CSV_METADATA.xml`) which
tells us the two business objects, their full attribute lists, the XML node paths, and the SOA
service — but we do **not** have a confirmed example of the batch data file the importer accepts,
and our constructed batches (both a nested `CalendarVO/PeriodVORow` XML and per-object flat CSVs)
are silently skipped. Guessing further would risk faking a pass, which is forbidden.

## The manifest we DID get (authoritative structure)

`artifact/ASM_SETUP_CSV_METADATA.xml` (exported live) declares the object precisely:

- **Batch:** `Calendar`, `ImportSequence=0`, `BatchSize=500`, service `CalendarsService`.
- **Business object `GL_PERIOD_SET`** (the calendar header) — node path
  `/CalendarVO/CalendarVORow`, 31 attributes beginning
  `UserPeriodSetName, PeriodSetName, Description, SecurityFlag, AdjPeriodsNum, NonAdjPeriodsNum,
  LatestYearStartDate, CalendarStartDate, CalendarTypeCode, ... , PeriodNameFormatCode, ...`.
- **Business object `GL_PERIOD_DEF`** (the periods) — node path
  `/CalendarVO/CalendarVORow/Period/PeriodVORow`, 64 attributes beginning
  `PeriodName, PeriodSetName, StartDate, EndDate, YearStartDate, QuarterStartDate, PeriodYear,
  PeriodNum, QuarterNum, EnteredPeriodName, AdjustmentPeriodFlag, ... , FiscalYear, ...`.
- `MigrationObjectCSVMetadata`: `GL_PERIOD_SET`, `MigrateFlag=Y`, `IncludeExternalDataFlag=Y`
  (this `IncludeExternalDataFlag=Y` is the "External Loading" marker — the tell that the batch
  is service-loaded XML, not a plain CSV the FSM CSV importer parses directly).

## The portable fixture (built, ready the instant the batch shape is confirmed)

Standalone setup data — a calendar borrows nothing, so **no discovery is needed** and there is
**no upstream dependency** (portability rules 6–8 satisfied trivially).

- **Good:** a NEW monthly calendar, period-set `RTG${PREFIX}` / user name `RT Gold Cal ${PREFIX}`,
  with **12 non-adjusting monthly periods** for fiscal year **2035** (far-future year so it can
  never collide with any pod ledger's calendar).
- **Bad (deterministic, pod-independent):** period-set `RTB${PREFIX}` is present in
  `GL_PERIOD_SET.csv` but has **zero period rows** in `GL_PERIOD_DEF.csv`. A calendar whose
  declared non-adjusting period count is not met is rejected; with no valid parent it can never
  reach the base tables. No bad reference data required.

Files (`artifact/`, `${PREFIX}` tokens, batched into `GLCalendar_gold.zip`):
`GL_PERIOD_SET.csv`, `GL_PERIOD_DEF.csv`, plus the real `ASM_SETUP_CSV_METADATA.xml` manifest.
**`GLCalendar_gold.zip` is our best-known layout, NOT a proven artifact** — the importer still
skips it, so the exact batch member naming/shape for this External-Loading object is unconfirmed.

## Verify SQL (read-only BIP, direct single-table reads) — for when it loads

Good calendar reached base:
```sql
SELECT user_period_set_name, period_set_name FROM gl_calendars   WHERE period_set_name = 'RTG${PREFIX}';
SELECT period_set_name, description           FROM gl_period_sets WHERE period_set_name = 'RTG${PREFIX}';
```
Good periods reached base (expect 12):
```sql
SELECT period_set_name, period_name, TO_CHAR(start_date,'YYYY/MM/DD'), TO_CHAR(end_date,'YYYY/MM/DD')
FROM   gl_periods WHERE period_set_name = 'RTG${PREFIX}' ORDER BY period_num;
```
Bad calendar absent from base (rejection proof):
```sql
SELECT period_set_name FROM gl_period_sets WHERE period_set_name = 'RTB${PREFIX}';   -- expect zero rows
```

## Live evidence

None for the base tables — **tabled, never faked.** The non-UI mechanism is proven **reachable**
(HTTP 201 + process completion) but never loaded a calendar (importer skipped the object every
time), so there is no base-table id to report. Two live import ProcessIds (`100007866630774`,
`100007866630785`; ESS `9764655`, `9764673`) each "Completed successfully" with 0 objects
loaded. Base tables clean afterward.

## How to unblock (promote to ✅)

1. **Get one valid reference batch.** The 10 MB export wall is environmental (191 calendars).
   On a pod with few calendars — or after Oracle raises the per-file export limit / adds working
   scope filtering — export `GL_MANAGE_ACCOUNTING_CALENDARS`, unzip `Calendar/1_BATCH.zip`, and
   read the real batch data member(s). Rebuild `GLCalendar_gold.zip` to match that shape exactly.
2. Re-run the import (`setupTaskCSVImports`, base64 zip, poll `ProcessCompletedFlag`, read
   `ProcessResultsReport` for per-object counts), then run the verify SQL above and record
   prefix + ProcessId + base ids.

## Sources

- Oracle: [Automate Export and Import of CSV File Packages](https://docs.oracle.com/en/cloud/saas/applications-common/25c/oafsm/automate-export-and-import-of-csv-file-packages.html)
- Oracle: [Get a setup task CSV import (REST, Common Features)](https://docs.oracle.com/en/cloud/saas/applications-common/25c/farca/op-fscmrestapi-resources-11.13.18.05-setuptaskcsvimports-taskcode-get.html)
- Oracle: [Setup Data Import and Export for Oracle Fusion Financials](https://docs.oracle.com/en/cloud/saas/financials/26c/faigl/setup-data-import-and-export-for-oracle-fusion-financials.html)
- Oracle DM: [GL_PERIOD_SETS](https://docs.oracle.com/en/cloud/saas/financials/25d/oedmf/glperiodsets-27159.html) · [GL_PERIODS](https://docs.oracle.com/en/cloud/saas/financials/24b/oedmf/glperiods-5841.html) · [GL_CALENDARS](https://docs.oracle.com/en/cloud/saas/financials/24b/oedmf/glcalendars-5141.html)
- Vishal Palakurthi: [How to automate setup data load in Fusion Cloud ERP](https://medium.com/@vishalpalakurthi/how-to-automate-setup-data-load-in-fusion-cloud-erp-system-4c5cefc5cef1)
