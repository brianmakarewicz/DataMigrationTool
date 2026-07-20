# GLCalendar (GL Accounting Calendar) — canonical object notes

**What it is.** A GL accounting calendar: a calendar / period set plus its accounting periods.
Base tables: `GL_CALENDARS` and `GL_PERIOD_SETS` (calendar header), `GL_PERIODS` (periods).

**Load mechanism (found 2026-07-20).** NOT FBDI, NOT HDL. It is the FSM **Setup Data Import
from CSV** path, driven programmatically (no UI, no DMT code):

- REST `POST /fscmRestApi/resources/11.13.18.05/setupTaskCSVImports`
- TaskCode **`GL_MANAGE_ACCOUNTING_CALENDARS`** (`ImportSupportedFlag: true`)
- Body: `{TaskCode, SetupTaskCSVImportProcess:[{TaskCode, FileContent:<base64 zip>, SourceTargetDiffOkFlag:true}]}`
- Content-Type `application/vnd.oracle.adf.resourceitem+json`; auth `fin_impl`.
- Poll `.../SetupTaskCSVImportProcess/{id}` for `ProcessCompletedFlag`; read outcome from the
  `SetupTaskCSVImportProcessResult/{id}/enclosure/ProcessLog` and `.../ProcessResultsReport`.

The import zip is an FSM configuration package: `ASM_SETUP_CSV_METADATA.xml` (manifest) plus a
batch `Calendar/1_BATCH.zip`. Two business objects: `GL_PERIOD_SET` (header,
`/CalendarVO/CalendarVORow`) and `GL_PERIOD_DEF` (periods,
`/CalendarVO/CalendarVORow/Period/PeriodVORow`), loaded via the SOA `CalendarsService`. It is an
"External Loading" object (`IncludeExternalDataFlag=Y`) — the batch data is service-loaded XML,
not a plain CSV the FSM importer parses directly.

**Status: TABLED (not live-proven).** The mechanism is proven **reachable** (HTTP 201, process
completes) but no calendar loaded — every constructed batch is skipped by the importer with
"all the related CSV files are missing or empty," and we could not obtain a valid reference batch
to mimic because the pod's export of this object always exceeds the 10 MB per-file limit
(191 calendars → 13.24 MB `GL_CALENDAR.xml`) and scope criteria are ignored. Full detail,
manifest structure, fixture, verify SQL, and unblock steps are in `GOLD_README.md`.

**Portability.** Standalone setup data — a calendar borrows nothing, so no discovery and no
upstream dependency. Good = new monthly period-set `RTG${PREFIX}` with 12 periods (FY 2035);
bad = period-set `RTB${PREFIX}` with zero periods (deterministic reject, pod-independent).

See `GOLD_README.md` for the complete finding and `recipe.json` for the machine-readable recipe.
